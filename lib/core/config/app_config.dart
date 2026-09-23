/// App 全局配置
///
/// 所有服务地址、SDK 凭证、运行时开关都在这里统一管理。
/// 新增地址时请放到对应区块，不要散落在业务代码里。
class AppConfig {
  AppConfig._();

  // ──────────────────────────────────────────────
  // 业务后端（uCloudlink）
  // ──────────────────────────────────────────────
  //static const String baseUrl        = 'http://115.29.196.61:3000';
  static const String baseUrl = 'https://api.jxpetai.com';
  // ──────────────────────────────────────────────
  // 第三方 SDK（待填入）
  // ──────────────────────────────────────────────

  static const int timSdkAppId = 1600139420; // 宠物测试 IM - 体验版
  static const String wechatAppId = 'wx02094a124e425dfe';
  static const String wechatUniversalLink = 'https://www.jxpetai.com/';

  // ──────────────────────────────────────────────
  // 极光推送
  // ──────────────────────────────────────────────
  static const String jpushAppKey = 'bbff354f334f7c5e340b9c38';

  // ──────────────────────────────────────────────
  // 认证服务
  // ──────────────────────────────────────────────
  // 登录接口与主业务后端同地址，统一使用 baseUrl。
  // 完整登录 URL = baseUrl + '/auth/login'

  // ──────────────────────────────────────────────
  // App 信息
  // ──────────────────────────────────────────────
  static const String appVersion = '1.0.8';
  static const String defaultLang = 'zh-CN';
  static const String shareSiteBaseUrl = 'https://www.jxpetai.com';
  static const String appScheme = 'petpogo';

  // ──────────────────────────────────────────────
  // 分页
  // ──────────────────────────────────────────────
  static const int pageSize = 20;

  // ──────────────────────────────────────────────
  // ApiClient 专用（统一入口）
  // ──────────────────────────────────────────────
  /// ApiClient 使用的基础地址（与 baseUrl 保持一致，可按需切换）
  static const String apiBaseUrl = baseUrl;

  /// 是否 Debug 模式（控制日志拦截器开关）
  /// Flutter 会在 release 构建时自动优化掉 assert/kDebugMode
  static const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;
}
