import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_colors.dart';
import '../../app.dart' show AppL10nX;
import '../message/controller/im_controller.dart';
import '../../core/router/app_routes.dart';

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategory = 0;

  final _posts = [
    _PostData(userId: 'user_001', name: '可比',       caption: '找到了下午晒太阳的最佳位置 ☀️',        liked: true,  hasVideo: true,  aspect: 3 / 4,  emoji: '☀️'),
    _PostData(userId: 'user_002', name: '奥利',       caption: '下雨天准备好了！☔️',                  liked: false, hasVideo: false, aspect: 9 / 16, emoji: '🌂'),
    _PostData(userId: 'user_003', name: '麻薯',       caption: '今天只想感受海边的风 🕶️🌊',           liked: false, hasVideo: false, aspect: 1,      emoji: '🌊'),
    _PostData(userId: 'user_004', name: '小点',       caption: '到零食时间了吗？🥕',                  liked: true,  hasVideo: false, aspect: 4 / 5,  emoji: '🥕'),
    _PostData(userId: 'user_005', name: '露娜',       caption: '今天的捕猎技能满分！🧶',              liked: true,  hasVideo: false, aspect: 2 / 3,  emoji: '🧶', isFeatured: true),
    _PostData(userId: 'user_006', name: '便当 & 布布', caption: '两只一起，双倍的麻烦，双倍的快乐！🐾🐾', liked: false, hasVideo: false, aspect: 1,  emoji: '🐾'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── 点击头像：底部面板 ──────────────────────────────────
  void _showUserPanel(BuildContext context, _PostData post) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => _UserActionDialog(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = [
      l10n.communityAllPets,
      l10n.communityDogs,
      l10n.communityCats,
      l10n.communityBirds,
      l10n.communityOthers,
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: false,
            snap: false,
            backgroundColor: AppColors.surface.withOpacity(0.95),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            title: Row(
              children: [
                Icon(Icons.pets_rounded, color: AppColors.primary, size: 22),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.search_rounded, color: AppColors.onSurfaceVariant),
                onPressed: () {},
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  child: Icon(Icons.person_rounded, size: 18, color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(92),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.onSurfaceVariant,
                    indicatorColor: AppColors.primary,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w500),
                    tabs: [
                      Tab(text: l10n.communityTabFollowing),
                      Tab(text: l10n.communityTabDiscover),
                    ],
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _CategoryChip(
                        label: categories[i],
                        selected: _selectedCategory == i,
                        onTap: () => setState(() => _selectedCategory = i),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildGrid(), _buildGrid()],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _posts.length,
      itemBuilder: (_, i) => _PostCard(
        post: _posts[i],
        onAvatarTap: () => _showUserPanel(context, _posts[i]),
      ),
    );
  }
}

// ── 居中操作弹窗 ─────────────────────────────────────────────
class _UserActionDialog extends ConsumerStatefulWidget {
  final _PostData post;
  const _UserActionDialog({required this.post});

  @override
  ConsumerState<_UserActionDialog> createState() => _UserActionDialogState();
}

class _UserActionDialogState extends ConsumerState<_UserActionDialog> {
  bool _adding = false;
  bool _added  = false;

  Future<void> _addFriend() async {
    setState(() => _adding = true);
    final ok = await ref.read(imControllerProvider.notifier).addFriend(
      toUserId: widget.post.userId,
      wording: '我在 PetPogo 看到你的宠物，想加个好友～',
    );
    if (!mounted) return;
    setState(() { _adding = false; _added = ok; });
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('好友申请已发送给 ${widget.post.name} 的主人 🐾'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // 读取错误消息
      final err = ref.read(imControllerProvider).errorMessage ?? '发送失败，请重试';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    // 居中 Dialog 卡片布局
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 40, spreadRadius: -4)],
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              post.emoji,
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${post.name} 的主人',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 18, fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          Text(
            '@${post.userId}',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // 操作按钮（全宽，不加额外 Padding，Dialog 本身已有 24 水平内边距）
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.chat_bubble_rounded,
                  label: '发私信',
                  color: AppColors.primaryContainer,
                  textColor: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.chat(post.userId));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _adding
                    ? _ActionButton(
                        icon: Icons.hourglass_top_rounded,
                        label: '发送中…',
                        color: AppColors.surfaceContainerHigh,
                        textColor: AppColors.onSurfaceVariant,
                        onTap: null,
                      )
                    : _added
                        ? _ActionButton(
                            icon: Icons.check_circle_rounded,
                            label: '申请已发',
                            color: AppColors.surfaceContainerHigh,
                            textColor: AppColors.primary,
                            onTap: null,
                          )
                        : _ActionButton(
                            icon: Icons.person_add_rounded,
                            label: '加好友',
                            color: AppColors.primary,
                            textColor: AppColors.onPrimary,
                            onTap: _addFriend,
                          ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, textColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 14,
              fontWeight: FontWeight.w700, color: textColor,
            )),
          ],
        ),
      ),
    );
  }
}

// ── 分类筛选 chip ────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.primaryGlow, blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Text(label,
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w700,
                color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant)),
      ),
    );
  }
}

// ── 帖子卡片 ─────────────────────────────────────────────────
class _PostCard extends StatefulWidget {
  final _PostData post;
  final VoidCallback onAvatarTap;
  const _PostCard({required this.post, required this.onAvatarTap});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late bool _liked;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.liked;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final post = widget.post;
    return Container(
      decoration: BoxDecoration(
        color: post.isFeatured
            ? AppColors.secondaryContainer.withOpacity(0.15)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: post.aspect,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [AppColors.surfaceContainerHigh, AppColors.surfaceContainerHighest],
                    ),
                  ),
                  child: Center(
                    child: Text(post.emoji, style: TextStyle(fontSize: post.aspect < 1 ? 48 : 36)),
                  ),
                ),
              ),
              if (post.isFeatured)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    color: AppColors.secondaryContainer.withOpacity(0.85),
                    child: Text(l10n.communityFeaturedStory,
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9,
                            fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.secondary)),
                  ),
                ),
              if (post.hasVideo)
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头像 + 名字 + 点赞
                Row(
                  children: [
                    // ✅ 头像：点击触发加好友面板
                    GestureDetector(
                      onTap: widget.onAvatarTap,
                      child: Hero(
                        tag: 'avatar_${post.userId}',
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(post.emoji, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onAvatarTap,
                        child: Text(post.name,
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700,
                              fontSize: 13, color: AppColors.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _liked = !_liked),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          key: ValueKey(_liked),
                          color: _liked ? AppColors.error : AppColors.onSurfaceVariant.withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(post.caption,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                        color: AppColors.onSurfaceVariant, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 数据模型 ─────────────────────────────────────────────────
class _PostData {
  final String userId, name, caption, emoji;
  final bool liked, hasVideo;
  final double aspect;
  final bool isFeatured;

  const _PostData({
    required this.userId,
    required this.name, required this.caption, required this.liked,
    required this.hasVideo, required this.aspect, required this.emoji,
    this.isFeatured = false,
  });
}
