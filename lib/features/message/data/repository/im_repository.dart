/// ════════════════════════════════════════════════════════════
///  IM Repository — 腾讯云 IM SDK 封装层
///
///  职责：
///    ✅ 封装 TencentImSDKPlugin 所有 API 调用
///    ✅ 统一用 Result<T> 包装，上层不需要处理 SDK 异常
///    ✅ IM 登录 / 登出
///    ✅ 会话列表 / 历史消息 / 发送消息
///    ✅ 好友管理（添加/同意/删除/获取列表）
///    ❌ 不包含 UI 逻辑（由 Controller 负责）
///
///  用法示例：
///    final result = await ref.read(imRepositoryProvider).fetchConversations();
///    result.when(success: (list) => ..., failure: (err) => ...);
/// ════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimFriendshipListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_priority_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_response_type_enum.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/result.dart';

class ImRepository {
  // ── IM 登录 ──────────────────────────────────────────────
  /// 使用后端下发的 UserSig 登录腾讯 IM
  ///
  /// [userId]  - 与 PetPogo 账号绑定的 ID（使用 merchantId 字符串）
  /// [userSig] - 由后端使用 SecretKey 生成后下发，客户端直接传入
  ///
  /// ⚠️ userSig 绝对不能在客户端生成（SecretKey 有安全风险）
  Future<Result<void>> login({
    required String userId,
    required String userSig,
  }) => guardResult(() async {
    debugPrint('[IM] 登录 userId=$userId');
    final res = await TencentImSDKPlugin.v2TIMManager.login(
      userID: userId,
      userSig: userSig,
    );
    if (res.code != 0) {
      throw ApiException(message: res.desc ?? 'IM 登录失败', statusCode: res.code);
    }
    debugPrint('[IM] ✅ 登录成功 userId=$userId');
  });

  // ── IM 登出 ──────────────────────────────────────────────
  Future<Result<void>> logout() => guardResult(() async {
    await TencentImSDKPlugin.v2TIMManager.logout();
    debugPrint('[IM] 已登出');
  });

  // ── 会话列表 ─────────────────────────────────────────────
  /// 获取最近会话列表（用于消息页展示）
  Future<Result<List<V2TimConversation>>> fetchConversations() =>
      guardResult(() async {
        final res = await TencentImSDKPlugin.v2TIMManager
            .getConversationManager()
            .getConversationList(nextSeq: '0', count: 50);
        if (res.code != 0) {
          throw ApiException(message: res.desc ?? '获取会话失败');
        }
        final list = res.data?.conversationList ?? [];
        // 过滤掉空会话
        return list.where((c) => c != null).map((c) => c!).toList();
      });

