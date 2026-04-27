/// ════════════════════════════════════════════════════════════
///  认证 Controller — 状态管理层
///
///  职责：
///    ✅ 管理认证状态（游客 / 登录中 / 已登录 / 错误）
///    ✅ 登录成功后触发设备和宠物数据加载
///    ✅ 应用启动时自动恢复会话
///    ❌ 不直接调用 HTTP（通过 Repository）
///    ❌ 不处理 UI（View 监听 state 自行更新）
///
///  状态流转：
///    启动 → restoring → guest（无会话）或 loggedIn（有会话）
///    登录 → loading → loggedIn（成功）或 error（失败）
///    退出 → guest
/// ════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_model.dart';
import '../../message/controller/im_controller.dart';

// ── 认证状态枚举 ────────────────────────────────────────────
enum AuthStatus {
  restoring,  // 启动时从存储恢复（短暂的中间态）
  guest,      // 游客（未登录）
  loading,    // 登录请求进行中
  loggedIn,   // 已登录
  error,      // 登录失败
}

// ── 认证状态类 ──────────────────────────────────────────────
class AuthState {
  final AuthStatus status;
  final UserInfo? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  /// 便捷判断
  bool get isGuest    => status == AuthStatus.guest;
  bool get isLoggedIn => status == AuthStatus.loggedIn;
  bool get isLoading  => status == AuthStatus.loading;

  /// 当前用户名（未登录时为空字符串）
  String get displayName => user?.name ?? '';

  AuthState copyWith({
    AuthStatus? status,
    UserInfo? user,
    String? errorMessage,
  }) => AuthState(
    status:       status       ?? this.status,
    user:         user         ?? this.user,
    errorMessage: errorMessage,   // 允许置 null
  );

  // 工厂方法（语义清晰）
  const AuthState.restoring() : this(status: AuthStatus.restoring);
  const AuthState.guest()     : this(status: AuthStatus.guest);
}

// ── Controller ──────────────────────────────────────────────
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthController(this._repo, this._ref)
      : super(const AuthState.restoring()) {
    // App 启动时自动恢复会话
    _restoreSession();
  }

  // ── 启动时恢复会话 ─────────────────────────────────────
  Future<void> _restoreSession() async {
    debugPrint('[AuthCtrl] [状态] restoring → 检查本地会话...');
    final user = await _repo.restoreSession();
    if (user != null) {
      debugPrint('[AuthCtrl] [状态] restoring → loggedIn (${user.name})');
      state = AuthState(status: AuthStatus.loggedIn, user: user);
      _loadUserData();
    } else {
      debugPrint('[AuthCtrl] [状态] restoring → guest (无本地会话)');
      state = const AuthState.guest();
    }
  }

  // ── 登录 ───────────────────────────────────────────────
  Future<void> login({
    required String account,
    required String password,
  }) async {
    debugPrint('[AuthCtrl] [状态] → loading (account=$account)');
    state = state.copyWith(status: AuthStatus.loading);

    final result = await _repo.login(account: account, password: password);

    result.when(
      success: (user) {
        debugPrint('[AuthCtrl] [状态] loading → loggedIn (${user.name} / merchantId=${user.merchantId})');
        state = AuthState(status: AuthStatus.loggedIn, user: user);
        _loadUserData();
      },
      failure: (err) {
        debugPrint('[AuthCtrl] [状态] loading → error (${err.message})');
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: err.userMessage,
        );
      },
    );
  }

  // ── 退出登录 ───────────────────────────────────────────
  Future<void> logout() async {
    debugPrint('[AuthCtrl] [状态] loggedIn → guest (退出登录)');
    await _repo.logout();
    state = const AuthState.guest();
  }

  // ── 登录后触发数据加载 ─────────────────────────────────
  /// 登录成功 / 会话恢复后，加载用户相关数据
  ///
  /// 这里集中管理"登录后需要做什么"，便于扩展
  void _loadUserData() {
    final user = state.user;
    if (user == null) return;

    // ① IM 登录（Debug 时自动用本地生成的 UserSig）
    _ref.read(imControllerProvider.notifier).loginIm(
      userId: user.merchantId.toString(),
      userSig: user.imUserSig ?? '',   // 后端接入后会有实际値
    );

    // TODO: 设备列表（接口就绪后取消注释）
    // _ref.read(deviceListProvider.notifier).fetchAll();

    // TODO: 宠物列表（接口就绪后取消注释）
    // _ref.read(petListProvider.notifier).fetchAll();

    debugPrint('[AuthCtrl] 触发 IM 登录 (userId=${user.merchantId})');
  }
}

// ── Provider ─────────────────────────────────────────────
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.read(authRepositoryProvider),
    ref,
  );
});

/// 便捷只读 Provider（View 只需要监听状态，不操作）
final authStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authControllerProvider);
});

/// 是否已登录（用于路由守卫 / UI 条件渲染）
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isLoggedIn;
});
