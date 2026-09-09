/// 所有 API 路径常量
///
/// 路径常量只保存路径部分（如 '/pets'），
/// 完整地址由 ApiClient 拼接（baseUrl + path）。
/// 注意：语音/图像情绪分析实际直连 AI 网关（AppConfig.aiConsultBaseUrl），
/// 由 ai_repository.dart 拼接完整 URL；本文件仅保留业务后端路径常量。
abstract class ApiEndpoints {
  static const musicList = '/sdkapi/music/list';
  static const musicPlaylists = '/sdkapi/music/playlists';
  static String musicPlaylist(int id) => '/sdkapi/music/playlist/$id';
  static String musicPlaylistAdd(int id) => '${musicPlaylist(id)}/add';
  static String musicPlaylistItem(int id, int musicId) =>
      '${musicPlaylist(id)}/item/$musicId';
  // ── 业务后端（PetPogo 自有服务）────────────────────────
  static const pets = '/pets';
  static const devices = '/devices';
  static const deviceBind = '/devices/bind';
  static const user = '/user/profile';
  static const feedback = '/api/user/feedback';
  static const login = '/auth/login';
  static const logout = '/auth/logout';
  static const community = '/posts';
  static const mallItems = '/mall/products';
  static const storeNearby = '/stores/nearby';

  // 带参数（用方法生成）
  static String petDetail(String id) => '/pets/$id';
  static String deviceDetail(String id) => '/devices/$id';

  // ── OSS 上传签名 ──────────────────────────────────────
  /// 获取预签名上传地址  POST /sdkapi/upload/sign
  static const ossUploadSign = '/sdkapi/upload/sign';

  // ── 媒体库 ──────────────────────────────────────────
  /// 保存图库记录  POST /sdkapi/media/save
  static const mediaSave = '/sdkapi/media/save';

  /// 获取图库列表  GET /sdkapi/media/list
  static const mediaList = '/sdkapi/media/list';

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

  // ── 萌宠圈自动动态 ─────────────────────────────────────
  /// 获取某只宠物的萌宠圈动态  GET /sdkapi/pet-circle/feed
  static const petCircleFeed = '/sdkapi/pet-circle/feed';

  /// 删除萌宠圈动态  DELETE /sdkapi/pet-circle/post/:id
  static String petCirclePostDelete(String id) => '/sdkapi/pet-circle/post/$id';

  // ── 声音预设 ───────────────────────────────────────
  /// 获取声音预设列表  GET /sdkapi/sound/preset/list
  static const soundPresetList = '/sdkapi/sound/preset/list';

  // ── 分享落地页 / App 内解析 ──────────────────────────────
  /// 创建分享卡片链接  POST /sdkapi/share/create
  static const shareCreate = '/sdkapi/share/create';

  /// 打开 App 后解析分享码  GET /sdkapi/share/resolve
  static const shareResolve = '/sdkapi/share/resolve';

  // ── 宠小伊 AI 问诊（独立后端 AppConfig.aiConsultBaseUrl）─
  /// 创建新 session（POST JSON body {pet_id}，v0.4 改为 POST）
  static const aiConsultSessionNew = '/session/new';

  /// 删除 session（POST JSON body {session_id}）
  static const aiConsultSessionDelete = '/session/delete';

  /// 同步问诊（一次性返回，调试/降级用）
  static const aiConsultMessages = '/messages';

  /// 流式问诊（SSE，主入口）
  static const aiConsultMessagesStream = '/messages/stream';

  /// 生成诊断报告
  static const aiConsultReport = '/report';

  /// 查询宠物的全部历史会话列表（POST {pet_id}）
  static const aiConsultSessionByPet = '/session/by-pet';

  /// 查询指定会话的完整聊天记录（POST {session_id}）
  static const aiConsultSessionMessages = '/session/messages';

  // ── 视频流自动 AI 分析（router_video_stream.py）──────────
  /// 保存/更新自动分析设置（POST JSON body）
  static const autoAnalysisSave = '/video/stream/auto-analysis/settings/save';

  /// 启用或禁用自动分析设置（POST JSON body）
  static const autoAnalysisToggle =
      '/video/stream/auto-analysis/settings/disable';

  /// 查询设备任务列表（POST JSON body）
  static const autoAnalysisTasks = '/video/stream/auto-analysis/tasks';

  // ── 音频流自动 AI 分析（自动打招呼）──────────────────────
  /// 保存/更新音频流自动分析设置（POST JSON body）
  static const voiceAnalysisSave = '/voice/stream/auto-analysis/settings/save';

  /// 启用或禁用音频流自动分析设置（POST JSON body）
  static const voiceAnalysisToggle =
      '/voice/stream/auto-analysis/settings/disable';

  // ── 手动录制声网音视频流（router_video_recording.py）───
  /// 开始录制设备音视频流  POST /video/recording/start
  static const recordingStart = '/video/recording/start';

  /// 结束录制并合成 MP4   POST /video/recording/stop
  static const recordingStop = '/video/recording/stop';

  // ── 积分系统 ────────────────────────────────────────────
  /// 积分余额（周积分/永久积分/总计）  GET /sdkapi/points/balance
  static const pointsBalance = '/sdkapi/points/balance';

  /// 积分流水（分页）  GET /sdkapi/points/list
  static const pointsList = '/sdkapi/points/list';

  /// 积分消费规则  GET /sdkapi/points/rules
  static const pointsRules = '/sdkapi/points/rules';

  // ── 购买计划（会员）─────────────────────────────────────
  /// 计划列表（Free/Pro/ProMax）  GET /sdkapi/plan/list
  static const planList = '/sdkapi/plan/list';

  /// 生成购买订单（占位订单，需后台人工确认）  POST /sdkapi/plan/order
  static const planOrder = '/sdkapi/plan/order';

  /// 查询订单状态（轮询用）  GET /sdkapi/plan/order/:orderId
  static String planOrderDetail(String orderId) =>
      '/sdkapi/plan/order/$orderId';

  // ── 每日签到 ────────────────────────────────────────────
  /// 签到状态 + 奖励档位  GET /sdkapi/checkin/status
  static const checkInStatus = '/sdkapi/checkin/status';

  /// 月签到日历（每天 status + 补签配额 + 奖励按钮）  GET /sdkapi/checkin/calendar
  static const checkInCalendar = '/sdkapi/checkin/calendar';

  /// 执行签到  POST /sdkapi/checkin/signin
  static const checkInSignIn = '/sdkapi/checkin/signin';

  /// 领取签到奖励  POST /sdkapi/checkin/claim
  static const checkInClaim = '/sdkapi/checkin/claim';

  /// 补签（会员配额）POST /sdkapi/checkin/makeup
  /// body: { date: 'YYYY-MM-DD' }，配额用尽返回 402 → 引导看广告
  static const checkInMakeup = '/sdkapi/checkin/makeup';

  // ── 设备事件（系统通知）────────────────────────────────
  /// 设备事件列表  GET /sdkapi/device-event/list
  /// query: type(breach/offline/low_battery)?, page, page_size
  /// → { list:[{id,type,pet_name,device_mac,device_name,device_product_key,desc,time,read}], total, page }
  static const deviceEventList = '/sdkapi/device-event/list';

  /// 标记单条已读  POST /sdkapi/device-event/read
  /// body: { event_id }
  static const deviceEventRead = '/sdkapi/device-event/read';

  /// 标记全部已读  POST /sdkapi/device-event/read-all
  static const deviceEventReadAll = '/sdkapi/device-event/read-all';
}
