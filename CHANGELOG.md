## 0.2.0

- First pub.dev release, with installation, host configuration, API usage, and troubleshooting documentation.
- Read `MobAppKey` from the host module metadata and initialize on privacy consent.
- Use the official `Smssdk.submitPrivacyGrantResult` API on all platforms.
- Remove the separate `MobsmsOhos.initialize` and `grantPrivacy` methods.
- Reject SMS calls before consent and after consent is withdrawn.

## 0.1.0

- Add HarmonyOS text verification code support for `mobsms`.
- Add HarmonyOS initialization and privacy consent methods.
