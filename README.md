# mobsms_ohos

`mobsms` 的 HarmonyOS 实现。添加本包后，Android/iOS 继续使用 MobTech 的 `mobsms` 插件，HarmonyOS 自动注册本包的 ArkTS 插件。应用只需声明 `mobsms_ohos` 依赖；本包会引入 `mobsms`。

```yaml
dependencies:
  mobsms_ohos: ^0.1.0
```

```dart
import 'package:mobsms_ohos/mobsms_ohos.dart';

// HarmonyOS 首次使用短信前初始化；AppKey 由应用自己提供。
await MobsmsOhos.initialize('你的 MobTech AppKey');
// 用户同意隐私政策后调用。
await MobsmsOhos.grantPrivacy();

await Smssdk.getTextCode('手机号', '86', '模板代码', (ret, err) {
  if (err != null) {
    // 处理发送失败。
  }
});
```

目前 HarmonyOS 实现了 `getTextCode`、`commitCode`、`getSupportedCountries` 和 `getVersion`。`mobsms` 的其他方法尚无对应原生能力，调用时会返回未实现。应用需要声明 `ohos.permission.INTERNET` 和 `ohos.permission.GET_NETWORK_INFO`，并在 MobTech 后台登记鸿蒙包名及签名。原生 SDK 要求 HarmonyOS API 20 或以上。

本包通过 ohpm 取得 `@zztsdk/zztcore` 和 `@zztsdk/smshos`，不包含这两个 SDK 的二进制文件。

只依赖 `mobsms` 主包的项目不会自动取得本实现；要实现这一点，`mobsms` 主包还需要将本包列为依赖，并将 OHOS 的 `default_package` 指向 `mobsms_ohos`。
