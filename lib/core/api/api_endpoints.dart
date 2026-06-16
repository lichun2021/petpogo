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
  static const feedback    = '/api/user/feedback';
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

  // ── 媒体库 ──────────────────────────────────────────
  /// 保存图库记录  POST /sdkapi/media/save
  static const mediaSave   = '/sdkapi/media/save';
  /// 获取图库列表  GET /sdkapi/media/list
  static const mediaList   = '/sdkapi/media/list';
  /// 删除图库文件  DELETE /sdkapi/media/:id
  static String mediaDelete(String id) => '/sdkapi/media/$id';

  // ── 自动抓拍事件 ─────────────────────────────────────
  /// 获取抓拍记录列表  GET /sdkapi/capture/list
  static const captureList = '/sdkapi/capture/list';

  // ── 打招呼事件 ─────────────────────────────────────
  /// 获取打招呼记录列表  GET /sdkapi/greeting/list
  static const greetingList = '/sdkapi/greeting/list';

  /// 删除抓拍记录  DELETE /sdkapi/capture/:id
  static String captureDelete(int id) => '/sdkapi/capture/$id';

  // ── 声音预设 ───────────────────────────────────────
  /// 获取声音预设列表  GET /sdkapi/sound/preset/list
  static const soundPresetList = '/sdkapi/sound/preset/list';


  // ── 宠小伊 AI 问诊（独立后端 AppConfig.aiConsultBaseUrl）─
  /// 创建新 session（POST JSON body {pet_id}，v0.4 改为 POST）
  static const aiConsultSessionNew      = '/session/new';
  /// 删除 session（POST JSON body {session_id}）
  static const aiConsultSessionDelete   = '/session/delete';
  /// 同步问诊（一次性返回，调试/降级用）
  static const aiConsultMessages        = '/messages';
  /// 流式问诊（SSE，主入口）
  static const aiConsultMessagesStream  = '/messages/stream';
  /// 生成诊断报告
  static const aiConsultReport          = '/report';
  /// 查询宠物的全部历史会话列表（POST {pet_id}）
  static const aiConsultSessionByPet    = '/session/by-pet';
  /// 查询指定会话的完整聊天记录（POST {session_id}）
  static const aiConsultSessionMessages = '/session/messages';

  // ── 视频流自动 AI 分析（router_video_stream.py）──────────
  /// 保存/更新自动分析设置（POST JSON body）
  static const autoAnalysisSave   = '/video/stream/auto-analysis/settings/save';
  /// 启用或禁用自动分析设置（POST JSON body）
  static const autoAnalysisToggle = '/video/stream/auto-analysis/settings/disable';
  /// 查询设备任务列表（POST JSON body）
  static const autoAnalysisTasks  = '/video/stream/auto-analysis/tasks';
}
