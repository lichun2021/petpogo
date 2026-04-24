import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../shared/theme/app_colors.dart';
import '../../app.dart' show AppL10nX;

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategory = 0;

  final _posts = [
    _PostData(name: '可比',      caption: '找到了下午晒太阳的最佳位置 ☀️',    liked: true,  hasVideo: true,  aspect: 3 / 4,  emoji: '☀️'),
    _PostData(name: '奥利',      caption: '下雨天准备好了！☔️',               liked: false, hasVideo: false, aspect: 9 / 16, emoji: '🌂'),
    _PostData(name: '麻薯',      caption: '今天只想感受海边的风 🕶️🌊',        liked: false, hasVideo: false, aspect: 1,      emoji: '🌊'),
    _PostData(name: '小点',      caption: '到零食时间了吗？🥕',               liked: true,  hasVideo: false, aspect: 4 / 5,  emoji: '🥕'),
    _PostData(name: '露娜',      caption: '今天的捕猎技能满分！🧶',           liked: true,  hasVideo: false, aspect: 2 / 3,  emoji: '🧶', isFeatured: true),
    _PostData(name: '便当 & 布布', caption: '两只一起，双倍的麻烦，双倍的快乐！🐾🐾', liked: false, hasVideo: false, aspect: 1,  emoji: '🐾'),
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
            pinned: true,           // 固定顶部
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _posts.length,
      itemBuilder: (_, i) => _PostCard(post: _posts[i]),
    );
  }
}

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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(post.name,
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700,
                            fontSize: 16, color: AppColors.onSurface)),
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
                const SizedBox(height: 6),
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

class _PostData {
  final String name, caption, emoji;
  final bool liked, hasVideo;
  final double aspect;
  final bool isFeatured;

  const _PostData({
    required this.name, required this.caption, required this.liked,
    required this.hasVideo, required this.aspect, required this.emoji,
    this.isFeatured = false,
  });
}
