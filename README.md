# mobsms_ohos

`mobsms` 的 HarmonyOS 实现。添加本包后，Android/iOS 继续使用 MobTech 的 `mobsms` 插件，HarmonyOS 自动注册本包的 ArkTS 插件。三端业务代码均可使用官方 `Smssdk` 接口。

```yaml
dependencies:
  mobsms: 1.2.1
  mobsms_ohos:
    git:
      url: https://github.com/zhangruiyu/mobsms_ohos.git
      ref: main
```

目前通过 GitHub 分发，尚未发布到 pub.dev。正式项目建议将 `ref` 固定到验证过的提交。

### 鸿蒙配置

在宿主应用 `ohos/entry/src/main/module.json5` 的 `module.metadata` 数组中添加以下配置，保留已有条目：

```json
{
  "name": "MobAppKey",
  "value": "你的 MobTech AppKey"
}
```

插件在收到隐私授权时读取 AppKey 并初始化原生 SDK，无需在 Dart 单独调用鸿蒙初始化方法。当前鸿蒙 SDK 初始化的 Secret 参数使用空字符串。

### Dart 调用

```dart
import 'package:mobsms/mobsms.dart';

// 用户同意隐私政策后调用。
Smssdk.submitPrivacyGrantResult(true);

await Smssdk.getTextCode('手机号', '86', '模板代码', (ret, err) {
  if (err != null) {
    // 处理发送失败。
  }
});
```

`submitPrivacyGrantResult` 是官方包提供的 `void` 方法，不需要 `await`。鸿蒙插件同步完成配置读取和初始化，随后即可发送验证码。未授权时不会初始化；传入 `false` 会撤销授权并阻止后续短信调用。

从 0.1.0 升级时，将 AppKey 移到上述原生配置，删除 `MobsmsOhos.initialize`，并将 `MobsmsOhos.grantPrivacy` 替换为官方的 `Smssdk.submitPrivacyGrantResult(true)`。

目前 HarmonyOS 实现了 `getTextCode`、`commitCode`、`getSupportedCountries` 和 `getVersion`。`mobsms` 的其他方法尚无对应原生能力，调用时会返回未实现。应用需要声明 `ohos.permission.INTERNET` 和 `ohos.permission.GET_NETWORK_INFO`，并在 MobTech 后台登记鸿蒙包名及签名。原生 SDK 要求 HarmonyOS API 20 或以上。

本包通过 ohpm 取得 `@zztsdk/zztcore` 和 `@zztsdk/smshos`，不包含这两个 SDK 的二进制文件。

只依赖 `mobsms` 主包的项目不会自动取得本实现；要实现这一点，`mobsms` 主包还需要将本包列为依赖，并将 OHOS 的 `default_package` 指向 `mobsms_ohos`。
