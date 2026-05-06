/// ════════════════════════════════════════════════════════════
///  IM Controller — 消息模块状态管理
///
///  职责：
///    ✅ 持有会话列表、好友申请、加载状态
///    ✅ 管理 SDK 监听器生命周期（注册/注销）
///    ✅ 驱动 ImRepository 调用，把结果映射到 UI 状态
///    ❌ 不持有 BuildContext（不弹 Dialog / SnackBar）
///    ❌ 不管路由（由 View 层通过 errorMessage 决定跳转）
/// ════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimFriendshipListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import '../data/repository/im_repository.dart';
import '../data/debug_user_sig.dart';
import '../../auth/controller/auth_controller.dart';

// ── 状态类 ────────────────────────────────────────────────
class ImState {
  /// 会话列表（已排序：最新消息在前）
  final List<V2TimConversation> conversations;

  /// 好友申请列表（待处理）
  final List<V2TimFriendApplication> friendApplications;

  /// 是否正在加载会话
  final bool isLoading;

  /// IM 是否已登录
  final bool isLoggedIn;

  /// 错误信息（null = 无错误）
  final String? errorMessage;

  const ImState({
    this.conversations     = const [],
    this.friendApplications = const [],
    this.isLoading         = false,
    this.isLoggedIn        = false,
    this.errorMessage,
  });

  ImState copyWith({
    List<V2TimConversation>? conversations,
    List<V2TimFriendApplication>? friendApplications,
    bool? isLoading,
    bool? isLoggedIn,
    String? errorMessage,
  }) => ImState(
    conversations:      conversations      ?? this.conversations,
    friendApplications: friendApplications ?? this.friendApplications,
    isLoading:          isLoading          ?? this.isLoading,
    isLoggedIn:         isLoggedIn         ?? this.isLoggedIn,
    errorMessage:       errorMessage,       // null 时清除
  );

  /// 未处理的好友申请数量（用于消息 Tab 角标）
  int get pendingFriendCount => friendApplications.length;

  /// 所有会话未读消息总数
  int get totalUnread => conversations.fold(
    0, (sum, c) => sum + (c.unreadCount ?? 0),
  );
}

// ── Controller ────────────────────────────────────────────
class ImController extends StateNotifier<ImState> {
  final ImRepository _repo;
  final Ref _ref;

  /// 会话列表变化监听器（会话页进入时注册，离开时注销）
  V2TimConversationListener? _conversationListener;

  /// 好友申请变化监听器
  V2TimFriendshipListener? _friendListener;

  ImController(this._repo, this._ref) : super(const ImState());

  // ── IM 登录 ──────────────────────────────────────────────
  /// 在用户 PetPogo 登录成功后调用
  ///
  /// UserSig 优先级（三级降级）：
  ///   1. 后端下发的 imUserSig（生产环境标准流程）
  ///   2. Debug 构建时本地生成（测试期间后端未接入时使用）
  ///   3. 以上都没有 → 跳过 IM 登录，记录日志
  Future<void> loginIm({required String userId, required String userSig}) async {
    String? effectiveSig = userSig.isNotEmpty ? userSig : null;

    // 后端 UserSig 为空时，Debug 构建尝试本地生成
    if (effectiveSig == null) {
      effectiveSig = DebugUserSig.generate(userId);
      if (effectiveSig != null) {
        debugPrint('[ImCtrl] 🔧 使用本地生成的 UserSig（仅开发测试）');
      }
    }

    if (effectiveSig == null) {
      debugPrint('[ImCtrl] ⏭️ 无可用 UserSig，跳过 IM 登录'
          '（后端请在登录响应中返回 imUserSig 字段）');
      return;
    }

    final result = await _repo.login(userId: userId, userSig: effectiveSig);
    result.when(
      success: (_) {
        state = state.copyWith(isLoggedIn: true);
        _registerListeners();
      },
      failure: (err) {
        debugPrint('[ImCtrl] IM 登录失败: ${err.message}');
        state = state.copyWith(errorMessage: err.userMessage);
      },
    );

    // 注册 UserSig 过期回调（SDK 级联）
    TencentImSDKPlugin.v2TIMManager.addIMSDKListener(V2TimSDKListener(
      onUserSigExpired: () async {
        debugPrint('[ImCtrl] IM UserSig 已过期，开始静默刷新...');
        final newSig = await _ref
            .read(authControllerProvider.notifier)
            .refreshImUserSig();
        if (newSig != null && newSig.isNotEmpty) {
          debugPrint('[ImCtrl] UserSig 已刷新，重新登录 IM...');
          await loginIm(userId: userId, userSig: newSig);
        } else {
          debugPrint('[ImCtrl] ⚠️ UserSig 刷新失败，需要用户重新登录');
        }
      },
      onKickedOffline: () {
        debugPrint('[ImCtrl] ⚠️ 账号在其他设备登录，已下线');
        state = state.copyWith(
          isLoggedIn: false,
          errorMessage: '账号在其他设备登录，已被踢下线',
        );
      },
    ));
  }

