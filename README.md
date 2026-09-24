# mobsms_ohos

为 MobTech 官方 Flutter 短信插件 [`mobsms`](https://pub.dev/packages/mobsms) 提供 HarmonyOS 实现。

添加本包后，鸿蒙自动注册原生插件，业务代码继续使用官方 `Smssdk` 接口。Android/iOS 仍由 `mobsms` 处理，沿用各自的原生配置。

## 1. 安装

在应用的 `pubspec.yaml` 中添加：

```yaml
dependencies:
  mobsms: ^1.2.1
  mobsms_ohos: ^0.2.0
```

然后运行：

```sh
flutter pub get
```

业务代码可以直接导入官方包：

```dart
import 'package:mobsms/mobsms.dart';
```

也可以导入 `package:mobsms_ohos/mobsms_ohos.dart`，它重新导出了相同的 `Smssdk` API。

**必须同时添加鸿蒙实现依赖。** 目前只添加 `mobsms` 不会自动下载 `mobsms_ohos`。本包声明了 `implements: mobsms`，添加依赖后无需手动编辑 `GeneratedPluginRegistrant.ets`。

## 2. 环境要求

- 使用支持 OHOS 的 Flutter SDK。包声明的最低版本为 Flutter 3.27、Dart 3.6。
- 鸿蒙原生短信 SDK 要求 HarmonyOS API 20 或以上。
- DevEco / Command Line Tools 和编译 SDK 须与所用 Flutter OHOS 版本匹配。

本项目已使用 Flutter `3.44.9+ohos-0.0.1-canary1`、Dart `3.12.2`、HarmonyOS CLI `26.0.0.621` / API 26 完成宿主应用的调试构建。最低声明版本不代表所有组合均已实测。

## 3. 配置鸿蒙应用

### 配置 AppKey

在宿主应用 `ohos/entry/src/main/module.json5` 的 `module.metadata` 数组中添加 `MobAppKey`：

```json5
{
  "module": {
    // 保留应用原有的 name、type、abilities 等字段。
    "metadata": [
      // 保留原有 metadata 条目。
      {
        "name": "MobAppKey",
        "value": "你的 MobTech AppKey"
      }
    ],
    "requestPermissions": [
      // 与应用已有权限合并，避免重复声明。
      { "name": "ohos.permission.INTERNET" },
      { "name": "ohos.permission.GET_NETWORK_INFO" }
    ]
  }
}
```

上面是需要合并的配置片段，不是完整的 `module.json5`。Key 配置在**宿主应用的 entry 模块**中，不要修改插件包里的 HAR 模块配置。

插件在收到隐私授权后读取 `MobAppKey` 并初始化一次。Dart 无需额外调用鸿蒙初始化方法；当前鸿蒙原生 SDK 的 Secret 参数使用空字符串，不需要配置 `MobAppSecret`。

### 配置最低系统版本

在 `ohos/build-profile.json5` 中，为实际使用的每个 product 配置至少 API 20，例如：

```json5
"compatibleSdkVersion": "6.0.0(20)"
```

调试和发布 product 都要核对，不能只修改调试配置。编译 SDK 则按 Flutter OHOS 所要求的版本安装。

### 配置 MobTech 后台

在 MobTech 开发者平台创建或选择短信应用，开通鸿蒙短信能力，并配置：

- 当前应用的 AppKey。
- 与 `ohos/AppScope/app.json5` 中 `bundleName` 一致的鸿蒙包名。
- 与实际安装包签名一致的鸿蒙签名指纹。
- 应用所使用的短信模板。

调试包与发布包可能使用不同签名。后台信息必须匹配正在运行的安装包；Android 的签名配置不能直接代替鸿蒙配置。

## 4. 提交隐私授权

**取得用户同意后**，调用官方接口：

```dart
Smssdk.submitPrivacyGrantResult(true);
```

这是 `void` 方法，不需要 `await`。鸿蒙插件收到调用时同步读取 Key 并初始化，随后可以调用验证码接口。相同插件实例重复收到授权时不会重复初始化 SDK。

用户撤销授权时调用：

```dart
Smssdk.submitPrivacyGrantResult(false);
```

鸿蒙未授权时不会初始化；撤销授权后会阻止后续短信调用。不要无条件在应用启动时传入 `true`，应与应用自己的隐私同意流程衔接。

## 5. 发送短信验证码

以下代码在用户同意隐私政策、提交上述授权后执行：

```dart
import 'package:flutter/foundation.dart';
import 'package:mobsms/mobsms.dart';

Future<void> sendCode(String phone, String templateCode) async {
  await Smssdk.getTextCode(
    phone,
    '86', // 国家或地区代码，不带 +。
    templateCode, // MobTech 后台配置的短信模板代码。
    (ret, err) {
      if (err != null) {
        debugPrint('验证码发送失败：$err');
        // 在这里提示错误，不要启动成功后的倒计时。
        return;
      }
      // 请求已完成，可提示用户查看短信并启动倒计时。
      // 这不代表手机已经收到短信。
      debugPrint('验证码请求已完成');
    },
  );
}
```

回调中的 `err` 表示 SDK 业务错误；判断是否失败时优先检查它，不要将 `ret` 当作运营商短信送达回执。平台通道异常还可能以 Future 异常返回，应用应接入自己的异常处理。

本实现保留了对鸿蒙 SDK 发送返回值的兼容：已观察到短信正常送达时原生方法仍返回 `false`，因此发送失败按原生异常处理，避免错误提示“发送失败”。

## 6. 校验验证码

参数顺序为手机号、国家或地区代码、验证码、回调：

```dart
await Smssdk.commitCode(phone, '86', code, (ret, err) {
  if (err != null) {
    // 验证失败，向用户提示并允许重新输入。
    return;
  }
  // 验证成功，继续应用自己的业务流程。
});
```

短信校验结果不等同于应用服务端的登录态。登录、绑定手机号等操作仍需接入应用自己的服务端流程。

## 7. 其他接口

```dart
await Smssdk.getSupportedCountries((ret, err) {
  // ret 为原生 SDK 返回的国家或地区信息；失败时检查 err。
});

await Smssdk.getVersion((ret, err) {
  // 鸿蒙成功时 ret 为 { 'version': '原生短信 SDK 版本' }。
});
```

### 鸿蒙支持范围

| 官方 Dart 接口 | 鸿蒙实现 |
| --- | --- |
| `submitPrivacyGrantResult` | 授权、读取 Key、初始化及撤销授权 |
| `getTextCode` | 发送短信验证码 |
| `commitCode` | 校验验证码 |
| `getSupportedCountries` | 获取支持的国家或地区 |
| `getVersion` | 获取原生短信 SDK 版本 |
| `getVoiceCode`、`getFriends`、`submitUserInfo`、`enableWarn` | 未实现 |

除隐私授权外，上述已实现接口都要求先取得授权。未实现的方法在完成初始化后调用会返回未实现错误。Android/iOS 的支持范围以官方 `mobsms` 为准。

## 8. 常见问题

### `INIT_FAILED`：缺少 MobAppKey

检查 `MobAppKey` 是否位于宿主 entry 模块的 `module.metadata` 中，名称大小写是否正确、value 是否为空。原生配置修改后需要重新构建安装，热重载不会更新安装包里的配置。

### `NOT_INITIALIZED`

先取得用户同意，再调用 `Smssdk.submitPrivacyGrantResult(true)`。同时检查前一次授权调用是否因 Key 配置错误而失败。

### `MD5 is not valid.` / 状态码 489

核对 MobTech 后台的鸿蒙应用配置，尤其是包名与当前安装包的签名指纹。后台字段即使标注为 MD5，也应按该平台的鸿蒙签名要求填写；不要直接套用 Android 的签名值。检查是否更换过调试证书或切换了发布签名。

### 修改原生配置后没有生效

停止当前运行，重新构建并安装应用。确认应用没有同时接入旧的 `SMSSDK-for-Flutter` 本地修改版或其他注册相同短信通道的插件。

## 从 Git 版本 0.1.0 迁移

1. 将原来的 Dart AppKey 移到宿主 `module.json5` 的 `MobAppKey`。
2. 删除 `MobsmsOhos.initialize(...)`。
3. 将 `MobsmsOhos.grantPrivacy()` 替换为 `Smssdk.submitPrivacyGrantResult(true)`，保留用户同意判断。
4. 验证码发送与校验继续使用原来的 `Smssdk` 方法。

## 原生依赖与许可证

通过 ohpm 引入以下原生依赖，发布包不包含其二进制文件：

- `@zztsdk/zztcore: 2026.7.13`
- `@zztsdk/smshos: 1.0.0`

本插件桥接代码使用 [MIT 许可证](LICENSE)。MobTech / 原生 SDK 的使用条款与许可证由各自供应方规定。

问题反馈：[GitHub Issues](https://github.com/zhangruiyu/mobsms_ohos/issues)。
