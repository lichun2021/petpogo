import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import 'data/music_models.dart';
import 'data/music_repository.dart';
import 'music_category_page.dart';

// ── 分类卡片颜色 ──────────────────────────────────────────
const _cardColors = [
  Color(0xFF2C3E50), Color(0xFFF39C12),
  Color(0xFF16A085), Color(0xFF27AE60),
  Color(0xFF8E44AD), Color(0xFFE74C3C),
];

// ── 宠物类型过滤（客户端）────────────────────────────────
// petType 字段: 'all'=通用 'dog'=狗 'cat'=猫
// 分类只要包含至少一首匹配的歌曲就保留

List<MusicCategory> _filterByPetType(
    List<MusicCategory> all, int petTypeIdx) {
  // 0=全部：直接返回
  if (petTypeIdx == 0) return all;
  final target = petTypeIdx == 1 ? 'dog' : 'cat';
  return all
      .map((cat) {
        final songs = cat.songs
            .where((s) => s.petType == target || s.petType == 'all')
            .toList();
        if (songs.isEmpty) return null;
        return MusicCategory(name: cat.name, iconUrl: cat.iconUrl, songs: songs);
      })
      .whereType<MusicCategory>()
      .toList();
}

// ═══════════════════════════════════════════════════════════
// 宠物音乐主页
// ═══════════════════════════════════════════════════════════
class PetMusicPage extends ConsumerStatefulWidget {
  const PetMusicPage({super.key});
  @override
  ConsumerState<PetMusicPage> createState() => _PetMusicPageState();
}

class _PetMusicPageState extends ConsumerState<PetMusicPage>
    with SingleTickerProviderStateMixin {
  late final TabController _mainTab;

  // 全量数据（一次加载）
  List<MusicCategory> _allCategories = [];
  List<Playlist>      _playlists     = [];
  bool   _loading = true;
  int    _petType = 0; // 0=全部 1=狗狗 2=猫咪

  // 过滤后展示的分类（不触发网络请求）
  List<MusicCategory> get _displayCategories =>
      _filterByPetType(_allCategories, _petType);

  @override
  void initState() {
    super.initState();
    _mainTab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _mainTab.dispose(); super.dispose(); }

  // 只在进页面 & 下拉刷新时请求，不因切换 petType 重复请求
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 不传 petType，一次拿全部数据
      final cats  = await ref.read(musicRepositoryProvider).fetchAllMusic();
      final lists = await ref.read(musicRepositoryProvider)
          .fetchPlaylists().catchError((_) => <Playlist>[]);
      if (mounted) setState(() {
        _allCategories = cats;
        _playlists     = lists;
        _loading       = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true, floating: false,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent, elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('宠物音乐',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 17, fontWeight: FontWeight.w800)),
            centerTitle: false,
            actions: [
              IconButton(icon: const Icon(Icons.volume_up_outlined),
                  color: AppColors.onSurface, onPressed: () {}),
            ],
            bottom: TabBar(
              controller: _mainTab,
              indicatorColor: AppColors.primary, indicatorWeight: 3,
              labelStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 14),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              tabs: const [Tab(text: '推荐'), Tab(text: '限免')],
            ),
          ),
        ],
        body: TabBarView(
          controller: _mainTab,
          children: [
            _buildRecommendTab(),
            _buildFreeTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendTab() {
    if (_loading) return const Center(
        child: CircularProgressIndicator(color: AppColors.primary));
    final cats = _displayCategories;
    return RefreshIndicator(
      onRefresh: _load, color: AppColors.primary,
      child: CustomScrollView(slivers: [
        // 横幅（固定，不因切换闪烁）
        SliverToBoxAdapter(child: _Banner()),
        // 宠物类型筛选（切换只改 _petType，不请求网络）
        SliverToBoxAdapter(child: _PetTypeBar(
          selected: _petType,
          onSelect: (v) {
            if (v == _petType) return;
            setState(() => _petType = v); // 纯客户端过滤
          },
        )),
        // 过滤结果提示（非「全部」时显示）
        if (_petType != 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Icon(Icons.filter_alt_outlined, size: 13,
                    color: AppColors.primary.withOpacity(0.8)),
                const SizedBox(width: 4),
                Text(
                  '已筛选：共 ${_displayCategories.fold(0, (s, c) => s + c.songs.length)} 首'
                      '（${_petType == 1 ? "狗狗" : "猫咪"}专属 + 通用）',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    color: AppColors.primary.withOpacity(0.8),
                  ),
                ),
              ]),
            ),
          ),
        // 分类卡片网格
        if (cats.isEmpty)
          SliverToBoxAdapter(child: _emptyCategories())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final cat = cats[i];
                  return _CategoryCard(
                    category: cat,
                    color: _cardColors[i % _cardColors.length],
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MusicCategoryPage(category: cat),
                    )),
                  );
                },
                childCount: cats.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12,
                mainAxisSpacing: 12, childAspectRatio: 1.0,
              ),
            ),
          ),
        // 我的歌单
        SliverToBoxAdapter(child: _MyPlaylists(
          playlists: _playlists,
          onAdd: _showCreatePlaylist,
          onOpen: (pl) => Navigator.push(context, MaterialPageRoute(
            builder: (_) => MusicCategoryPage(playlist: pl),
          )),
          onRefresh: _load,
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ]),
    );
  }

  Widget _buildFreeTab() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.lock_open_rounded, size: 64,
          color: AppColors.onSurfaceVariant.withOpacity(0.3)),
      const SizedBox(height: 16),
      const Text('限免专区即将上线', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
    ]),
  );

  Widget _emptyCategories() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.music_off_rounded, size: 64,
          color: AppColors.onSurfaceVariant.withOpacity(0.3)),
      const SizedBox(height: 12),
      const Text('暂无音乐内容', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
          fontSize: 14, color: AppColors.onSurfaceVariant)),
    ])),
  );

  void _showCreatePlaylist() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('新建歌单', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl, autofocus: true,
              decoration: InputDecoration(
                hintText: '歌单名称',
                filled: true, fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(context);
                try {
                  await ref.read(musicRepositoryProvider).createPlaylist(name: ctrl.text.trim());
                  if (mounted) { PetToast.success(context, '歌单已创建'); _load(); }
                } catch (_) {
                  if (mounted) PetToast.warning(context, '创建失败，请重试');
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('创建', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── 横幅 ──────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 100,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF48CAE4), Color(0xFF52B788)],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
        ),
        child: Stack(children: [
          // 装饰圆
          Positioned(right: -20, top: -20,
            child: Container(width: 120, height: 120,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle))),
          Positioned(right: 60, bottom: -30,
            child: Container(width: 80, height: 80,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle))),
          // 文字
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('安抚  疗愈  欢乐',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text('为毛孩子开启音乐魔力',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12, color: Colors.white.withOpacity(0.85))),
            ]),
          ),
          // 右侧音乐图标装饰
          Positioned(right: 20, top: 0, bottom: 0,
            child: Center(child: Icon(Icons.music_note_rounded,
                size: 48, color: Colors.white.withOpacity(0.25)))),
        ]),
      ),
    ),
  );
}

