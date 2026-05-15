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

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/pet_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimFriendshipListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import '../data/repository/im_repository.dart';
import '../data/debug_user_sig.dart';
import '../../auth/controller/auth_controller.dart';
import '../../../app.dart' show globalNavigatorKey;

// ── 系统通知模型（点赞 / 评论 / 好友申请）────────────────────
class ImSystemNotice {
  final String type;        // 'post_like' | 'post_comment' | 'friend_request'
  final String action;      // 'like' | 'unlike' | 'comment'（默认 'like'/'comment'）
  final String fromName;    // 发送人昵称
  final String postContent; // 帖子内容摘要（最多20字，可能为空）
  final String content;     // 最终展示文案
  final DateTime time;

  const ImSystemNotice({
    required this.type,
    this.action = '',
    required this.fromName,
    this.postContent = '',
    required this.content,
    required this.time,
  });

  /// 是否为点赞类通知
  bool get isLike    => type == 'post_like';
  bool get isComment => type == 'post_comment';
  bool get isFriend  => type == 'friend_request';
  bool get isUnlike  => type == 'post_like' && action == 'unlike';
}

// ── 状态类 ────────────────────────────────────────────────
class ImState {
  /// 会话列表（已排序：最新消息在前）
  final List<V2TimConversation> conversations;

  /// 好友申请列表（待处理）
  final List<V2TimFriendApplication> friendApplications;

  /// 系统通知（点赞 / 评论 / 好友申请等，最新在前，最多保留 50 条）
  final List<ImSystemNotice> systemNotices;

  /// 是否正在加载会话
  final bool isLoading;

  /// IM 是否已登录
  final bool isLoggedIn;

  /// 错误信息（null = 无错误）
  final String? errorMessage;

  const ImState({
    this.conversations      = const [],
    this.friendApplications = const [],
    this.systemNotices      = const [],
    this.isLoading          = false,
    this.isLoggedIn         = false,
    this.errorMessage,
  });

  ImState copyWith({
    List<V2TimConversation>? conversations,
    List<V2TimFriendApplication>? friendApplications,
    List<ImSystemNotice>? systemNotices,
    bool? isLoading,
    bool? isLoggedIn,
    String? errorMessage,
  }) => ImState(
    conversations:      conversations      ?? this.conversations,
    friendApplications: friendApplications ?? this.friendApplications,
    systemNotices:      systemNotices      ?? this.systemNotices,
    isLoading:          isLoading          ?? this.isLoading,
    isLoggedIn:         isLoggedIn         ?? this.isLoggedIn,
    errorMessage:       errorMessage,
  );

  /// 未处理的好友申请数量（用于消息 Tab 角标）
  int get pendingFriendCount => friendApplications.length;

  /// 所有会话未读消息总数
  int get totalUnread => conversations.fold(
    0, (sum, c) => sum + (c.unreadCount ?? 0),
  );

  /// 最新点赞通知
  ImSystemNotice? get latestLike =>
      systemNotices.where((n) => n.isLike).firstOrNull;

  /// 最新评论通知
  ImSystemNotice? get latestComment =>
      systemNotices.where((n) => n.isComment).firstOrNull;

  /// 未读系统通知数（用于角标）
  int get unreadNoticeCount => systemNotices.length;
}

// ── Controller ────────────────────────────────────────────
class ImController extends StateNotifier<ImState> {
  final ImRepository _repo;
  final Ref _ref;

  /// 会话列表变化监听器
  V2TimConversationListener? _conversationListener;

  /// 好友申请变化监听器
  V2TimFriendshipListener? _friendListener;

  /// 系统消息监听器（点赞/评论）
  V2TimAdvancedMsgListener? _systemMsgListener;

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

    final sigSource = userSig.isNotEmpty ? '后端下发' : '本地生成(Debug)';
    debugPrint('[ImCtrl] 🔑 IM 登录 userId=$userId sigSource=$sigSource '
        'sig前16位=${effectiveSig.substring(0, effectiveSig.length.clamp(0, 16))}');

