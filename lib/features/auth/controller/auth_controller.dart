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
import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_model.dart';
import '../../message/controller/im_controller.dart';
import '../../pet/controller/pet_controller.dart';
import '../../device/data/repository/device_repository.dart';
import '../../profile/data/user_stats_provider.dart';

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
  bool get isGuest      => status == AuthStatus.guest;
  bool get isLoggedIn   => status == AuthStatus.loggedIn;
  bool get isLoading    => status == AuthStatus.loading;
  bool get isRestoring  => status == AuthStatus.restoring;

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

  Future<void> loginWithSms({
    required String phone,
    required String code,
  }) async {
    debugPrint('[AuthCtrl] [状态] → loading (phone=$phone, type=sms)');
    state = state.copyWith(status: AuthStatus.loading);

    final result = await _repo.loginWithSms(phone: phone, code: code);

    result.when(
      success: (user) {
        debugPrint('[AuthCtrl] [状态] loading → loggedIn (${user.name})');
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

  Future<void> loginWithPwd({
    required String phone,
    required String password,
  }) async {
    debugPrint('[AuthCtrl] [状态] → loading (phone=$phone, type=pwd)');
    state = state.copyWith(status: AuthStatus.loading);

    final result = await _repo.loginWithPwd(phone: phone, password: password);

    result.when(
      success: (user) {
        debugPrint('[AuthCtrl] [状态] loading → loggedIn (${user.name})');
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

  Future<String?> sendSms(String phone) async {
    final result = await _repo.sendSms(phone);
    return result.when(
      success: (_) => null,
      failure: (err) => err.userMessage,
    );
  }

  // legacy compatibility
  Future<void> login({
    required String account,
    required String password,
  }) async {
    return loginWithPwd(phone: account, password: password);
  }

  // ── JWT 过期强制登出（由 _ErrorInterceptor 401 触发）──────
  /// 不弹对话框，直接清除本地状态 → guest
  /// UI 层监听 isGuest 后自动提示重新登录
  Future<void> forceLogout() async {
    debugPrint('[AuthCtrl] JWT 已过期，强制登出');
    await _repo.logout();
    state = const AuthState(
      status: AuthStatus.guest,
      errorMessage: '登录已过期，请重新验证',
    );
  }

  // ── IM UserSig 过期刷新（无需重新登录）──────────────────
  /// 由 ImController 的 onUserSigExpired 回调触发
  /// 返回新的 UserSig，失败返回 null
  Future<String?> refreshImUserSig() async {
    final result = await _repo.refreshImUserSig();
    return result.when(
      success: (sig) => sig,
      failure: (err) {
        debugPrint('[AuthCtrl] ⚠️ 刷新 UserSig 失败: ${err.message}');
        return null;
      },
    );
  }

  // ── 退出登录 ───────────────────────────────────────────
  Future<void> logout() async {
    debugPrint('[AuthCtrl] [状态] loggedIn → guest (退出登录)');
    await _repo.logout();
    state = const AuthState.guest();
  }

  // ── 刷新用户资料（改昵称后调用）────────────────────────
  Future<void> refreshUser() async {
    final updated = await _repo.fetchProfile();
    if (updated != null) {
      state = state.copyWith(user: updated);
      debugPrint('[AuthCtrl] 用户资料已刷新: ${updated.name}');
    }
  }

  // ── 更新头像（上传 OSS 后调用）────────────────────────
  Future<bool> updateAvatar(String avatarUrl) async {
    final ok = await _repo.updateAvatar(avatarUrl);
    if (ok && state.user != null) {
      state = state.copyWith(user: state.user!.copyWith(avatar: avatarUrl));
      debugPrint('[AuthCtrl] 头像 state 已更新: $avatarUrl');
    }
    return ok;
  }

  // ── 登录后触发数据加载 ─────────────────────────────────
  /// 登录成功 / 会话恢复后，并行加载用户相关数据
  void _loadUserData() {
    final user = state.user;
    if (user == null) return;

    // ① IM 登录
    final imUserId  = user.id.isNotEmpty ? user.id : user.merchantId.toString();
    final imUserSig = user.imUserSig;
    if (imUserSig.isNotEmpty) {
      _ref.read(imControllerProvider.notifier).loginIm(
        userId:  imUserId,
        userSig: imUserSig,
      );
      debugPrint('[AuthCtrl] 触发 IM 登录 (userId=$imUserId)');
    } else {
      debugPrint('[AuthCtrl] ⚠️ imUserSig 为空，跳过 IM 登录');
    }

    // ② 并行拉取：宠物列表 / 设备列表 / 用户统计
    _ref.read(petControllerProvider.notifier).loadPets();
    _ref.read(deviceListProvider.notifier).load();
    _ref.read(userStatsProvider.notifier).loadMyStats();

    debugPrint('[AuthCtrl] 并行加载: 宠物 / 设备 / 用户统计');
  }
}

// ── Provider ─────────────────────────────────────────────
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(
    ref.read(authRepositoryProvider),
    ref,
  );
  // 注入 JWT 401 → forceLogout 回调
  // ApiClient 持有回调函数指针，不直接引用 Riverpod，避免循环依赖
  ref.read(apiClientProvider).onUnauthorized = () {
    controller.forceLogout();
  };
  return controller;
});

/// 便捷只读 Provider（View 只需要监听状态，不操作）
final authStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authControllerProvider);
});

/// 是否已登录（用于路由守卫 / UI 条件渲染）
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isLoggedIn;
});
