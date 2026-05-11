import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/pet_toast.dart';
import '../../app.dart' show AppL10nX;
import '../../core/router/app_routes.dart';
import 'controller/im_controller.dart';
import 'data/repository/im_repository.dart';
import 'qr/my_qr_page.dart';
import 'qr/scan_add_friend_page.dart';

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
      ctrl.loadConversations();
      ctrl.loadFriendApplications();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── 右上角 "..." 底部菜单 ─────────────────────────────────
  void _showMorePanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MorePanel(
        onChatTap: () => Navigator.pop(context),
        onMyQrTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyQrCodePage()));
        },
        onScanQrTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanAddFriendPage()));
        },
      ),
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
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 22,
                fontWeight: FontWeight.w800, letterSpacing: -0.4,
                color: AppColors.onSurface,
              ),
            ),
            actions: [
              // "..." 按钮（带好友申请角标）
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.more_horiz_rounded, color: AppColors.onSurface, size: 26),
                    onPressed: _showMorePanel,
                    tooltip: '更多',
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
              const SizedBox(width: 4),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // 好友申请 Banner（实时数据）
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

                // 系统通知区（真实通知）
                _NotificationSection(
                  friendApplications: state.friendApplications,
                ),
                const SizedBox(height: 24),

                const SizedBox(height: 16),

                // 搜索栏
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14),
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
                      return const Padding(
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

// ══════════════════════════════════════════════════════════════
//  "..." 底部面板 — 好友列表 + 族群
// ══════════════════════════════════════════════════════════════
class _MorePanel extends ConsumerStatefulWidget {
  final VoidCallback onChatTap;
  final VoidCallback? onMyQrTap;    // 我的二维码
  final VoidCallback? onScanQrTap;  // 扫码加好友
  const _MorePanel({
    required this.onChatTap,
    this.onMyQrTap,
    this.onScanQrTap,
  });

  @override
  ConsumerState<_MorePanel> createState() => _MorePanelState();
}

class _MorePanelState extends ConsumerState<_MorePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<V2TimFriendInfo> _friends = [];
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // 好友列表
    final friendResult = await TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .getFriendList();
    // 群列表
    final groupResult = await TencentImSDKPlugin.v2TIMManager
        .getGroupManager()
        .getJoinedGroupList();

    if (!mounted) return;
    setState(() {
      _friends = friendResult.data?.map((f) => f!).toList() ?? [];
      _groups  = (groupResult.data ?? [])
          .where((g) => g != null)
          .map((g) => {
                'id':   g!.groupID ?? '',
                'name': g.groupName ?? g.groupID ?? '群聊',
                'face': g.faceUrl ?? '',
                'count': g.memberCount ?? 0,
              })
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // 拖动条
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // QR 快捷操作行
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(children: [
              _QrActionBtn(
                icon: Icons.qr_code_rounded,
                label: '我的二维码',
                onTap: widget.onMyQrTap,
              ),
              const SizedBox(width: 12),
              _QrActionBtn(
                icon: Icons.qr_code_scanner_rounded,
                label: '扫码加好友',
                onTap: widget.onScanQrTap,
              ),
            ]),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0x12000000)),

          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(children: [
              const Text('联系人', style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 20,
                fontWeight: FontWeight.w800, color: AppColors.onSurface,
              )),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: AppColors.onSurfaceVariant,
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // Tab
          TabBar(
            controller: _tab,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: '好友 ${_friends.isEmpty ? '' : '(${_friends.length})'}'),
              Tab(text: '族群 ${_groups.isEmpty ? '' : '(${_groups.length})'}'),
            ],
          ),

          const Divider(height: 1, thickness: 0.5, color: Color(0x18000000)),

          // 内容
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5))
                : TabBarView(
                    controller: _tab,
                    children: [
                      _FriendListTab(friends: _friends),
                      _GroupListTab(groups: _groups),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 好友列表 Tab ──────────────────────────────────────────────
class _FriendListTab extends ConsumerWidget {
  final List<V2TimFriendInfo> friends;
  const _FriendListTab({required this.friends});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (friends.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🐾', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text('还没有好友', style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 15,
            fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant,
          )),
          SizedBox(height: 4),
          Text('在社区认识新朋友，加他们为好友吧～', style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 12,
            color: AppColors.onSurfaceVariant,
          )),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final f    = friends[i];
        final uid  = f.userID ?? '';
        final name = f.friendRemark ?? f.userProfile?.nickName ?? uid;
        final face = f.userProfile?.faceUrl;

        return GestureDetector(
          onTap: () {
            Navigator.pop(ctx);
            ctx.push(AppRoutes.chat(uid));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, spreadRadius: -4)],
            ),
            child: Row(children: [
              PetAvatar(imageUrl: face, size: 44, fallbackEmoji: '🐾'),
              const SizedBox(width: 12),
              Expanded(child: Text(name,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface))),
              Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 18),
            ]),
          ),
        );
      },
    );
  }
}