  // ── 会话列表 ─────────────────────────────────────────────
  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true);
    final result = await _repo.fetchConversations();
    result.when(
      success: (list) => state = state.copyWith(
        conversations: list,
        isLoading: false,
      ),
      failure: (err) => state = state.copyWith(
        isLoading: false,
        errorMessage: err.userMessage,
      ),
    );
  }

  // ── 好友申请 ─────────────────────────────────────────────
  Future<void> loadFriendApplications() async {
    final result = await _repo.fetchFriendApplications();
    result.when(
      success: (list) => state = state.copyWith(friendApplications: list),
      failure: (err) => state = state.copyWith(errorMessage: err.userMessage),
    );
  }

  /// 同意好友申请
  Future<void> acceptFriend(String fromUserId) async {
    final result = await _repo.acceptFriend(fromUserId);
    result.when(
      success: (_) {
        // 从申请列表移除，刷新会话
        final updated = state.friendApplications
            .where((a) => a.userID != fromUserId)
            .toList();
        state = state.copyWith(friendApplications: updated);
        loadConversations();
      },
      failure: (err) => state = state.copyWith(errorMessage: err.userMessage),
    );
  }

  /// 拒绝好友申请
  Future<void> refuseFriend(String fromUserId) async {
    final result = await _repo.refuseFriend(fromUserId);
    result.when(
      success: (_) {
        final updated = state.friendApplications
            .where((a) => a.userID != fromUserId)
            .toList();
        state = state.copyWith(friendApplications: updated);
      },
      failure: (err) => state = state.copyWith(errorMessage: err.userMessage),
    );
  }

  /// 添加好友（在社区页点击用户头像时调用）
  Future<bool> addFriend({required String toUserId, String wording = ''}) async {
    final result = await _repo.addFriend(toUserId: toUserId, addWording: wording);
    return result.when(success: (_) => true, failure: (_) => false);
  }

  // ── 标记已读 ─────────────────────────────────────────────
  Future<void> markRead(String userId) async {
    await _repo.markConversationRead(userId);
    // 本地把对应会话的 unreadCount 置 0（避免等待 SDK 回调刷新 UI）
    // V2TimConversation 没有 copyWith，通过 fromJson 克隆并替换字段
    final updated = state.conversations.map((c) {
      if (c.userID == userId && (c.unreadCount ?? 0) > 0) {
        final json = c.toJson();
        json['unreadCount'] = 0;
        return V2TimConversation.fromJson(json);
      }
      return c;
    }).toList();
    state = state.copyWith(conversations: updated);
  }

  // ── 监听器注册 ───────────────────────────────────────────
  void _registerListeners() {
    // 会话列表变化（新消息到来时实时刷新列表）
    _conversationListener = V2TimConversationListener(
      onConversationChanged: (list) {
        if (!mounted) return;
        final updated = Map.fromEntries(
          state.conversations.map((c) => MapEntry(c.conversationID!, c)),
        );
        for (final changed in list) {
          if (changed != null) updated[changed.conversationID!] = changed;
        }
        final sorted = updated.values.toList()
          ..sort((a, b) => (b.orderkey ?? 0).compareTo(a.orderkey ?? 0));
        state = state.copyWith(conversations: sorted);
      },
      onNewConversation: (list) {
        if (!mounted) return;
        loadConversations(); // 新会话直接重新拉取
      },
      onTotalUnreadMessageCountChanged: (count) {
        debugPrint('[ImCtrl] 总未读数变更: $count');
      },
    );
    _repo.addConversationListener(_conversationListener!);

    // 好友申请变化
    _friendListener = V2TimFriendshipListener(
      onFriendApplicationListAdded: (applications) {
        if (!mounted) return;
        final newApps = applications.where((a) => a != null).map((a) => a!).toList();
        final merged = [...state.friendApplications, ...newApps];
        state = state.copyWith(friendApplications: merged);
      },
      onFriendApplicationListDeleted: (userIDs) {
        if (!mounted) return;
        final updated = state.friendApplications
            .where((a) => !userIDs.contains(a.userID))
            .toList();
        state = state.copyWith(friendApplications: updated);
      },
    );
    _repo.addFriendListener(_friendListener!);
  }

  // ── 登出 ─────────────────────────────────────────────────
  Future<void> logoutIm() async {
    _cleanupListeners();
    await _repo.logout();
    state = const ImState();
  }

  void _cleanupListeners() {
    if (_conversationListener != null) {
      _repo.removeConversationListener(_conversationListener!);
      _conversationListener = null;
    }
    if (_friendListener != null) {
      _repo.removeFriendListener(_friendListener!);
      _friendListener = null;
    }
  }

  @override
  void dispose() {
    _cleanupListeners();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────
final imControllerProvider =
    StateNotifierProvider<ImController, ImState>((ref) {
  return ImController(ref.watch(imRepositoryProvider), ref);
});