    final result = await _repo.login(userId: userId, userSig: effectiveSig);
    result.when(
      success: (_) {
        state = state.copyWith(isLoggedIn: true);
        _registerListeners();
        // ✅ 登录后同步昵称&头像到 IM，好友列表 userProfile.nickName 才有值
        final user = _ref.read(authControllerProvider).user;
        // ══ 关键日志：多设备对比用 ══
        debugPrint('┌─────────────────────────────────────────');
        debugPrint('│ 🐾 当前账号 userId=$userId');
        debugPrint('│    昵称=${user?.name ?? "未知"} account=${user?.account ?? ""}');
        debugPrint('└─────────────────────────────────────────');
        if (user != null && user.name.isNotEmpty) {
          _repo.updateSelfProfile(
            nickname: user.name,
            faceUrl: user.avatar.isNotEmpty ? user.avatar : null,
          );
        }
        // ✅ 主动拉取一次好友申请 + 会话列表（新设备登录时本地无缓存）
        loadFriendApplications();
        loadConversations();
        // iOS SDK 数据同步有延迟，延迟 3s 再补拉一次
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            debugPrint('[ImCtrl] ⏰ 延迟补拉好友申请（iOS SDK 同步保障）');
            loadFriendApplications();
          }
        });
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
      onKickedOffline: () async {
        debugPrint('[ImCtrl] ⚠️ 账号在其他设备登录，已下线');
        state = state.copyWith(
          isLoggedIn: false,
          errorMessage: '账号在其他设备登录',
        );
        final ctx = globalNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          await showDialog<void>(
            context: ctx,
            barrierDismissible: false,
            barrierColor: Colors.black.withOpacity(0.65),
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // 图标
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.devices_other_rounded,
                        color: Colors.redAccent, size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text('账号已在其他设备登录',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '当前设备已自动退出登录。\n如非本人操作，请尽快修改密码。',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13, color: Colors.white.withOpacity(0.55),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.18),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(_).pop(),
                      child: const Text('我知道了',
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ]),
              ),
            ),
          );
        }
        await _ref.read(authControllerProvider.notifier).logout();
      },
    ));
  }

  // ── 会话列表 ─────────────────────────────────────────────
  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true);
    final result = await _repo.fetchConversations();
    result.when(
      success: (list) {
        // 过滤掉因 friend_rejected / friend_accepted 自定义消息产生的系统会话
        final cleaned = list.where((conv) {
          final last = conv.lastMessage;
          if (last == null) return true;
          if (last.elemType != 2) return true;
          final raw = last.customElem?.data ?? '';
          return !raw.contains('friend_rejected') && !raw.contains('friend_accepted');
        }).toList();
        state = state.copyWith(conversations: cleaned, isLoading: false);
        // 同步删除 SDK 里的这些残留会话
        for (final conv in list) {
          if (!cleaned.contains(conv) && conv.conversationID != null) {
            TencentImSDKPlugin.v2TIMManager
                .getConversationManager()
                .deleteConversation(conversationID: conv.conversationID!)
                .catchError((_, __) => null);
          }
        }
      },
      failure: (err) => state = state.copyWith(
        isLoading: false,
        errorMessage: err.userMessage,
      ),
    );
  }

  // ── 好友申请 ─────────────────────────────────────────────
  Future<void> loadFriendApplications() async {
    debugPrint('[ImCtrl] 📥 拉取好友申请列表...');
    final result = await _repo.fetchFriendApplications();
    result.when(
      success: (list) {
        debugPrint('[ImCtrl] 好友申请: 共 ${list.length} 条');
        state = state.copyWith(friendApplications: list);
      },
      failure: (err) {
        debugPrint('[ImCtrl] 好友申请加载失败: ${err.message}');
        state = state.copyWith(errorMessage: err.userMessage);
      },
    );
  }

  /// 同意好友申请
  Future<void> acceptFriend(String fromUserId) async {
    final result = await _repo.acceptFriend(fromUserId);
    result.when(
      success: (_) async {
        final updated = state.friendApplications
            .where((a) => a.userID != fromUserId)
            .toList();
        state = state.copyWith(friendApplications: updated);
        // 发自定义消息让申请方收到「已同意」通知
        final self = _ref.read(authControllerProvider).user;
        final myName = self?.name ?? '对方';
        await _repo.sendCustomMessage(
          toUserId: fromUserId,
          data: {'type': 'friend_accepted', 'fromName': myName},
        );
        // 删除因通知消息产生的临时 c2c 会话
        try {
          await TencentImSDKPlugin.v2TIMManager
              .getConversationManager()
              .deleteConversation(conversationID: 'c2c_$fromUserId');
        } catch (_) {}
        loadConversations();
      },
      failure: (err) => state = state.copyWith(errorMessage: err.userMessage),
    );
  }

  /// 拒绝好友申请，并通过自定义消息通知对方（SDK 不会自动推送拒绝结果）
  Future<void> refuseFriend(String fromUserId) async {
    final result = await _repo.refuseFriend(fromUserId);
    result.when(
      success: (_) async {
        final updated = state.friendApplications
            .where((a) => a.userID != fromUserId)
            .toList();
        state = state.copyWith(friendApplications: updated);
        // 发一条自定义消息让对方知道被拒绝
        final self = _ref.read(authControllerProvider).user;
        final myName = self?.name ?? '对方';
        await _repo.sendCustomMessage(
          toUserId: fromUserId,
          data: {'type': 'friend_rejected', 'fromName': myName},
        );
        debugPrint('[ImCtrl] 已发拒绝通知给 $fromUserId');
        // 拒绝方删除就己侧与对方的 c2c 会话（避免空白会话条目）
        try {
          await TencentImSDKPlugin.v2TIMManager
              .getConversationManager()
              .deleteConversation(conversationID: 'c2c_$fromUserId');
          debugPrint('[ImCtrl] 已删除拒绝方的 c2c 会话');
        } catch (e) {
          debugPrint('[ImCtrl] 删除会话失败: $e');
        }
        loadConversations(); // 刷新会话列表
      },
      failure: (err) => state = state.copyWith(errorMessage: err.userMessage),
    );
  }

  /// 添加好友（在社区页点击用户头像时调用）
  Future<bool> addFriend({required String toUserId, String wording = ''}) async {
    final result = await _repo.addFriend(toUserId: toUserId, addWording: wording);
    return result.when(success: (_) => true, failure: (_) => false);
  }

  /// 删除好友
  Future<bool> deleteFriend(String userId) async {
    final result = await _repo.deleteFriend(userId);
    return result.when(success: (_) => true, failure: (_) => false);
  }

  /// 拉黑用户
  Future<bool> addToBlackList(String userId) async {
    final result = await _repo.addToBlackList(userId);
    return result.when(success: (_) => true, failure: (_) => false);
  }

  /// 检查是否已是好友
  Future<bool> checkIsFriend(String userId) => _repo.checkIsFriend(userId);

  // ―― 清除互动通知未读（点击互动通知区域后调用） ――――――――――――――――――――
  void clearInteractNotices() {
    state = state.copyWith(systemNotices: []);
  }

  // ―― 删除指定索引的通知（右滑删除） ―――――――――――――――――――――――――――――
  void removeSystemNotice(int index) {
    final updated = [...state.systemNotices]..removeAt(index);
    state = state.copyWith(systemNotices: updated);
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

  // ── 自动清理系统消息产生的临时会话 ───────────────────────────
  /// 如果一个 c2c 会话的最后一条消息是 friend_rejected 自定义消息，
  /// 说明这是拒绝通知产生的副产品，立即删除。
  void _autoCleanSystemConvs(List<V2TimConversation> convs) {
    for (final conv in convs) {
      final convId = conv.conversationID;
      if (convId == null || !convId.startsWith('c2c_')) continue;
      final lastMsg = conv.lastMessage;
      if (lastMsg == null) continue;
      if (lastMsg.elemType != 2) continue;
      final raw = lastMsg.customElem?.data ?? '';
      if (raw.contains('friend_rejected') || raw.contains('friend_accepted')) {
        final uid = convId.replaceFirst('c2c_', '');
        debugPrint('[ImCtrl] 自动清理系统消息会话: $convId');
        TencentImSDKPlugin.v2TIMManager
            .getConversationManager()
            .deleteConversation(conversationID: convId)
            .catchError((_, __) => null)
            .then((_) => loadConversations());
        // 同时从本地 state 里移除，立即刷新 UI
        final filtered = state.conversations
            .where((c) => c.userID != uid)
            .toList();
        state = state.copyWith(conversations: filtered);
      }
    }
  }

  // ── 监听器注册 ───────────────────────────────────────────
  void _registerListeners() {
    // 会话列表变化（新消息到来时实时刷新列表）
    _conversationListener = V2TimConversationListener(
      onConversationChanged: (list) {
        if (!mounted) return;
        _autoCleanSystemConvs(list.whereType<V2TimConversation>().toList());
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
        _autoCleanSystemConvs(list.whereType<V2TimConversation>().toList());
        loadConversations();
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
        debugPrint('[ImCtrl] onFriendApplicationListAdded: '
            '总共 ${applications.length} 条 → ${ applications.map((a) => "uid=${a?.userID} type=${a?.type}").join(", ")}');
        // 只处理别人发给我的申请（type == 1 COME_IN）
        final incoming = applications
            .where((a) => a != null && a.type == 1)
            .map((a) => a!)
            .toList();
        if (incoming.isEmpty) return;
        // 去重：避免同一 userID 重复添加
        final existingIds = state.friendApplications.map((a) => a.userID).toSet();
        final newApps = incoming.where((a) => !existingIds.contains(a.userID)).toList();
        if (newApps.isEmpty) return;
        final merged = [...state.friendApplications, ...newApps];
        state = state.copyWith(friendApplications: merged);
        // 当有新申请来了，给被申请方弹出 PetToast
        for (final app in newApps) {
          final senderName = app.nickname ?? app.userID ?? '某用户';
          final ctx = globalNavigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            PetToast.show(ctx, '🐾 $senderName 向你申请加好友');
          }
          break; // 多条申请只弹一个提示
        }
      },
      onFriendApplicationListDeleted: (userIDs) async {
        if (!mounted) return;
        // 从「收到的申请」中移除（被我处理掉的）
        final incomingIds = state.friendApplications.map((a) => a.userID).toSet();
        final updated = state.friendApplications
            .where((a) => !userIDs.contains(a.userID))
            .toList();
        state = state.copyWith(friendApplications: updated);

        // 对于「不在我的收到列表里」的 userID，说明是我「发出的申请」被对方处理了
        // → 重新拉一次好友列表判断是否已成为好友
        for (final uid in userIDs) {
          if (!incomingIds.contains(uid)) {
            final accepted = await _repo.checkIsFriend(uid);
            String peerName = uid;
            try {
              final r = await TencentImSDKPlugin.v2TIMManager
                  .getUsersInfo(userIDList: [uid]);
              peerName = r.data?.firstOrNull?.nickName ?? uid;
            } catch (_) {}

            if (accepted) {
              debugPrint('[ImCtrl] 好友申请被同意 (SDK删除回调): $peerName');
            } else {
              // 拒绝通知已由 friend_rejected 自定义消息处理，这里不再弹 Toast
              debugPrint('[ImCtrl] 好友申请被拒绝 (SDK删除回调): $peerName');
            }
          }
        }
      },
    );
    _repo.addFriendListener(_friendListener!);

    // ── 系统消息（点赞 / 评论通知，后端用 TIMCustomElem 发送）──
    _systemMsgListener = V2TimAdvancedMsgListener(
      onRecvNewMessage: (msg) async {
        if (!mounted) return;
        // 过滤自己发出的消息（SDK 在 onlineUserOnly=false 时会同步给发送方）
        final myImId = _ref.read(authControllerProvider).user?.imUserId ?? '';
        if (msg.sender == myImId) {
          debugPrint('[ImCtrl] onRecvNewMessage 跳过自发消息 sender=${msg.sender}');
          return;
        }
        // 只处理自定义消息（后端系统通知）
        final customData = msg.customElem?.data;
        debugPrint('[ImCtrl] onRecvNewMessage elemType=${msg.elemType} '
            'sender=${msg.sender} customData=$customData');
        if (customData == null || customData.isEmpty) return;
        try {
          final json = jsonDecode(customData) as Map<String, dynamic>;
          final type = json['type'] as String? ?? '';
          debugPrint('[ImCtrl] custom msg type=$type fromName=${json["fromName"]}');
          if (type != 'post_like' && type != 'post_comment'
              && type != 'friend_rejected' && type != 'friend_accepted') return;

          final fromName = json['fromName'] as String? ?? json['nickname'] as String? ?? '对方';

          // ── 好友申请被拒绝通知（只有申请方能收到）──────────────
          if (type == 'friend_rejected') {
            // 写入 systemNotices，让申请方在「发出的」看到拒绝记录
            final notice = ImSystemNotice(
              type:        'friend_result',
              action:      'rejected',
              fromName:    fromName,
              postContent: '',
              content:     '$fromName 拒绝了你的好友申请',
              time:        DateTime.now(),
            );
            final notices = [notice, ...state.systemNotices].take(50).toList();
            state = state.copyWith(systemNotices: notices);
            debugPrint('[ImCtrl] 好友申请被拒绝通知: $fromName');
            final ctx = globalNavigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              PetToast.error(ctx, '$fromName 拒绝了你的好友申请');
            }
            final sender = msg.sender ?? '';
            if (sender.isNotEmpty) {
              try {
                await TencentImSDKPlugin.v2TIMManager
                    .getConversationManager()
                    .deleteConversation(conversationID: 'c2c_$sender');
              } catch (_) {}
            }
            loadConversations();
            return;
          }

          // ── 好友申请已通过通知 ──────────────────────────────
          if (type == 'friend_accepted') {
            final notice = ImSystemNotice(
              type:        'friend_result',
              action:      'accepted',
              fromName:    fromName,
              postContent: '',
              content:     '$fromName 同意了你的好友申请',
              time:        DateTime.now(),
            );
            final notices = [notice, ...state.systemNotices].take(50).toList();
            state = state.copyWith(systemNotices: notices);
            // 弹出 PetToast 应答申请方
            final ctx = globalNavigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              PetToast.success(ctx, '🎉 $fromName 同意了你的好友申请');
            }
            // 删除临时会话
            final sender = msg.sender ?? '';
            if (sender.isNotEmpty) {
              try {
                await TencentImSDKPlugin.v2TIMManager
                    .getConversationManager()
                    .deleteConversation(conversationID: 'c2c_$sender');
              } catch (_) {}
            }
            loadConversations();
            return;
          }

          final action      = json['action'] as String? ?? (type == 'post_like' ? 'like' : 'comment');
          final postContent = json['postContent'] as String? ?? '';
          final commentText = json['commentText'] as String?
              ?? json['content'] as String?
              ?? '';

          // ── 生成展示文案 ──────────────────────────────────────
          // 帖子摘要引用（有内容则加引号展示）
          final postRef = postContent.isNotEmpty
              ? '"${postContent.length >= 20 ? '${postContent}…' : postContent}"'
              : '你的帖子';
          final String content;
          if (type == 'post_like') {
            content = action == 'unlike'
                ? '$fromName 取消了 $postRef 的点赞'
                : '$fromName 赞了你发布的 $postRef ❤️';
          } else {
            content = commentText.isNotEmpty
                ? '$fromName 评论了 $postRef：$commentText'
                : '$fromName 评论了 $postRef';
          }

          final notice = ImSystemNotice(
            type:        type,
            action:      action,
            fromName:    fromName,
            postContent: postContent,
            content:     content,
            time:        DateTime.now(),
          );

          // 最新通知插到最前，最多保留 50 条
          final updated = [notice, ...state.systemNotices].take(50).toList();
          state = state.copyWith(systemNotices: updated);
          debugPrint('[ImCtrl] 系统通知: $content');
        } catch (e) {
          debugPrint('[ImCtrl] 解析系统消息失败: $e');
        }
      },
    );
    _repo.addMessageListener(_systemMsgListener!);
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
    if (_systemMsgListener != null) {
      _repo.removeMessageListener(_systemMsgListener!);
      _systemMsgListener = null;
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
