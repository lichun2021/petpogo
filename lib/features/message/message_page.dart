import 'package:flutter/material.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../app.dart' show AppL10nX;

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final bool _isLoggedIn = true;

  final List<Map<String, dynamic>> _conversations = [
    {'name': '豆包的主人', 'petName': '豆包', 'avatar': '', 'lastMsg': '哈哈，我家猫也是这样的！', 'time': '刚刚',    'unread': 2, 'emoji': '🐱'},
    {'name': '汪汪的妈妈', 'petName': '汪汪', 'avatar': '', 'lastMsg': '你发的帖子好可爱！',       'time': '10分钟前', 'unread': 0, 'emoji': '🐶'},
    {'name': '小橘的铲屎官','petName': '小橘', 'avatar': '', 'lastMsg': '[图片]',              'time': '昨天',    'unread': 1, 'emoji': '🐱'},
    {'name': '布丁的爸爸', 'petName': '布丁', 'avatar': '', 'lastMsg': '明天一起去遛狗吗？',     'time': '昨天',    'unread': 0, 'emoji': '🐕'},
  ];

  final List<Map<String, dynamic>> _friendRequests = [
    {'name': '美美的主人', 'petName': '美美', 'emoji': '🐶'},
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!_isLoggedIn) return _buildGuestView(l10n);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── AppBar 固定 ─────────────────────────────
          SliverAppBar(
            pinned: true,          // 固定顶部
            floating: false,
            backgroundColor: AppColors.surface.withOpacity(0.95),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            title: Text(l10n.messageTitle,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 22,
                    fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.onSurface)),
            actions: [
              IconButton(
                icon: Icon(Icons.person_add_rounded, color: AppColors.onSurfaceVariant),
                onPressed: () {},
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_friendRequests.isNotEmpty) ...[
                  _FriendRequestBanner(requests: _friendRequests, l10n: l10n),
                  const SizedBox(height: 16),
                ],
                _NotificationSection(l10n: l10n),
                const SizedBox(height: 24),
                Text(l10n.messageDirectMessages,
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16,
                        fontWeight: FontWeight.w700, color: AppColors.onSurface, letterSpacing: -0.2)),
                const SizedBox(height: 12),
                ..._conversations.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ConversationCard(data: c),
                )),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestView(dynamic l10n) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 100, height: 100,
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
                child: const Center(child: Text('💬', style: TextStyle(fontSize: 44)))),
            const SizedBox(height: 20),
            Text(l10n.messageLoginPrompt,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18,
                    fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            const SizedBox(height: 8),
            Text(l10n.messageLoginSubtitle,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 28),
            ElevatedButton(onPressed: () {}, child: Text(l10n.messageBindPhone)),
          ],
        ),
      ),
    );
  }
}

class _FriendRequestBanner extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final dynamic l10n;
  const _FriendRequestBanner({required this.requests, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)],
      ),
      child: Row(
        children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.3), shape: BoxShape.circle),
              child: const Center(child: Text('🐾', style: TextStyle(fontSize: 22)))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.messageFriendRequests(requests.length),
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                        fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                Text(l10n.messageFriendRequestDesc(requests.first['petName'] as String),
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: Text(l10n.messageView,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _NotificationSection extends StatelessWidget {
  final dynamic l10n;
  const _NotificationSection({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _NotificationItem(
            icon: Icons.notifications_rounded,
            iconBg: AppColors.primaryContainer.withOpacity(0.3),
            iconColor: AppColors.primary,
            title: lateTitle(l10n, 'system'),
            subtitle: lateTitle(l10n, 'systemDesc'),
            time: '5分钟前',
            hasUnread: true,
          ),
          Divider(color: AppColors.outlineVariant.withOpacity(0.1), height: 0, indent: 72),
          _NotificationItem(
            icon: Icons.favorite_rounded,
            iconBg: AppColors.errorContainer.withOpacity(0.2),
            iconColor: AppColors.error,
            title: lateTitle(l10n, 'interaction'),
            subtitle: lateTitle(l10n, 'interactionDesc'),
            time: '1小时前',
            hasUnread: false,
          ),
        ],
      ),
    );
  }

  String lateTitle(dynamic l10n, String key) {
    if (key == 'system') return l10n.messageSystemNotif;
    if (key == 'systemDesc') return l10n.messageSystemNotifDesc;
    if (key == 'interaction') return l10n.messageInteraction;
    return l10n.messageInteractionDesc;
  }
}

class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle, time;
  final bool hasUnread;

  const _NotificationItem({required this.icon, required this.iconBg, required this.iconColor,
    required this.title, required this.subtitle, required this.time, required this.hasUnread});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                    fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                Text(subtitle, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, color: AppColors.onSurfaceVariant)),
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

class _ConversationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ConversationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final int unread = data['unread'] as int;
    final bool hasUnread = unread > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              PetAvatar(imageUrl: data['avatar'] as String?, size: 48, fallbackEmoji: data['emoji'] as String),
              if (hasUnread)
                Positioned(
                  right: -2, top: -2,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceContainerLowest, width: 2)),
                    child: Center(child: Text('$unread',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['name'] as String,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                        fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600, color: AppColors.onSurface)),
                const SizedBox(height: 3),
                Text(data['lastMsg'] as String, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                        color: hasUnread ? AppColors.onSurface : AppColors.onSurfaceVariant,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400)),
              ],
            ),
          ),
          Text(data['time'] as String,
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