// ── 族群列表 Tab ──────────────────────────────────────────────
class _GroupListTab extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  const _GroupListTab({required this.groups});

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🏡', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text('还没有加入任何族群', style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 15,
            fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant,
          )),
          SizedBox(height: 4),
          Text('加入族群，结识更多爱宠伙伴～', style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 12,
            color: AppColors.onSurfaceVariant,
          )),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final g     = groups[i];
        final name  = g['name'] as String;
        final face  = g['face'] as String;
        final count = g['count'] as int;

        return GestureDetector(
          onTap: () {
            Navigator.pop(ctx);
            // TODO: 跳转群聊页面
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, spreadRadius: -4)],
            ),
            child: Row(children: [
              PetAvatar(imageUrl: face.isNotEmpty ? face : null, size: 44, fallbackEmoji: '🏡'),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  Text('$count 名成员', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12, color: AppColors.onSurfaceVariant)),
                ],
              )),
              Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant, size: 20),
            ]),
          ),
        );
      },
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
            subtitle: hasFriendReq
                ? '$firstName 想和你成为好友${friendApplications.length > 1 ? '，共 ${friendApplications.length} 条待处理' : ''}'
                : '暂无新好友申请',
            time: hasFriendReq ? '刚刚' : '',
            hasUnread: hasFriendReq,
            onTap: hasFriendReq
                ? () => PetToast.show(context, '${friendApplications.length} 条好友申请待处理')
                : null,
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
      decoration: const BoxDecoration(
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
              const Text('互动通知', style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 20,
                fontWeight: FontWeight.w800, color: AppColors.onSurface,
              )),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: AppColors.onSurfaceVariant,
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0x18000000)),

          // 通知列表
          if (notices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('❤️', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Text('暂无互动通知', style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                    fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant,
                  )),
                  SizedBox(height: 4),
                  Text('当有人点赞或评论你的帖子时，通知会在这里显示', style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 12,
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
                separatorBuilder: (_, __) => const Divider(
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
    final isLike    = notice.isLike && !notice.isUnlike;
    final isUnlike  = notice.isUnlike;
    final isComment = notice.isComment;

    final IconData icon;
    final Color iconColor, iconBg;
    if (isUnlike) {
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
        const SizedBox(width: 12),
        // 文案
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              notice.content,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                fontWeight: FontWeight.w600, color: AppColors.onSurface,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 3),
            Text(timeStr, style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 11,
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
            if (time.isNotEmpty || hasUnread)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (time.isNotEmpty)
                    Text(time, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                        color: AppColors.onSurfaceVariant)),
                  if (hasUnread) ...[
                    const SizedBox(height: 4),
                    Container(width: 8, height: 8,
                        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                  ],
                ],
              ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.onSurfaceVariant),
            ],
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const double _kPanelW = 180.0; // 3 × 60
  static const double _kSnapThreshold = 0.35;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _open()  => _ctrl.animateTo(1.0,
      duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  void _close() => _ctrl.animateTo(0.0,
      duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);

  void _onDragUpdate(DragUpdateDetails d) {
    final v = _ctrl.value + (-d.delta.dx / _kPanelW);
    _ctrl.value = v.clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final vel = d.velocity.pixelsPerSecond.dx;
    if (_ctrl.value > _kSnapThreshold || vel < -500) {
      _open();
    } else {
      _close();
    }
  }

  Future<void> _runAction(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    _close();
    await fn();
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

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPinned
            ? AppColors.primaryContainer.withOpacity(0.08)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
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
                    style: const TextStyle(color: Colors.white,
                        fontSize: 9, fontWeight: FontWeight.w800))),
              ),
            ),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(name, style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                color: AppColors.onSurface))),
              if (isPinned)
                Icon(Icons.push_pin_rounded, size: 12,
                    color: AppColors.primary.withOpacity(0.6)),
            ]),
            const SizedBox(height: 3),
            Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                color: hasUnread
                    ? AppColors.onSurface : AppColors.onSurfaceVariant,
                fontWeight:
                    hasUnread ? FontWeight.w600 : FontWeight.w400)),
          ],
        )),
        Text(time, style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 10,
            color: AppColors.onSurfaceVariant)),
      ]),
    );

    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd:    _onDragEnd,
      onTap: () {
        if (_ctrl.value > 0.02) { _close(); return; }
        widget.onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Stack(children: [
            // ── 操作按钮区（右对齐）────────────────────────────
            Positioned.fill(child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(width: _kPanelW, child: Row(children: [
                // 置顶
                _SwipeActionBtn(
                  icon: isPinned
                      ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  label: isPinned ? '取消置顶' : '置顶',
                  color: AppColors.primary,
                  onTap: () => _runAction(widget.onPin),
                ),
                // 清空
                _SwipeActionBtn(
                  icon: Icons.delete_sweep_outlined,
                  label: '清空',
                  color: const Color(0xFFFF9500),
                  onTap: () => _runAction(widget.onClear),
                ),
                // 删除
                _SwipeActionBtn(
                  icon: Icons.delete_outline_rounded,
                  label: '删除',
                  color: AppColors.error,
                  onTap: () => _runAction(widget.onDelete),
                ),
              ])),
            )),
            // ── 卡片（向左滑动）──────────────────────────────
            Transform.translate(
              offset: Offset(-_kPanelW * _ctrl.value, 0),
              child: child,
            ),
          ]),
          child: card,
        ),
      ),
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

// ── 滑动操作按钮 ─────────────────────────────────────────────
class _SwipeActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SwipeActionBtn({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        color: color,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 11,
            fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

class _QrActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _QrActionBtn({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.primary, size: 26),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 12,
            fontWeight: FontWeight.w600, color: AppColors.primary,
          )),
        ]),
      ),
    ),
  );
}

// ── 会话管理菜单按钮 ──────────────────────────────────────────
class _ConvMenuBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ConvMenuBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 15,
          fontWeight: FontWeight.w600, color: color)),
      ]),
    ),
  );
}
