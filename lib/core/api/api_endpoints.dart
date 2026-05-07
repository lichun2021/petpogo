/// 所有 API 路径常量
///
/// 路径常量只保存路径部分（如 '/pets'），
/// 完整地址由 ApiClient 拼接（baseUrl + path）。
/// AI 功能统一通过业务后端 /sdkapi/ai/* 接口调用，不再直连独立 AI 服务。
abstract class ApiEndpoints {
  // ── 业务后端（PetPogo 自有服务）────────────────────────
  static const pets        = '/pets';
  static const devices     = '/devices';
  static const deviceBind  = '/devices/bind';
  static const user        = '/user/profile';
  static const login       = '/auth/login';
  static const logout      = '/auth/logout';
  static const community   = '/posts';
  static const mallItems   = '/mall/products';
  static const storeNearby = '/stores/nearby';

  // 带参数（用方法生成）
  static String petDetail(String id) => '/pets/$id';
  static String deviceDetail(String id) => '/devices/$id';

  // ── AI 接口（经业务后端代理，含配额控制）────────────────
  /// 语音情绪分析  POST /sdkapi/ai/voice-analyze
  static const aiVoiceAnalyze = '/sdkapi/ai/voice-analyze';

  /// 图像情绪分析  POST /sdkapi/ai/image-analyze
  static const aiImageAnalyze = '/sdkapi/ai/image-analyze';

  // ── OSS 上传签名 ──────────────────────────────────────
  /// 获取预签名上传地址  POST /sdkapi/upload/sign
  static const ossUploadSign = '/sdkapi/upload/sign';
}
