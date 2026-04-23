/// 所有 API URL 常量
/// 用法：ApiEndpoints.pets → '/pets'
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

  // ── AI 语音分析服务（独立部署）────────────────────────
  /// AI 服务的完整 baseUrl（独立于业务后端地址）
  static const aiServiceBase = 'http://49.234.39.11:8002';

  /// 上传音频并返回物种 + 情绪分析结果
  static const aiAnalyze   = '/analyze';

  /// 查询服务健康状态
  static const aiHealth    = '/health';
}