// ── 宠物类型筛选 ──────────────────────────────────────────
class _PetTypeBar extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  const _PetTypeBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Row(children: ['全部', '狗狗', '猫咪'].asMap().entries.map((e) {
      final active = e.key == selected;
      return GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onSelect(e.key); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? AppColors.primary : Colors.grey.withOpacity(0.2)),
          ),
          child: Text(e.value,
              style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.onSurfaceVariant)),
        ),
      );
    }).toList()),
  );
}

// ── 分类卡片 ──────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final MusicCategory category;
  final Color         color;
  final VoidCallback  onTap;
  const _CategoryCard({required this.category, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = category.iconUrl
        ?? (category.songs.isNotEmpty ? category.songs.first.iconUrl : null);

    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(fit: StackFit.expand, children: [
          // ① 底色（无图时显示）
          Container(color: color),
          // ② 封面图铺满
          if (cover != null)
            CachedNetworkImage(
              imageUrl: cover, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox(),
            ),
          // ③ 渐变遮罩（保证文字可读）
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(cover != null ? 0.65 : 0),
                  Colors.black.withOpacity(cover != null ? 0.45 : 0),
                ],
              ),
            ),
          ),
          // ④ 文字内容
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 48, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(category.name,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black38)])),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${category.songs.length} 首',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.95))),
              ),
            ]),
          ),
          // ⑤ 播放按钮
          Positioned(right: 10, top: 10,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 我的歌单 ──────────────────────────────────────────────
class _MyPlaylists extends StatelessWidget {
  final List<Playlist>      playlists;
  final VoidCallback        onAdd;
  final void Function(Playlist) onOpen;
  final VoidCallback        onRefresh;
  const _MyPlaylists({required this.playlists, required this.onAdd,
      required this.onOpen, required this.onRefresh});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('我的歌单', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 15, fontWeight: FontWeight.w800)),
        const Spacer(),
        // NEW 标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: AppColors.primary,
              borderRadius: BorderRadius.circular(4)),
          child: const Text('NEW', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      if (playlists.isEmpty)
        GestureDetector(
          onTap: onAdd,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.15)),
            ),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_circle_outline_rounded, size: 28,
                  color: AppColors.primary.withOpacity(0.5)),
              const SizedBox(height: 4),
              const Text('新建歌单', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12, color: AppColors.onSurfaceVariant)),
            ])),
          ),
        )
      else
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _PlaylistCard(
                playlist: playlists[i], onTap: () => onOpen(playlists[i])),
          ),
        ),
    ]),
  );
}

class _PlaylistCard extends StatelessWidget {
  final Playlist     playlist;
  final VoidCallback onTap;
  const _PlaylistCard({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 80,
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: playlist.coverUrl != null
              ? CachedNetworkImage(
                  imageUrl: playlist.coverUrl!, width: 72, height: 72, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _defaultCover())
              : _defaultCover(),
        ),
        const SizedBox(height: 6),
        Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 11, fontWeight: FontWeight.w600)),
        Text('${playlist.songCount}首', style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 10, color: AppColors.onSurfaceVariant)),
      ]),
    ),
  );

  Widget _defaultCover() => Container(
    width: 72, height: 72,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 32),
  );
}
