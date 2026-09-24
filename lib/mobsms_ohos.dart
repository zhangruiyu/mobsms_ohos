import 'package:flutter/services.dart';

export 'package:mobsms/mobsms.dart';

/// HarmonyOS 初始化入口。验证码接口继续使用 mobsms 的 Smssdk。
class MobsmsOhos {
  static const MethodChannel _channel = MethodChannel('com.mob.smssdk.channel');

  static Future<void> initialize(String appKey) async {
    await _channel.invokeMethod<void>('initOhos', {'appKey': appKey});
  }

  static Future<void> grantPrivacy() async {
    await _channel.invokeMethod<void>('uploadPrivacyStatus', {'status': true});
  }
}
