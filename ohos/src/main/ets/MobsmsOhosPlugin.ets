import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { ZztSDK } from '@zztsdk/zztcore';
import { SmsSDK } from '@zztsdk/smshos';

export default class MobsmsOhosPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.Context | null = null;
  private initialized: boolean = false;

  getUniqueClassName(): string {
    return 'MobsmsOhosPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getApplicationContext();
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.mob.smssdk.channel');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.context = null;
    this.initialized = false;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (call.method === 'initOhos') {
        const appKey: string = call.args.get('appKey');
        if (!this.context || !appKey) {
          result.error('INIT_FAILED', '缺少应用上下文或 AppKey', null);
          return;
        }
        ZztSDK.init(this.context, appKey, '');
        this.initialized = true;
        result.success(null);
        return;
      }

      if (!this.initialized) {
        result.error('NOT_INITIALIZED', '请先初始化鸿蒙短信 SDK', null);
        return;
      }

      if (call.method === 'uploadPrivacyStatus') {
        ZztSDK.submitPolicyGrantResult(call.args.get('status') === true);
        result.success(null);
      } else if (call.method === 'getTextCode') {
        const country: string = call.args.get('zone');
        const phone: string = call.args.get('phoneNumber');
        const template: string = call.args.get('tempCode');
        // 实测短信已送达时 SDK 仍可能返回 false；失败会抛出异常。
        await SmsSDK.getVerificationCode(country, phone, template);
        result.success({ 'ret': true });
      } else if (call.method === 'commitCode') {
        const country: string = call.args.get('zone');
        const phone: string = call.args.get('phoneNumber');
        const code: string = call.args.get('code');
        const verified = await SmsSDK.submitVerificationCode(country, phone, code);
        if (verified) {
          result.success({ 'ret': true });
        } else {
          result.success({ 'err': { 'message': '验证码校验失败' } });
        }
      } else if (call.method === 'getSupportedCountries') {
        const countries = await SmsSDK.getSupportedCountries();
        result.success({ 'ret': countries });
      } else if (call.method === 'getVersion') {
        result.success({ 'ret': { 'version': SmsSDK.getVersion() } });
      } else {
        result.notImplemented();
      }
    } catch (error) {
      if (call.method === 'initOhos' || call.method === 'uploadPrivacyStatus') {
        result.error('SMS_FAILED', String(error), null);
      } else {
        result.success({ 'err': { 'message': String(error) } });
      }
    }
  }
}
