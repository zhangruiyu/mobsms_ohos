import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult
} from '@ohos/flutter_ohos';
import { bundleManager, common } from '@kit.AbilityKit';
import { ZztSDK } from '@zztsdk/zztcore';
import { SmsSDK } from '@zztsdk/smshos';

export default class MobsmsOhosPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.Context | null = null;
  private initialized: boolean = false;
  private privacyGranted: boolean = false;

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
    this.privacyGranted = false;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (call.method === 'uploadPrivacyStatus') {
        const granted: boolean = call.args.get('status') === true;
        if (!granted) {
          this.privacyGranted = false;
        }
        if (granted && !this.initialized) {
          // 同步读取宿主配置，确保紧接着发送验证码时已经完成初始化。
          const bundleInfo = bundleManager.getBundleInfoForSelfSync(
            bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE |
            bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_METADATA);
          let appKey: string = '';
          for (const moduleInfo of bundleInfo.hapModulesInfo) {
            for (const metadata of moduleInfo.metadata) {
              if (metadata.name === 'MobAppKey') {
                appKey = metadata.value;
              }
            }
          }
          if (!this.context || !appKey) {
            result.error('INIT_FAILED', '请在宿主 module.json5 的 metadata 中配置 MobAppKey', null);
            return;
          }
          ZztSDK.init(this.context, appKey, '');
          this.initialized = true;
        }
        if (this.initialized) {
          ZztSDK.submitPolicyGrantResult(granted);
        }
        this.privacyGranted = granted;
        result.success(null);
        return;
      }

      if (!this.initialized || !this.privacyGranted) {
        result.error('NOT_INITIALIZED', '请在用户同意隐私政策后调用 Smssdk.submitPrivacyGrantResult(true)', null);
        return;
      }

      if (call.method === 'getTextCode') {
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
      if (call.method === 'uploadPrivacyStatus') {
        result.error('SMS_FAILED', String(error), null);
      } else {
        result.success({ 'err': { 'message': String(error) } });
      }
    }
  }
}
