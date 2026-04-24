/// 所有路由路径常量 — 避免硬编码字符串分散在各页面
/// 用法：context.go(AppRoutes.home)
///       context.push(AppRoutes.petDetail('abc123'))
abstract class AppRoutes {
  // ── Tab 主页 ─────────────────────────────────────────
  static const home      = '/';
  static const message   = '/message';
  static const community = '/community';
  static const mall      = '/mall';
  static const profile   = '/profile';

  // ── 子页面 ────────────────────────────────────────────
  static const settings    = '/settings';
  static const addPet      = '/add-pet';
  static const bindDevice  = '/bind-device';
  static const login       = '/login';   // 登录页

  // ── 带参数路由（用方法生成，杜绝拼错） ──────────────
  static String scanQr(String deviceType)    => '/scan-qr/$deviceType';
  static String bindSuccess(String deviceType) => '/bind-success/$deviceType';
  static String petDetail(String petId)      => '/pet-detail/$petId';
  static String postDetail(String postId)    => '/post-detail/$postId';

  // ── 路由模板（GoRoute path 用） ─────────────────────
  static const scanQrTemplate      = '/scan-qr/:deviceType';
  static const bindSuccessTemplate = '/bind-success/:deviceType';
  static const petDetailTemplate   = '/pet-detail/:petId';
  static const postDetailTemplate  = '/post-detail/:postId';
}
