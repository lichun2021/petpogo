import '../config/app_config.dart';

/// 所有 API 路径常量
///
/// 路径常量只保存路径部分（如 '/pets'），
/// 完整地址由 ApiClient 拼接（baseUrl + path）。
/// AI 服务的根地址统一从 [AppConfig.aiServiceBase] 读取。
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

  // ── AI 服务（独立部署）─────────────────────────────────────
  /// AI 服务根地址 — 统一从 AppConfig 读取，不在此处硬编码
  ///
  /// 修改部署地址请前往 [AppConfig.aiServiceBase]
  static String get aiServiceBase => AppConfig.aiServiceBase;

  // —— 语音模块：POST /voice/analyze ——
  /// 上传音频并返回物种 + 情绪分析结果
  static const aiVoiceAnalyze = '/voice/analyze';

  // —— 图像模块：POST /dog/analyze ——
  /// 上传狗狗图片并返回 13 类情绪分析结果
  static const aiDogAnalyze   = '/dog-image/analyze';

  /// 查询服务健康状态
  static const aiHealth = '/health';

  // 保留旧名兼容已接入的语音接口代码（无需修改调用方）
  @Deprecated('Use aiVoiceAnalyze')
  static const aiAnalyze = aiVoiceAnalyze;
}
