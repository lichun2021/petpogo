/// App 全局配置
///
/// 所有服务地址、SDK 凭证、运行时开关都在这里统一管理。
/// 新增地址时请放到对应区块，不要散落在业务代码里。
class AppConfig {
  AppConfig._();

  // ──────────────────────────────────────────────
  // 业务后端（uCloudlink）
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
  // AI 识别服务（独立部署，与业务后端地址不同）
  // ──────────────────────────────────────────────

  /// PetPogo AI 服务根地址
  ///
  /// 该服务独立于业务后端，包含：
  ///   - POST /voice/analyze   — 宠物语音情绪分析
  ///   - POST /dog-image/analyze — 狗狗图像情绪分析（13 类）
  ///   - GET  /health          — 服务健康检查
  ///
  /// 部署地址变更时只改这里，Repository 层无需修改。
  static const String aiServiceBase = 'http://49.234.39.11:8002';

  // ──────────────────────────────────────────────
  // 认证服务（独立部署）
  // ──────────────────────────────────────────────

  /// 登录接口根地址（与主业务后端不同，独立部署）
  ///
  /// 完整登录 URL = [authServiceBase] + '/admin/sys/index/login'
  ///
  /// 部署地址变更时只改这里，AuthRepository 无需修改。
  static const String authServiceBase = 'http://49.234.39.11:8008';

  /// 旧版翻译服务地址（保留，待接入时替换）
  static const String translationBaseUrl = 'http://YOUR_TRANSLATION_HOST:8078';

  // ──────────────────────────────────────────────
  // App 信息
  // ──────────────────────────────────────────────
  static const String appVersion     = '1.0.5';
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
