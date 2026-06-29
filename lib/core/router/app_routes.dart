/// 所有路由路径常量 — 避免硬编码字符串分散在各页面
/// 用法：context.go(AppRoutes.home)
///       context.push(AppRoutes.petDetail('abc123'))
abstract class AppRoutes {
  // ── Tab 主页 ─────────────────────────────────────────
  static const home = '/';
  static const message = '/message';
  static const community = '/community';
  static const petCircle = '/pet-circle';
  static const mall = '/mall';
  static const profile = '/profile';

  // ── 分享落地 ────────────────────────────────────────────
  static const share = '/share';

  // ── 启动页 ────────────────────────────────────────────
  static const splash = '/splash'; // 启动 Logo 页（认证状态恢复期间显示）

  // ── 子页面 ────────────────────────────────────────────
  static const settings = '/settings';
  static const addPet = '/add-pet';
  static const bindDevice = '/bind-device';
  static const login = '/login'; // 登录页

  // ── 宠小伊 AI 问诊 ──────────────────────────────────────
  /// 主聊天页（extra: 宠物 petId 字符串）
  static const consultation = '/consultation';

  /// 宠小伊问诊报告详情页（extra: ConsultationReport 对象）
  static const reportDiagnosis = '/consultation/report/diagnosis';

  /// 治疗养护建议页（extra: ConsultationReport 对象）
  static const reportCare = '/consultation/report/care';

  /// 医疗检测方案页（extra: ConsultationReport 对象）
  static const reportMedical = '/consultation/report/medical';

  // ── 带参数路由（用方法生成，杜绝拼错） ──────────────
  static String scanQr(String productKey) => '/scan-qr/$productKey';
  static String bindSuccess(String productKey) => '/bind-success/$productKey';
  static String petDetail(String petId) => '/pet-detail/$petId';
  static String postDetail(String postId) => '/post-detail/$postId';
  static String chat(String userId) => '/chat/$userId'; // IM 聊天页
  static const myQrCode = '/my-qr-code'; // 我的二维码名片
  static String addFriendByQr(String userId) =>
      '/add-friend-qr/$userId'; // 扫码后加好友
  static String deviceDetail(String mac) => '/device/$mac'; // 设备详情（push 跳转）
  static String shareLanding({required String code, String? type}) {
    final params = {
      'code': code,
      if (type != null && type.isNotEmpty) 'type': type,
    };
    return Uri(path: share, queryParameters: params).toString();
  }

  // ── 路由模板（GoRoute path 用） ─────────────────────
  static const scanQrTemplate = '/scan-qr/:productKey';
  static const bindSuccessTemplate = '/bind-success/:productKey';
  static const petDetailTemplate = '/pet-detail/:petId';
  static const postDetailTemplate = '/post-detail/:postId';
  static const chatTemplate = '/chat/:userId'; // IM 聊天页
  static const addFriendByQrTemplate = '/add-friend-qr/:userId'; // 扫码加好友
  static const deviceDetailTemplate = '/device/:mac'; // 设备详情（push 跳转）
}
