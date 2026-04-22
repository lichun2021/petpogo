import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../shared/theme/app_colors.dart';

/// 社区页 — 设计稿 Image 3/4 还原
/// 布局：Following/Discover Tab → 分类 Chip → 瀑布流卡片
/// 设计特点：
///   - 图片突破卡片顶边（break-top 效果）
///   - 无内部分割线，用白空间分隔名称与描述
///   - Featured Story 用 secondary-container 色调
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategory = 0;

  final _categories = ['All Pets', 'Dogs', 'Cats', 'Birds', 'Others'];

  // 模拟数据（实际从 API 获取）
  final _posts = [
    _PostData(
      name: 'Cooper',
      caption: 'Just found the perfect spot for an afternoon...',
      liked: true,
      hasVideo: true,
      aspect: 3 / 4,
      emoji: '☀️',
    ),
    _PostData(
      name: 'Oliver',
      caption: 'Ready for the rain! ☔️',
      liked: false,
      hasVideo: false,
      aspect: 9 / 16,
      emoji: '🌂',
    ),
    _PostData(
      name: 'Mochi',
      caption: 'Beach vibes only today. 🕶️🌊',
      liked: false,
      hasVideo: false,
      aspect: 1,
      emoji: '🌊',
    ),
    _PostData(
      name: 'Pip',
      caption: 'Is it snack time yet? 🥕',
      liked: true,
      hasVideo: false,
      aspect: 4 / 5,
      emoji: '🥕',
    ),
    _PostData(
      name: 'Luna',
      caption: 'Hunting skills are 10/10 today! 🧶',
      liked: true,
      hasVideo: false,
      aspect: 2 / 3,
      emoji: '🧶',
      isFeatured: true,
    ),
    _PostData(
      name: 'Bento & Boo',
      caption: 'Double the trouble, double the fun! 🐾🐾',
      liked: false,
      hasVideo: false,
      aspect: 1,
      emoji: '🐾',
    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── AppBar ─────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: false,
            backgroundColor: AppColors.surface.withOpacity(0.9),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            title: Row(
              children: [
                Icon(Icons.pets_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 6),
                Text(
                  'PetPogo',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
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
            // Following / Discover Tab
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(92),
              child: Column(
                children: [
                  // Tab
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.onSurfaceVariant,
                    indicatorColor: AppColors.primary,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [Tab(text: 'Following'), Tab(text: 'Discover')],
                  ),
                  // Category Chips
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _CategoryChip(
                        label: _categories[i],
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
          children: [
            _buildGrid(),
            _buildGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _posts.length,
      itemBuilder: (_, i) => _PostCard(post: _posts[i]),
    );
  }
}

// ── 分类 Chip ─────────────────────────────────────────
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
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── 帖子卡片 ─────────────────────────────────────────
class _PostCard extends StatefulWidget {
  final _PostData post;
  const _PostCard({required this.post});

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
    final post = widget.post;
    return Container(
      decoration: BoxDecoration(
        // 无边框，用 surfaceContainerLowest 与页面背景形成色调分层
        color: post.isFeatured
            ? AppColors.secondaryContainer.withOpacity(0.15)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 图片区域 ─────────────────────────────────
          Stack(
            children: [
              // 使用彩色渐变作为图片占位（实际用 CachedNetworkImage）
              AspectRatio(
                aspectRatio: post.aspect,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surfaceContainerHigh,
                        AppColors.surfaceContainerHighest,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      post.emoji,
                      style: TextStyle(fontSize: post.aspect < 1 ? 48 : 36),
                    ),
                  ),
                ),
              ),
              // Featured Story 标签
              if (post.isFeatured)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    color: AppColors.secondaryContainer.withOpacity(0.85),
                    child: Text(
                      'FEATURED STORY',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
              // 视频播放按钮
              if (post.hasVideo)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),

          // ── 文字区域 ─────────────────────────────────
          // 无分割线，用 16px 垂直白空间
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      post.name,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.onSurface,
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
                // 无分割线 — 用 8px 白空间替代
                const SizedBox(height: 6),
                Text(
                  post.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 数据模型 ──────────────────────────────────────────
class _PostData {
  final String name;
  final String caption;
  final bool liked;
  final bool hasVideo;
  final double aspect;
  final String emoji;
  final bool isFeatured;

  const _PostData({
    required this.name,
    required this.caption,
    required this.liked,
    required this.hasVideo,
    required this.aspect,
    required this.emoji,
    this.isFeatured = false,
  });
}
