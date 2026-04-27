import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../app.dart' show AppL10nX;
import '../../core/router/app_routes.dart';
import 'controller/im_controller.dart';

class MessagePage extends ConsumerStatefulWidget {
  const MessagePage({super.key});

  @override
  ConsumerState<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends ConsumerState<MessagePage> {
  @override
  void initState() {
    super.initState();
    // 进入消息页时加载会话列表和好友申请
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(imControllerProvider.notifier);
      ctrl.loadConversations();
      ctrl.loadFriendApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = context.l10n;
    final state = ref.watch(imControllerProvider);

    // IM 未登录时显示引导页
    if (!state.isLoggedIn) return _buildNotLoggedIn(l10n);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: AppColors.surface.withOpacity(0.95),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            title: Text(
              l10n.messageTitle,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 22,
                fontWeight: FontWeight.w800, letterSpacing: -0.4,
                color: AppColors.onSurface,
              ),
            ),
            actions: [
              // 好友申请角标
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.person_add_rounded, color: AppColors.onSurfaceVariant),
                    onPressed: () {/* TODO: 跳转好友申请列表页 */},
                    tooltip: '好友申请',
                  ),
                  if (state.pendingFriendCount > 0)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${state.pendingFriendCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // 好友申请 Banner
                if (state.friendApplications.isNotEmpty) ...[
                  _FriendRequestBanner(
                    applications: state.friendApplications,
                    onAccept: (userId) =>
                        ref.read(imControllerProvider.notifier).acceptFriend(userId),
                    onRefuse: (userId) =>
                        ref.read(imControllerProvider.notifier).refuseFriend(userId),
                  ),
                  const SizedBox(height: 16),
                ],

                // 系统通知区（暂用静态，后续接 IM 系统通知）
                _NotificationSection(l10n: l10n),
                const SizedBox(height: 24),

                // 私信列表标题
                Text(
                  l10n.messageDirectMessages,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 16,
                    fontWeight: FontWeight.w700, color: AppColors.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),

                // 加载中
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                    ),
                  )

                // 错误提示
                else if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                        const SizedBox(height: 8),
                        Text(state.errorMessage!,
                            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.error)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => ref.read(imControllerProvider.notifier).loadConversations(),
                          child: const Text('重试'),
                        ),
                      ]),
                    ),
                  )

                // 空状态
                else if (state.conversations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('💬', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text('暂无私信', style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans', fontSize: 16,
                          fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant,
                        )),
                        SizedBox(height: 4),
                        Text('在社区认识新朋友后，可以发起私信聊天',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            )),
                      ]),
                    ),
                  )

                // 会话列表
                else
                  ...state.conversations.map((conv) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ConversationCard(
                      conversation: conv,
                      onTap: () {
                        // 标记已读
                        ref.read(imControllerProvider.notifier).markRead(conv.userID ?? '');
                        // 跳转聊天页
                        context.push(AppRoutes.chat(conv.userID ?? ''));
                      },
                    ),
                  )),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // IM 未登录提示（后端 UserSig 还没接入时显示）
  Widget _buildNotLoggedIn(dynamic l10n) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('💬', style: TextStyle(fontSize: 44))),
            ),
            const SizedBox(height: 20),
            const Text('请先登录账号',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18,
                    fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          ],
        ),
      ),
    );
  }
}

// ── 好友申请 Banner ─────────────────────────────────────────
class _FriendRequestBanner extends StatelessWidget {
  final List<V2TimFriendApplication> applications;
  final void Function(String userId) onAccept;
  final void Function(String userId) onRefuse;

  const _FriendRequestBanner({
    required this.applications,
    required this.onAccept,
    required this.onRefuse,
  });

  @override
  Widget build(BuildContext context) {
    final first = applications.first;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🐾', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${applications.length} 条好友申请',
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                      fontWeight: FontWeight.w700, color: AppColors.onSurface),
                ),
                Text(
                  '${first.nickname ?? first.userID} 想和你成为好友',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                      color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => onRefuse(first.userID ?? ''),
                child: const Text('拒绝', style: TextStyle(color: AppColors.onSurfaceVariant)),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: () => onAccept(first.userID ?? ''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('同意', style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                  fontWeight: FontWeight.w700, color: Colors.white,
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 系统通知区（静态，后续接 IM 系统通知频道）──────────────
class _NotificationSection extends StatelessWidget {
  final dynamic l10n;
  const _NotificationSection({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _NotificationItem(
            icon: Icons.notifications_rounded,
            iconBg: AppColors.primaryContainer.withOpacity(0.3),
            iconColor: AppColors.primary,
            title: l10n.messageSystemNotif,
            subtitle: l10n.messageSystemNotifDesc,
            time: '5分钟前',
            hasUnread: true,
          ),
          Divider(color: AppColors.outlineVariant.withOpacity(0.1), height: 0, indent: 72),
          _NotificationItem(
            icon: Icons.favorite_rounded,
            iconBg: AppColors.errorContainer.withOpacity(0.2),
            iconColor: AppColors.error,
            title: l10n.messageInteraction,
            subtitle: l10n.messageInteractionDesc,
            time: '1小时前',
            hasUnread: false,
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle, time;
  final bool hasUnread;

  const _NotificationItem({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.title, required this.subtitle, required this.time,
    required this.hasUnread,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                    fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                Text(subtitle, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                    color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                  color: AppColors.onSurfaceVariant)),
              if (hasUnread) ...[
                const SizedBox(height: 4),
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── 会话卡片（对接 V2TimConversation）──────────────────────
class _ConversationCard extends StatelessWidget {
  final V2TimConversation conversation;
  final VoidCallback onTap;

  const _ConversationCard({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread    = conversation.unreadCount ?? 0;
    final hasUnread = unread > 0;
    final name      = conversation.showName ?? conversation.userID ?? '用户';
    final lastMsg   = conversation.lastMessage?.textElem?.text
        ?? (conversation.lastMessage?.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE ? '[图片]' : '[消息]');
    final time      = _formatTime(conversation.lastMessage?.timestamp);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                PetAvatar(
                  imageUrl: conversation.faceUrl,
                  size: 48,
                  fallbackEmoji: '🐾',
                ),
                if (hasUnread)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceContainerLowest, width: 2),
                      ),
                      child: Center(child: Text(
                        '$unread',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      )),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                        fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.onSurface,
                      )),
                  const SizedBox(height: 3),
                  Text(lastMsg,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                        color: hasUnread ? AppColors.onSurface : AppColors.onSurfaceVariant,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                      )),
                ],
              ),
            ),
            Text(time, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return '';
    final dt  = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return '刚刚';
    if (diff.inHours   < 1)  return '${diff.inMinutes}分钟前';
    if (diff.inDays    < 1)  return '${diff.inHours}小时前';
    if (diff.inDays    < 7)  return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}
