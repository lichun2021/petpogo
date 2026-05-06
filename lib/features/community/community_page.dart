import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../shared/theme/app_colors.dart';
import '../../app.dart' show AppL10nX;
import '../auth/controller/auth_controller.dart';
import '../message/controller/im_controller.dart';
import '../../core/router/app_routes.dart';
import 'controller/feed_controller.dart';
import 'data/models/post_model.dart';
import 'publish/publish_page.dart';
import 'viewer/post_viewer_page.dart';

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategory = 0;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  // ── 打开发布页 ──────────────────────────────────────────
  Future<void> _openPublish() async {
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PublishPage()),
    );
  }

  // ── 点击帖子 → 全屏查看 ─────────────────────────────────
  void _openViewer(int index) {
    final posts = ref.read(feedControllerProvider).posts;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PostViewerPage(posts: posts, initialIndex: index),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  // ── 当前登录用户 ID ─────────────────────────────────────
  String get _myUserId => ref.read(authControllerProvider).user?.id ?? '';

  // ── 点击头像：底部面板（自己的帖子不弹）──────────────────
  void _showUserPanel(BuildContext context, PostModel post) {
    if (post.userId == _myUserId) return; // 自己的帖子，不弹加好友
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
            title: Row(children: [
              Icon(Icons.pets_rounded, color: AppColors.primary, size: 22),
            ]),
            actions: [
              IconButton(
                icon: Icon(Icons.search_rounded, color: AppColors.onSurfaceVariant),
                onPressed: () {},
              ),
              // ── 发布按钮 ─────────────────────────────
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                ),
                onPressed: _openPublish,
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
              child: Column(children: [
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
              ]),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildFeedGrid(), _buildFeedGrid()],
        ),
      ),
    );
  }

  Widget _buildFeedGrid() {
    final feedState = ref.watch(feedControllerProvider);

    if (feedState.isLoading) {
      return _ShimmerGrid();
    }

    if (feedState.error != null && feedState.posts.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('加载失败，下拉重试', style: TextStyle(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => ref.read(feedControllerProvider.notifier).refresh(),
            child: const Text('重新加载'),
          ),
        ]),
      );
    }

    final posts = feedState.posts;

    if (posts.isEmpty) {
      return const Center(
        child: Text('还没有动态，来发第一条吧 🐾',
          style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: AppColors.onSurfaceVariant)),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(feedControllerProvider.notifier).refresh(),
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childCount: posts.length,
              itemBuilder: (_, i) => _PostCard(
                post: posts[i],
                index: i,
                onTap: () => _openViewer(i),
                onAvatarTap: () => _showUserPanel(context, posts[i]),
                onLike: () => ref.read(feedControllerProvider.notifier).toggleLike(posts[i].id),
              ).animate().fadeIn(delay: Duration(milliseconds: (i * 40).clamp(0, 400))).slideY(begin: 0.08),
            ),
          ),
          // 加载更多指示
          SliverToBoxAdapter(
            child: feedState.isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : feedState.hasMore
                    ? const SizedBox(height: 40)
                    : const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('没有更多了～', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13))),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── 帖子卡片（接真实数据）────────────────────────────────────
class _PostCard extends StatelessWidget {
  final PostModel post;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onAvatarTap;
  final VoidCallback onLike;

