import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/pet_toast.dart';
import '../../app.dart' show AppL10nX;
import '../../core/router/app_routes.dart';
import 'controller/im_controller.dart';
import 'data/repository/im_repository.dart';
import 'contacts_page.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

class MessagePage extends ConsumerStatefulWidget {
  const MessagePage({super.key});

  @override
  ConsumerState<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends ConsumerState<MessagePage> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(imControllerProvider.notifier);
      // IM 已登录才主动拉取（新设备登录时 loginIm 回调会处理）
      if (ref.read(imControllerProvider).isLoggedIn) {
        ctrl.loadConversations();
        ctrl.loadFriendApplications();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── 右上角 "..." → 跳转联系人全屏页 ──────────────────────────
  void _openContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContactsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = context.l10n;
    final state = ref.watch(imControllerProvider);

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
              style: TextStyle(
                fontFamily: AppFonts.primary, fontSize: 22,
                fontWeight: FontWeight.w800, letterSpacing: -0.4,
                color: AppColors.onSurface,
              ),
            ),
            actions: [
              IconButton(
                    icon: Icon(Icons.people_outline_rounded, color: AppColors.onSurface, size: 26),
                    onPressed: _openContacts,
                    tooltip: '联系人',
                  ),
              SizedBox(width: 4),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([



                // 系统通知区（真实通知）
                _NotificationSection(
                  friendApplications: state.friendApplications,
                ),
                SizedBox(height: 24),

                SizedBox(height: 16),

                // 搜索栏
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(fontFamily: AppFonts.primary, fontSize: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none, isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      hintText: '搜索私信…',
                      hintStyle: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant.withOpacity(0.6)),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () { _searchCtrl.clear(); FocusScope.of(context).unfocus(); },
                              child: Icon(Icons.clear_rounded, size: 16, color: AppColors.onSurfaceVariant),
                            )
                          : null,
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // 私信列表标题
                Text(
                  l10n.messageDirectMessages,
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontSize: 16,
                    fontWeight: FontWeight.w700, color: AppColors.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 12),

                // 加载中
                if (state.isLoading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                    ),
                  )

                else if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                        SizedBox(height: 8),
                        Text(state.errorMessage!,
                            style: TextStyle(fontFamily: AppFonts.primary, fontSize: 13, color: AppColors.error)),
                        SizedBox(height: 12),
                        TextButton(
                          onPressed: () => ref.read(imControllerProvider.notifier).loadConversations(),
                          child: Text('重试'),
                        ),
                      ]),
                    ),
                  )

                else ...[
                  // 过滤规则：
                  // 1. administrator 系统账号
                  // 2. 会话最新消息是自定义消息且内容为点赞/评论通知
                  Builder(builder: (context) {
                    final chats = state.conversations.where((c) {
                      if (c.userID == 'administrator') return false;
                      final lastMsg = c.lastMessage;
                      if (lastMsg != null &&
                          lastMsg.elemType == MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
                        final data = lastMsg.customElem?.data ?? '';
                        if (data.contains('"post_like"') || data.contains('"post_comment"')) return false;
                      }
                      // 搜索过滤
                      if (_searchQuery.isNotEmpty) {
                        final name = (c.showName ?? c.userID ?? '').toLowerCase();
                        final last = _parseLastMsgText(c).toLowerCase();
                        if (!name.contains(_searchQuery) && !last.contains(_searchQuery)) return false;
                      }
                      return true;
                    }).toList();
                    // 置顶会话排在前面
                    chats.sort((a, b) {
                      final aPin = a.isPinned == true ? 1 : 0;
                      final bPin = b.isPinned == true ? 1 : 0;
                      if (aPin != bPin) return bPin.compareTo(aPin);
                      return (b.orderkey ?? 0).compareTo(a.orderkey ?? 0);
                    });
                    if (chats.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('💬', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text('暂无私信', style: TextStyle(
                              fontFamily: AppFonts.primary, fontSize: 16,
                              fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant,
                            )),
                            SizedBox(height: 4),
                            Text('在社区认识新朋友后，可以发起私信聊天',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppFonts.primary, fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                )),
                          ]),
                        ),
                      );
                    }
                    return Column(
                      children: chats.map((conv) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ConversationCard(
                          conversation: conv,
                          onTap: () {
                            ref.read(imControllerProvider.notifier).markRead(conv.userID ?? '');
                            context.push(AppRoutes.chat(conv.userID ?? ''));
                          },
                          onPin: () async {
                            await ref.read(imRepositoryProvider)
                                .pinConversation(conv.userID ?? '', pin: !(conv.isPinned == true));
                            ref.read(imControllerProvider.notifier).loadConversations();
                          },
                          onClear: () async {
                            await ref.read(imRepositoryProvider).clearC2CHistory(conv.userID ?? '');
                            if (context.mounted) {
                              PetToast.success(context, '聊天记录已清空 ✨');
                            }
                          },
                          onDelete: () async {
                            await ref.read(imRepositoryProvider).deleteConversation(conv.userID ?? '');
                            ref.read(imControllerProvider.notifier).loadConversations();
                          },
                        ),
                      )).toList(),
                    );
                  }),
                ]
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // 业务使用的最后一条消息文字（搜索过滤用）
  String _parseLastMsgText(V2TimConversation c) {
    final last = c.lastMessage;
    if (last == null) return '';
    return last.textElem?.text ?? (last.soundElem != null ? '[语音]' : '[消息]');
  }


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
              child: Center(child: Text('💬', style: TextStyle(fontSize: 44))),
            ),
            SizedBox(height: 20),
            Text('请先登录账号',
                style: TextStyle(fontFamily: AppFonts.primary, fontSize: 18,
                    fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          ],
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════
//  系统通知区（真实好友申请 + 点赞 / 评论通知）
// ══════════════════════════════════════════════════════════════
class _NotificationSection extends ConsumerWidget {
  final List<V2TimFriendApplication> friendApplications;
  const _NotificationSection({required this.friendApplications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(imControllerProvider);
    final hasFriendReq  = friendApplications.isNotEmpty;
    final firstName     = hasFriendReq
        ? (friendApplications.first.nickname ?? friendApplications.first.userID ?? '有人')
        : '';
    final latestLike    = state.latestLike;
    final latestComment = state.latestComment;
    final hasInteract   = latestLike != null || latestComment != null;

    // 互动通知文案（点赞优先显示，然后评论）
    final interactSubtitle = latestLike != null
        ? latestLike.content
        : latestComment != null
            ? latestComment.content
            : '暂无互动通知';
    final interactTime = hasInteract
        ? _relTime(latestLike?.time ?? latestComment?.time)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // 好友申请（可点击弹出申请面板）
          _NotificationItem(
            icon: Icons.person_add_rounded,
            iconBg: AppColors.primaryContainer.withOpacity(0.3),
            iconColor: AppColors.primary,
            title: '好友申请',
            subtitle: () {
              final results = state.systemNotices
                  .where((n) => n.type == 'friend_result').toList();
              if (results.isNotEmpty) return results.first.content;
              if (hasFriendReq) return '$firstName 想和你成为好友${friendApplications.length > 1 ? '，共 ${friendApplications.length} 条待处理' : ''}';
              return '暂无新好友申请';
            }(),
            time: () {
              final results = state.systemNotices
                  .where((n) => n.type == 'friend_result').toList();
              if (results.isNotEmpty) return _relTime(results.first.time);
              return hasFriendReq ? '刚刚' : '';
            }(),
            hasUnread: hasFriendReq ||
                state.systemNotices.any((n) => n.type == 'friend_result'),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => FriendRequestsPage(applications: friendApplications))),
          ),
          Divider(color: AppColors.outlineVariant.withOpacity(0.1), height: 0, indent: 72),
          // 点赞 / 评论（点击弹出通知历史列表）
          _NotificationItem(
            icon: Icons.favorite_rounded,
            iconBg: AppColors.errorContainer.withOpacity(0.2),
            iconColor: AppColors.error,
            title: '互动通知',
            subtitle: interactSubtitle,
            time: interactTime,
            hasUnread: hasInteract,
            onTap: () => _showInteractSheet(context, ref),
          ),
        ],
      ),
    );
  }

  String _relTime(DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return '刚刚';
    if (diff.inHours   < 1)  return '${diff.inMinutes}分钟前';
    if (diff.inDays    < 1)  return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  void _showInteractSheet(BuildContext context, WidgetRef ref) {
    final notices = ref.read(imControllerProvider).systemNotices;
    // 标记已读
    ref.read(imControllerProvider.notifier).clearInteractNotices();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InteractSheet(notices: notices),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  互动通知历史面板
// ══════════════════════════════════════════════════════════════
class _InteractSheet extends StatelessWidget {
  final List<ImSystemNotice> notices;
  const _InteractSheet({required this.notices});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动条
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 16, 8),
            child: Row(children: [
              Text('互动通知', style: TextStyle(
                fontFamily: AppFonts.primary, fontSize: 20,
                fontWeight: FontWeight.w800, color: AppColors.onSurface,
              )),
              Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded),
                color: AppColors.onSurfaceVariant,
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Divider(height: 1, thickness: 0.5, color: Color(0x18000000)),

          // 通知列表
          if (notices.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('❤️', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Text('暂无互动通知', style: TextStyle(
                    fontFamily: AppFonts.primary, fontSize: 15,
                    fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant,
                  )),
                  SizedBox(height: 4),
                  Text('当有人点赞或评论你的帖子时，通知会在这里显示', style: TextStyle(
                    fontFamily: AppFonts.primary, fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  )),
                ]),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: notices.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1, thickness: 0.5, indent: 60,
                  color: Color(0x10000000),
                ),
                itemBuilder: (ctx, i) => _InteractNoticeItem(notice: notices[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _InteractNoticeItem extends StatelessWidget {
  final ImSystemNotice notice;
  const _InteractNoticeItem({required this.notice});

  @override
  Widget build(BuildContext context) {
    final isFriendResult = notice.type == 'friend_result';
    final isLike    = notice.isLike && !notice.isUnlike;
    final isUnlike  = notice.isUnlike;

    final IconData icon;
    final Color iconColor, iconBg;
    if (isFriendResult) {
      final accepted = notice.action == 'accepted';
      icon      = accepted ? Icons.handshake_rounded : Icons.person_off_rounded;
      iconColor = accepted ? AppColors.primary : AppColors.onSurfaceVariant;
      iconBg    = accepted
          ? AppColors.primaryContainer.withOpacity(0.3)
          : AppColors.surfaceContainerHigh;
    } else if (isUnlike) {
      icon = Icons.heart_broken_rounded;
      iconColor = AppColors.onSurfaceVariant;
      iconBg    = AppColors.surfaceContainerHigh;
    } else if (isLike) {
      icon = Icons.favorite_rounded;
      iconColor = AppColors.error;
      iconBg    = AppColors.errorContainer.withOpacity(0.25);
    } else {
      icon = Icons.chat_bubble_rounded;
      iconColor = AppColors.primary;
      iconBg    = AppColors.primaryContainer.withOpacity(0.3);
    }

    // 相对时间
    final diff = DateTime.now().difference(notice.time);
    final timeStr = diff.inMinutes < 1  ? '刚刚'
        : diff.inHours   < 1  ? '${diff.inMinutes}分钟前'
        : diff.inDays    < 1  ? '${diff.inHours}小时前'
        : '${diff.inDays}天前';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 图标
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        SizedBox(width: 12),
        // 文案
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              notice.content,
              style: TextStyle(
                fontFamily: AppFonts.primary, fontSize: 13,
                fontWeight: FontWeight.w600, color: AppColors.onSurface,
                height: 1.45,
              ),
            ),
            SizedBox(height: 3),
            Text(timeStr, style: TextStyle(
              fontFamily: AppFonts.primary, fontSize: 11,
              color: AppColors.onSurfaceVariant,
            )),
          ]),
        ),
      ]),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle, time;
  final bool hasUnread;
  final VoidCallback? onTap;  // ← 新增：点击回调（null = 不可点击）

  const _NotificationItem({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.title, required this.subtitle, required this.time,
    required this.hasUnread,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontFamily: AppFonts.primary, fontSize: 14,
                      fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  Text(subtitle, style: TextStyle(fontFamily: AppFonts.primary, fontSize: 12,
                      color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            if (time.isNotEmpty || hasUnread)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (time.isNotEmpty)
                    Text(time, style: TextStyle(fontFamily: AppFonts.primary, fontSize: 10,
                        color: AppColors.onSurfaceVariant)),
                  if (hasUnread) ...[
                    SizedBox(height: 4),
                    Container(width: 8, height: 8,
                        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                  ],
                ],
              ),
            if (onTap != null) ...[
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 好友申请全屏列表页 ─────────────────────────────────────
class FriendRequestsPage extends ConsumerStatefulWidget {
  final List<V2TimFriendApplication> applications;
  const FriendRequestsPage({super.key, required this.applications});
  @override
  ConsumerState<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends ConsumerState<FriendRequestsPage> {
  final Set<String> _removedIds = {};
  List<V2TimFriendApplication> _sent = [];
  bool _loadingSent = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(imControllerProvider.notifier).loadFriendApplications();
      _loadSent();
      // 定时轮询，小调修写开题时即时显示
      _refreshTimer = Timer.periodic(Duration(seconds: 3), (_) {
        if (mounted) {
          ref.read(imControllerProvider.notifier).loadFriendApplications();
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSent() async {
    final res = await ref.read(imRepositoryProvider).fetchSentApplications();
    if (!mounted) return;
    setState(() {
      _sent = res.when(success: (l) => l, failure: (_) => []);
      _loadingSent = false;
    });
  }

  Future<void> _accept(V2TimFriendApplication app) async {
    await ref.read(imControllerProvider.notifier).acceptFriend(app.userID ?? '');
    if (!mounted) return;
    setState(() => _removedIds.add(app.userID ?? ''));
  }

  Future<void> _refuse(V2TimFriendApplication app) async {
    await ref.read(imControllerProvider.notifier).refuseFriend(app.userID ?? '');
    if (!mounted) return;
    setState(() => _removedIds.add(app.userID ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    // 当 friendApplications 变化时强制 setState 触发重建
    ref.listen(
      imControllerProvider.select((s) => s.friendApplications),
      (_, __) { if (mounted) setState(() {}); },
    );
    final received = ref.watch(imControllerProvider)
        .friendApplications
        .where((a) => a.type == 1 && !_removedIds.contains(a.userID))
        .toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, size: 20),
            color: AppColors.onSurface,
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('好友申请',
              style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 17, fontWeight: FontWeight.w700)),
          centerTitle: true,
          bottom: TabBar(
            labelStyle: TextStyle(
                fontFamily: AppFonts.primary, fontWeight: FontWeight.w700,
                fontSize: 13),
            unselectedLabelStyle: TextStyle(
                fontFamily: AppFonts.primary, fontSize: 13),
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: '收到的${received.isNotEmpty ? "  (${received.length})" : ""}'),
              Tab(text: '发出的'),
            ],
          ),
        ),
        body: TabBarView(children: [
          // ─────── 收到的申请 ──────────────────────────────────────
          received.isEmpty
              ? _buildEmpty('暂无待处理的好友申请')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: received.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final app     = received[i];
                    final uid     = app.userID ?? '';
                    final name    = app.nickname ?? uid;
                    final wording = (app.addWording?.isNotEmpty == true)
                        ? app.addWording! : '想和你成为好友';
                    return _RequestCard(
                      name: name,
                      wording: wording,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        TextButton(
                          onPressed: () => _refuse(app),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6)),
                          child: Text('拒绝', style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontWeight: FontWeight.w600)),
                        ),
                        ElevatedButton(
                          onPressed: () => _accept(app),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text('同意', style: TextStyle(
                              fontFamily: AppFonts.primary, fontSize: 13,
                              fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ]),
                    );
                  },
                ),
          // ─────── 发出的申请 ───────────────────────────────
          Consumer(builder: (context, ref, _) {
            final resultNotices = ref.watch(imControllerProvider)
                .systemNotices
                .where((n) => n.type == 'friend_result')
                .toList();
            final isLoading = _loadingSent && resultNotices.isEmpty;
            if (isLoading) {
              return Center(child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5));
            }
            final items = <Widget>[];
            // 先显示结果通知（已同意 / 已拒绝）——支持右滑删除
            for (int idx = 0; idx < resultNotices.length; idx++) {
              final n = resultNotices[idx];
              final isRejected = n.action == 'rejected';
              items.add(Dismissible(
                key: ObjectKey(n),   // 对象引用键，唯一且不随删除后下标漂移
                direction: DismissDirection.startToEnd,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.delete_sweep_rounded,
                      color: AppColors.onSurfaceVariant, size: 28),
                ),
                onDismissed: (_) {
                  // 动态查找当前索引，避免删除后 idx 过时
                  final currentIdx = ref.read(imControllerProvider)
                      .systemNotices.indexOf(n);
                  if (currentIdx >= 0) {
                    ref.read(imControllerProvider.notifier)
                        .removeSystemNotice(currentIdx);
                  }
                },
                child: _RequestCard(
                  name: n.fromName,
                  wording: isRejected ? '拒绝了你的好友申请' : '已同意你的好友申请',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isRejected
                          ? AppColors.errorContainer.withOpacity(0.25)
                          : AppColors.primaryContainer.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isRejected ? '已拒绝 ❌' : '已同意 ✅',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: isRejected ? AppColors.error : AppColors.primary,
                      )),
                  ),
                ),
              ));
            }
            // 再显示待处理的发出申请
            for (final app in _sent) {
              final name = app.nickname ?? app.userID ?? '未知用户';
              final wording = (app.addWording?.isNotEmpty == true)
                  ? app.addWording!
                  : '我发送了好友申请';
              items.add(_RequestCard(
                name: name,
                wording: wording,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('待确认 ⏳',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant)),
                ),
              ));
            }
            if (items.isEmpty) return _buildEmpty('暂无发出的好友申请');
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: 10),
              itemBuilder: (_, i) => items[i],
            );
          }),
        ]),
      ),
    );
  }

  Widget _buildEmpty(String msg) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('🐾', style: TextStyle(fontSize: 52)),
      SizedBox(height: 12),
      Text(msg, style: TextStyle(fontFamily: AppFonts.primary,
          fontSize: 14, color: AppColors.onSurfaceVariant)),
    ]),
  );
}