  // ── 历史消息 ─────────────────────────────────────────────
  /// 获取单聊历史消息
  ///
  /// [userId] - 对方的 IM userID
  /// [count]  - 拉取数量，默认 30 条
  Future<Result<List<V2TimMessage>>> fetchMessages({
    required String userId,
    int count = 30,
  }) => guardResult(() async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .getHistoryMessageList(
          count: count,
          getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
          userID: userId,
          groupID: '',
        );
    if (res.code != 0) {
      throw ApiException(message: res.desc ?? '获取消息失败');
    }
    return res.data?.reversed.toList() ?? [];
  });

  // ── 发送消息 ─────────────────────────────────────────────
  /// 发送文本消息
  Future<Result<void>> sendText({
    required String toUserId,
    required String text,
  }) => guardResult(() async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .sendTextMessage(
          text: text,
          receiver: toUserId,   // v8.x: receiver (not userID)
          groupID: '',
          priority: MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
          onlineUserOnly: false,
          offlinePushInfo: null,
        );
    if (res.code != 0) {
      throw ApiException(message: res.desc ?? '发送失败');
    }
  });

  /// 发送图片消息
  Future<Result<void>> sendImage({
    required String toUserId,
    required String imagePath,
  }) => guardResult(() async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .sendImageMessage(
          imagePath: imagePath,
          receiver: toUserId,   // v8.x: receiver (not userID)
          groupID: '',
          priority: MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
          onlineUserOnly: false,
          offlinePushInfo: null,
        );
    if (res.code != 0) {
      throw ApiException(message: res.desc ?? '图片发送失败');
    }
  });

  // ── 好友管理 ─────────────────────────────────────────────
  /// 获取好友列表
  Future<Result<List<V2TimFriendInfo>>> fetchFriendList() =>
      guardResult(() async {
        final res = await TencentImSDKPlugin.v2TIMManager
            .getFriendshipManager()
            .getFriendList();
        if (res.code != 0) {
          throw ApiException(message: res.desc ?? '获取好友列表失败');
        }
        return res.data?.map((e) => e!).toList() ?? [];
      });

  /// 发送好友申请
  ///
  /// [toUserId] - 对方的 IM userID（merchantId 字符串）
  /// [addWording] - 申请附言（"我是 xx 的主人，想认识你~"）
  Future<Result<void>> addFriend({
    required String toUserId,
    String addWording = '',
  }) => guardResult(() async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .addFriend(
          userID: toUserId,
          addType: FriendTypeEnum.V2TIM_FRIEND_TYPE_BOTH,
          addWording: addWording,
          remark: '',
          friendGroup: '',
        );
    if (res.code != 0 && res.code != 30001) {
      throw ApiException(message: res.desc ?? '添加好友失败');
    }
  });

  /// 获取好友申请列表（别人申请加我）
  Future<Result<List<V2TimFriendApplication>>> fetchFriendApplications() =>
      guardResult(() async {
        final res = await TencentImSDKPlugin.v2TIMManager
            .getFriendshipManager()
            .getFriendApplicationList();
        if (res.code != 0) {
          throw ApiException(message: res.desc ?? '获取申请列表失败');
        }
        return res.data?.friendApplicationList?.map((e) => e!).toList() ?? [];
      });

  /// 同意好友申请
  Future<Result<void>> acceptFriend(String fromUserId) =>
      guardResult(() async {
        final res = await TencentImSDKPlugin.v2TIMManager
            .getFriendshipManager()
            .acceptFriendApplication(
              userID: fromUserId,
              responseType: FriendResponseTypeEnum.V2TIM_FRIEND_ACCEPT_AGREE_AND_ADD,
              type: FriendApplicationTypeEnum.V2TIM_FRIEND_APPLICATION_COME_IN,
            );
        if (res.code != 0) {
          throw ApiException(message: res.desc ?? '同意申请失败');
        }
      });

  /// 拒绝好友申请
  Future<Result<void>> refuseFriend(String fromUserId) =>
      guardResult(() async {
        final res = await TencentImSDKPlugin.v2TIMManager
            .getFriendshipManager()
            .refuseFriendApplication(
              userID: fromUserId,
              type: FriendApplicationTypeEnum.V2TIM_FRIEND_APPLICATION_COME_IN,
            );
        if (res.code != 0) {
          throw ApiException(message: res.desc ?? '拒绝申请失败');
        }
      });

  /// 删除好友
  Future<Result<void>> deleteFriend(String userId) =>
      guardResult(() async {
        final res = await TencentImSDKPlugin.v2TIMManager
            .getFriendshipManager()
            .deleteFromFriendList(
              userIDList: [userId],
              deleteType: FriendTypeEnum.V2TIM_FRIEND_TYPE_BOTH,
            );
        if (res.code != 0) {
          throw ApiException(message: res.desc ?? '删除好友失败');
        }
      });

  // ── 消息已读 ─────────────────────────────────────────────
  /// 标记会话消息全部已读
  Future<void> markConversationRead(String userId) async {
    await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .markC2CMessageAsRead(userID: userId);
  }

  // ── 注册监听器 ───────────────────────────────────────────
  /// 注册新消息监听（进入聊天页时调用）
  void addMessageListener(V2TimAdvancedMsgListener listener) {
    TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .addAdvancedMsgListener(listener: listener);
  }

  /// 移除消息监听（离开聊天页时调用）
  void removeMessageListener(V2TimAdvancedMsgListener listener) {
    TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .removeAdvancedMsgListener(listener: listener);
  }

  /// 注册会话列表变化监听（进入消息页时调用）
  void addConversationListener(V2TimConversationListener listener) {
    TencentImSDKPlugin.v2TIMManager
        .getConversationManager()
        .addConversationListener(listener: listener);
  }

  /// 移除会话列表变化监听
  void removeConversationListener(V2TimConversationListener listener) {
    TencentImSDKPlugin.v2TIMManager
        .getConversationManager()
        .removeConversationListener(listener: listener);
  }

  /// 注册好友申请变化监听
  void addFriendListener(V2TimFriendshipListener listener) {
    TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .addFriendListener(listener: listener);
  }

  void removeFriendListener(V2TimFriendshipListener listener) {
    TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .removeFriendListener(listener: listener);
  }
}

// ── Riverpod Provider ─────────────────────────────────────
final imRepositoryProvider = Provider<ImRepository>((ref) {
  return ImRepository();
});