  const _PostCard({
    required this.post,
    required this.index,
    required this.onTap,
    required this.onAvatarTap,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 封面图 ────────────────────────────────
            if (post.thumbnailUrl != null)
              Hero(
                tag: 'post_thumb_${post.id}',
                child: _Thumbnail(url: post.thumbnailUrl!, isVideo: post.mediaType == MediaType.video),
              ),

            // ── 底部信息 ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 作者 + 点赞
                Row(children: [
                  GestureDetector(
                    onTap: onAvatarTap,
                    child: _SmallAvatar(url: post.userAvatar, name: post.nickname),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: onAvatarTap,
                      child: Text(post.nickname,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                    ),
                  ),
                  GestureDetector(
                    onTap: onLike,
                    child: Row(children: [
                      Icon(
                        post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: post.isLiked ? AppColors.error : AppColors.onSurfaceVariant.withOpacity(0.5),
                        size: 16,
                      ),
                      const SizedBox(width: 2),
                      Text('${post.likeCount}',
                        style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                    ]),
                  ),
                ]),

                if (post.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(post.content,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                        color: AppColors.onSurfaceVariant, height: 1.4)),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 封面图（带视频图标，固定宽高比 3:4 保证卡片等高）──────────
class _Thumbnail extends StatelessWidget {
  final String url;
  final bool isVideo;
  const _Thumbnail({required this.url, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      AspectRatio(
        aspectRatio: 3 / 4,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (_, __) => Container(color: AppColors.surfaceContainerHigh),
          errorWidget: (_, __, ___) => Container(
            color: AppColors.surfaceContainerHigh,
            child: const Center(
              child: Icon(Icons.broken_image_outlined, color: AppColors.onSurfaceVariant, size: 32),
            ),
          ),
        ),
      ),
      if (isVideo)
        Positioned(
          top: 8, right: 8,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
          ),
        ),
    ]);
  }
}

// ── 小头像 ───────────────────────────────────────────────────
class _SmallAvatar extends StatelessWidget {
  final String? url;
  final String name;
  const _SmallAvatar({this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(radius: 12, backgroundImage: CachedNetworkImageProvider(url!));
    }
    return CircleAvatar(
      radius: 12,
      backgroundColor: AppColors.primaryContainer,
      child: Text(name.isNotEmpty ? name[0] : '?',
        style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Shimmer 加载占位 ─────────────────────────────────────────
class _ShimmerGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceContainerLow,
      highlightColor: AppColors.surfaceContainerHigh,
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10, crossAxisSpacing: 10,
        padding: const EdgeInsets.all(12),
        itemCount: 8,
        itemBuilder: (_, i) => Container(
          height: i.isEven ? 200 : 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ── 分类 Chip ────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
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
      child: Text(label, style: TextStyle(
        fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w700,
        color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
      )),
    ),
  );
}

// ── 用户操作弹窗 ─────────────────────────────────────────────
class _UserActionDialog extends ConsumerStatefulWidget {
  final PostModel post;
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
      wording: '我在 PetPogo 看到你的动态，想加个好友～',
    );
    if (!mounted) return;
    setState(() { _adding = false; _added = ok; });
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('好友申请已发送给 ${widget.post.nickname} 的主人 🐾'),
        backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating,
      ));
    } else {
      final err = ref.read(imControllerProvider).errorMessage ?? '发送失败，请重试';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (post.userAvatar != null && post.userAvatar!.isNotEmpty)
            CircleAvatar(radius: 36, backgroundImage: CachedNetworkImageProvider(post.userAvatar!))
          else
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primaryContainer,
              child: Text(post.nickname.isNotEmpty ? post.nickname[0] : '?',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          const SizedBox(height: 12),
          Text(post.nickname, style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _DialogBtn(
              icon: Icons.chat_bubble_rounded, label: '发私信',
              color: AppColors.primaryContainer, textColor: AppColors.primary,
              onTap: () { Navigator.pop(context); context.push(AppRoutes.chat(post.userId)); },
            )),
            const SizedBox(width: 12),
            Expanded(child: _adding
              ? _DialogBtn(icon: Icons.hourglass_top_rounded, label: '发送中…',
                  color: AppColors.surfaceContainerHigh, textColor: AppColors.onSurfaceVariant, onTap: null)
              : _added
                ? _DialogBtn(icon: Icons.check_circle_rounded, label: '申请已发',
                    color: AppColors.surfaceContainerHigh, textColor: AppColors.primary, onTap: null)
                : _DialogBtn(icon: Icons.person_add_rounded, label: '加好友',
                    color: AppColors.primary, textColor: AppColors.onPrimary, onTap: _addFriend)),
          ]),
        ]),
      ),
    );
  }
}

class _DialogBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, textColor;
  final VoidCallback? onTap;
  const _DialogBtn({required this.icon, required this.label, required this.color, required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: textColor, size: 18),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
      ]),
    ),
  );
}