class _RequestCard extends StatelessWidget {
  final String name, wording;
  final Widget trailing;
  const _RequestCard({required this.name, required this.wording,
      required this.trailing});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
          color: AppColors.cardShadow, blurRadius: 12, spreadRadius: -2)],
    ),
    child: Row(children: [
      CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primaryContainer,
        child: Text(name.isNotEmpty ? name[0] : '?',
            style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w800, color: AppColors.primary)),
      ),
      SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: TextStyle(fontFamily: AppFonts.primary,
            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        SizedBox(height: 2),
        Text(wording, style: TextStyle(fontFamily: AppFonts.primary,
            fontSize: 12, color: AppColors.onSurfaceVariant,
            fontStyle: FontStyle.italic)),
      ])),
      SizedBox(width: 8),
      trailing,
    ]),
  );
}


// ── 会话卡片（左滑露出操作按鈕）─────────────────────
class _ConversationCard extends StatefulWidget {
  final V2TimConversation conversation;
  final VoidCallback onTap;
  final Future<void> Function() onPin;
  final Future<void> Function() onClear;
  final Future<void> Function() onDelete;

  const _ConversationCard({
    required this.conversation,
    required this.onTap,
    required this.onPin,
    required this.onClear,
    required this.onDelete,
  });

  @override
  State<_ConversationCard> createState() => _ConversationCardState();
}

