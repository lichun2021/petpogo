/// App 全局配置
class AppConfig {
  AppConfig._();

  // ──────────────────────────────────────────────
  // API 端点
  // ──────────────────────────────────────────────
  static const String baseUrl        = 'https://api.ucloudlink.com/';
  static const String baseUrlCn      = 'https://saas.ucloudlink.cn/';

  // ──────────────────────────────────────────────
  // OAuth 凭证（生产）
  // ──────────────────────────────────────────────
  static const String partnerCode    = 'GCGROUP';
  static const String clientId       = '585920816499674940a2cbae';
  static const String clientSecret   = '585920816499674940a2cbaf';
  static const String enterpriseCode = 'EA00000484';

  // ──────────────────────────────────────────────
  // 第三方 SDK（待填入）
  // ──────────────────────────────────────────────
  static const String amapAndroidKey = 'YOUR_AMAP_ANDROID_KEY';
  static const String amapIosKey     = 'YOUR_AMAP_IOS_KEY';
  static const int    timSdkAppId    = 0;    // TODO: 腾讯云 IM SDKAppID
  static const String timSecretKey   = '';   // TODO: 腾讯云 IM SecretKey

  // ──────────────────────────────────────────────
  // AI 识别服务
  // ──────────────────────────────────────────────
  static const String translationBaseUrl = 'http://YOUR_TRANSLATION_HOST:8078';

  // ──────────────────────────────────────────────
  // App 信息
  // ──────────────────────────────────────────────
  static const String appVersion     = '1.0.4';
  static const String defaultLang    = 'zh-CN';

  // ──────────────────────────────────────────────
  // 分页
  // ──────────────────────────────────────────────
  static const int pageSize          = 20;

  // ──────────────────────────────────────────────
  // ApiClient 专用（统一入口）
  // ──────────────────────────────────────────────
  /// ApiClient 使用的基础地址（与 baseUrl 保持一致，可按需切换）
  static const String apiBaseUrl = baseUrl;

  /// 是否 Debug 模式（控制日志拦截器开关）
  /// Flutter 会在 release 构建时自动优化掉 assert/kDebugMode
  static const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;
}