class _ConversationCardState extends State<_ConversationCard>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;   // 左滑面板 (0−1)
  late final AnimationController _rCtrl; // 右滑位移，unbounded，单位像素
  static const double _kPanelW         = 180.0;
  static const double _kSnapThreshold  = 0.35;
  static const double _kDeleteThreshold = 80.0;
  bool _busy            = false;
  bool _allowRightSwipe = false;
  bool _deleting        = false;
  double _screenWidth    = 400.0; // 在 build 里更新

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: Duration(milliseconds: 280));
    _rCtrl = AnimationController.unbounded(vsync: this); // value = px offset
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _rCtrl.dispose();
    super.dispose();
  }

  void _open()  => _ctrl.animateTo(1.0,
      duration: Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  void _close() => _ctrl.animateTo(0.0,
      duration: Duration(milliseconds: 260), curve: Curves.easeOutCubic);

  void _onDragStart(DragStartDetails _) {
    _allowRightSwipe = _ctrl.value < 0.02 && !_deleting;
    _rCtrl.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final dx = d.delta.dx;
    if (dx < 0 || _ctrl.value > 0) {
      final v = _ctrl.value + (-dx / _kPanelW);
      _ctrl.value = v.clamp(0.0, 1.0);
      if (_rCtrl.value != 0) _rCtrl.value = 0;
    } else if (dx > 0 && _allowRightSwipe) {
      // 全程跟手，稍微阅力感
      _rCtrl.value = (_rCtrl.value + dx * 0.92).clamp(0, _kDeleteThreshold * 1.8);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    final vel = d.velocity.pixelsPerSecond.dx;
    if (_rCtrl.value > 0) {
      if (_rCtrl.value >= _kDeleteThreshold || vel > 400) {
        _flyOut(vel);
      } else {
        _springBack(vel);
      }
      return;
    }
    if (_ctrl.value > _kSnapThreshold || vel < -500) {
      _open();
    } else {
      _close();
    }
  }

  // 弹回——easeOutCubic
  void _springBack(double velocity) {
    _rCtrl.animateTo(
      0,
      duration: Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  // 飞出屏幕——easeIn，.then() 必定触发
  void _flyOut(double velocity) {
    if (_deleting) return;
    _deleting = true;
    final target = _screenWidth > 0 ? _screenWidth + 50 : 500.0;
    _rCtrl.animateTo(
      target,
      duration: Duration(milliseconds: 260),
      curve: Curves.easeIn,
    ).then((_) {
      if (mounted) _runAction(widget.onDelete);
    });
  }

  /// 执行操作：先关闭面板，等动画完成再执行业务，完成后确保 busy 重置
  Future<void> _runAction(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    // 先关闭面板动画，等动画完成
    await _ctrl.animateTo(0.0,
        duration: Duration(milliseconds: 220), curve: Curves.easeOutCubic);
    await fn();
    // 业务完成后重置（setState 驱动 rebuild，确保按钮区消失）
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final unread    = widget.conversation.unreadCount ?? 0;
    final hasUnread = unread > 0;
    final isPinned  = widget.conversation.isPinned == true;
    final name      = widget.conversation.showName ??
        widget.conversation.userID ?? '用户';
    final lastMsg   = _parseLastMsg(widget.conversation);
    final time      = _formatTime(widget.conversation.lastMessage?.timestamp);

    // 卡片圆角：左滑时左侧变直角；右滑时右侧变直角
    return AnimatedBuilder(
      animation: Listenable.merge([_ctrl, _rCtrl]),
      builder: (context, child) {
        _screenWidth = MediaQuery.of(context).size.width;
        final rPx         = _rCtrl.value.clamp(0.0, double.infinity);
        final leftRadius  = Radius.circular(18 * (1.0 - _ctrl.value));
        final rightRadius = Radius.circular(rPx > 0 ? 0.0 : 18.0);
        final delProgress = (rPx / _kDeleteThreshold).clamp(0.0, 1.0);

        final card = Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isPinned
                ? AppColors.primaryContainer.withOpacity(0.08)
                : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.only(
              topLeft:     leftRadius,
              bottomLeft:  leftRadius,
              topRight:    rightRadius,
              bottomRight: rightRadius,
            ),
            boxShadow: [BoxShadow(
                color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)],
            border: isPinned
                ? Border.all(color: AppColors.primary.withOpacity(0.12))
                : null,
          ),
          child: Row(children: [
            Stack(children: [
              PetAvatar(imageUrl: widget.conversation.faceUrl,
                  size: 48, fallbackEmoji: '🐾'),
              if (hasUnread)
                Positioned(
                  right: -2, top: -2,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.surfaceContainerLowest, width: 2),
                    ),
                    child: Center(child: Text('$unread',
                        style: TextStyle(color: Colors.white,
                            fontSize: 9, fontWeight: FontWeight.w800))),
                  ),
                ),
            ]),
            SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(name, style: TextStyle(
                    fontFamily: AppFonts.primary, fontSize: 14,
                    fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                    color: AppColors.onSurface))),
                  if (isPinned)
                    Icon(Icons.push_pin_rounded, size: 12,
                        color: AppColors.primary.withOpacity(0.6)),
                ]),
                SizedBox(height: 3),
                Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontSize: 12,
                    color: hasUnread
                        ? AppColors.onSurface : AppColors.onSurfaceVariant,
                    fontWeight:
                        hasUnread ? FontWeight.w600 : FontWeight.w400)),
              ],
            )),
            Text(time, style: TextStyle(
                fontFamily: AppFonts.primary, fontSize: 10,
                color: AppColors.onSurfaceVariant)),
          ]),
        );

        return GestureDetector(
          onHorizontalDragStart:  _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd:    _onDragEnd,
          onTap: () {
            if (_ctrl.value > 0.02) { _close(); return; }
            if (rPx > 0) { _springBack(0); return; }
            widget.onTap();
          },
          child: Stack(children: [
            // ── 右滑删除背景（左对齐）─────────────────────────────
            if (rPx > 0)
              Positioned.fill(child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 22),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                        AppColors.errorContainer.withOpacity(0.6),
                        AppColors.error,
                        delProgress),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.delete_rounded, color: Colors.white,
                        size: 20 + 6 * delProgress),
                    SizedBox(width: 6),
                    if (delProgress > 0.6)
                      Text('删除', style: TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppFonts.primary)),
                  ]),
                ),
              )),
            // ── 操作按钮区（右对齐，仅在左滑展开时可见）─────────────
            if (_ctrl.value > 0)
              Positioned.fill(child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: _kPanelW, child: Row(children: [
                  _SwipeActionBtn(
                    icon: isPinned
                        ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                    label: isPinned ? '取消置顶' : '置顶',
                    color: AppColors.primary,
                    isFirst: true,
                    onTap: () => _runAction(widget.onPin),
                  ),
                  _SwipeActionBtn(
                    icon: Icons.delete_sweep_outlined,
                    label: '清空',
                    color: Color(0xFFFF9500),
                    onTap: () => _runAction(widget.onClear),
                  ),
                  _SwipeActionBtn(
                    icon: Icons.delete_outline_rounded,
                    label: '删除',
                    color: AppColors.error,
                    onTap: () => _runAction(widget.onDelete),
                  ),
                ])),
              )),
            // 卡片：左滑向左，右滑向右
            Transform.translate(
              offset: Offset(
                rPx > 0 ? rPx : -_kPanelW * _ctrl.value,
                0,
              ),
              child: card,
            ),
          ]),
        );
      },
    );
  }

  String _parseLastMsg(V2TimConversation conv) {
    final msg = conv.lastMessage;
    if (msg == null) return '';
    final text = msg.textElem?.text;
    if (text != null && text.isNotEmpty) return text;
    if (msg.soundElem != null) return '[语音]';
    if (msg.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE) return '[图片]';
    if (msg.elemType == MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
      final raw = msg.customElem?.data;
      if (raw != null && raw.isNotEmpty) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final type = json['type'] as String? ?? '';
          final from = json['fromName'] as String? ?? '有人';
          if (type == 'post_like')    return '$from 赞了你的帖子 ❤️';
          if (type == 'post_comment') {
            final t = json['content'] as String? ?? '';
            return '$from 评论了你：$t';
          }
          if (type == 'friend_accepted') return '✅ $from 已同意你的好友申请';
          if (type == 'friend_rejected') return '❌ $from 暂时拒绝了你的好友申请';
          if (type == 'fence_alert') return '⚠️ 宠物越界提醒';
        } catch (_) {}
      }
      return '[互动消息]';
    }
    return '[消息]';
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

// ── 滑动操作按钮（最左侧无圆角，与卡片无缝衔接）────────────────
class _SwipeActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  /// 是否为最左侧按钮（置顶），紧邻卡片右边缘，不加左圆角
  final bool isFirst;
  const _SwipeActionBtn({
    required this.icon, required this.label,
    required this.color, required this.onTap,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        // 最左侧按钮左边直角（与卡片无缝衔接），其余保持矩形
        decoration: BoxDecoration(color: color),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 22),
          SizedBox(height: 5),
          Text(label, style: TextStyle(
            color: Colors.white, fontSize: 11,
            fontFamily: AppFonts.primary, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

