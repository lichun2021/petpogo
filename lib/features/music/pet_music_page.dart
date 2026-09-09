import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import 'data/music_models.dart';
import 'controller/music_controller.dart';
import '../../shared/theme/app_tokens.dart';
import '../../shared/widgets/app_error_view.dart';
import 'music_category_page.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

// ── 宠物类型过滤（客户端）────────────────────────────────
// petType 字段: 'all'=通用 'dog'=狗 'cat'=猫
// 分类只要包含至少一首匹配的歌曲就保留

List<MusicCategory> _filterByPetType(List<MusicCategory> all, int petTypeIdx) {
  // 0=全部：直接返回
  if (petTypeIdx == 0) return all;
  final target = petTypeIdx == 1 ? 'dog' : 'cat';
  return all
      .map((cat) {
        final songs = cat.songs
            .where((s) => s.petType == target || s.petType == 'all')
            .toList();
        if (songs.isEmpty) return null;
        return MusicCategory(
            name: cat.name, iconUrl: cat.iconUrl, songs: songs);
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

class _PetMusicPageState extends ConsumerState<PetMusicPage> {
  int _petType = 0;

  Future<void> _load() => ref.read(musicControllerProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surfacePage,
      appBar: AppBar(title: const Text('宠物音乐'), centerTitle: false),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          key: const PageStorageKey('pet-music'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _Banner()),
            SliverToBoxAdapter(
                child: _PetTypeBar(
                    selected: _petType,
                    onSelect: (value) => setState(() => _petType = value))),
            if (state.refreshing)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
            if (state.categories != null)
              state.categories!.when(
                success: (categories) {
                  final cats = _filterByPetType(categories, _petType);
                  if (cats.isEmpty)
                    return SliverToBoxAdapter(child: _emptyCategories());
                  return SliverPadding(
                    padding: AppSpacing.screen,
                    sliver:
                        SliverLayoutBuilder(builder: (context, constraints) {
                      final largeText =
                          MediaQuery.textScalerOf(context).scale(15) > 20;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              largeText && constraints.crossAxisExtent < 360
                                  ? 1
                                  : 2,
                          crossAxisSpacing: AppSpacing.x12,
                          mainAxisSpacing: AppSpacing.x12,
                          childAspectRatio: 1,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final cat = cats[index];
                          return _CategoryCard(
                              category: cat,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          MusicCategoryPage(category: cat))));
                        }, childCount: cats.length),
                      );
                    }),
                  );
                },
                failure: (error) => SliverToBoxAdapter(
                    child: AppErrorView(
                        error: error, fallback: '音乐加载失败，请重试', onRetry: _load)),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.sectionGap,
                  AppSpacing.screenHorizontal,
                  AppSpacing.x12),
              sliver: SliverToBoxAdapter(
                  child: Row(children: [
                Expanded(
                    child: Text('我的歌单',
                        style: Theme.of(context).textTheme.titleMedium)),
                TextButton.icon(
                    onPressed: _showCreatePlaylist,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('新建')),
              ])),
            ),
            if (state.playlists != null)
              state.playlists!.when(
                success: (playlists) => playlists.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                            padding: AppSpacing.screen,
                            child: OutlinedButton.icon(
                                onPressed: _showCreatePlaylist,
                                icon: const Icon(Icons.queue_music_rounded),
                                label: const Text('创建第一张歌单'))))
                    : SliverPadding(
                        padding: AppSpacing.screen,
                        sliver: SliverList.builder(
                            itemCount: playlists.length,
                            itemBuilder: (context, index) => _PlaylistCard(
                                playlist: playlists[index],
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => MusicCategoryPage(
                                            playlist: playlists[index])))))),
                failure: (error) => SliverToBoxAdapter(
                    child: AppErrorView(
                        error: error,
                        fallback: '歌单加载失败，请重试',
                        onRetry: () => ref
                            .read(musicControllerProvider.notifier)
                            .refreshPlaylists())),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x32)),
          ],
        ),
      ),
    );
  }

  Widget _emptyCategories() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.music_off_rounded,
              size: 64, color: AppColors.onSurfaceVariant.withOpacity(0.3)),
          SizedBox(height: 12),
          Text('暂无音乐内容',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant)),
        ])),
      );

  void _showCreatePlaylist() {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const _CreatePlaylistSheet());
  }
}

class _CreatePlaylistSheet extends ConsumerStatefulWidget {
  const _CreatePlaylistSheet();
  @override
  ConsumerState<_CreatePlaylistSheet> createState() =>
      _CreatePlaylistSheetState();
}

class _CreatePlaylistSheetState extends ConsumerState<_CreatePlaylistSheet> {
  final _name = TextEditingController();
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final result = await ref
        .read(musicControllerProvider.notifier)
        .createPlaylist(_name.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
        success: (_) {
          PetToast.success(context, '歌单已创建');
          Navigator.pop(context);
        },
        failure: (error) => PetToast.error(context, error));
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('新建歌单', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.x16),
                  TextField(
                      controller: _name,
                      autofocus: true,
                      enabled: !_saving,
                      maxLength: 40,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: '歌单名称', hintText: '例如：晚安陪伴')),
                  const SizedBox(height: AppSpacing.x16),
                  FilledButton(
                      onPressed:
                          _saving || _name.text.trim().isEmpty ? null : _save,
                      child: Text(_saving ? '创建中…' : '创建')),
                ]),
          ),
        ),
      );
}

// ── 横幅 ──────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.screenHorizontal,
      AppSpacing.x16, AppSpacing.screenHorizontal, AppSpacing.x12),
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.x24),
      decoration: BoxDecoration(borderRadius: AppRadius.cardRadius,
        gradient: LinearGradient(colors: [AppColors.brandPrimary, AppColors.brandPrimaryStrong])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('安抚 · 陪伴 · 欢乐', style: TextStyle(fontFamily: AppFonts.primary,
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textOnBrand)),
        const SizedBox(height: AppSpacing.x8),
        Text('为毛孩子挑一段喜欢的旋律', style: TextStyle(fontFamily: AppFonts.primary,
          fontSize: 12, color: AppColors.textOnBrand)),
      ]),
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
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenHorizontal,
            AppSpacing.x4, AppSpacing.screenHorizontal, AppSpacing.x12),
        child: Wrap(
            spacing: AppSpacing.x8,
            runSpacing: AppSpacing.x8,
            children: ['全部', '狗狗', '猫咪'].asMap().entries.map((e) {
              final active = e.key == selected;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(e.key);
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  constraints:
                      const BoxConstraints(minHeight: AppSize.touchMin),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x16, vertical: AppSpacing.x12),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.brandPrimarySoft
                        : AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active
                            ? AppColors.brandPrimarySoft
                            : AppColors.borderSubtle),
                  ),
                  child: Text(e.value,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? AppColors.brandPrimaryStrong
                              : AppColors.textSecondary)),
                ),
              );
            }).toList()),
      );
}

// ── 分类卡片 ──────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final MusicCategory category;
  final VoidCallback onTap;
  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = category.iconUrl ??
        (category.songs.isNotEmpty ? category.songs.first.iconUrl : null);
    final hasCover = cover?.trim().isNotEmpty == true;
    // 有封面：白字压深棕遮罩；无封面：浅底深字 + 品牌色小件（不铺大面积品牌色）
    final fg = hasCover ? Colors.white : AppColors.textPrimary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(fit: StackFit.expand, children: [
          // ① 底色（无图时显示）
          Container(color: AppColors.surfaceSunken),
          // ② 封面图铺满
          if (hasCover)
            CachedNetworkImage(
              imageUrl: cover!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => SizedBox(),
            ),
          // ③ 渐变遮罩（保证文字可读）
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.textPrimary.withValues(alpha: hasCover ? 0.65 : 0),
                  AppColors.textPrimary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          // ④ 文字内容
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: fg,
                      shadows: hasCover
                          ? [Shadow(blurRadius: 4, color: Colors.black38)]
                          : null)),
              SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hasCover
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.brandPrimarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${category.songs.length} 首',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hasCover
                            ? Colors.white.withValues(alpha: 0.95)
                            : AppColors.brandPrimaryStrong)),
              ),
            ]),
          ),
          // ⑤ 播放按钮
          Positioned(
            right: AppSpacing.x12,
            bottom: AppSpacing.x12,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: hasCover
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow_rounded,
                  color: AppColors.textOnBrand, size: 18),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 我的歌单 ──────────────────────────────────────────────
class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  const _PlaylistCard({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x12),
        child: Material(
            color: AppColors.surfaceCard,
            borderRadius: AppRadius.cardRadius,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.cardRadius,
              child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: Row(children: [
                    ClipRRect(
                        borderRadius: AppRadius.controlRadius,
                        child: SizedBox(
                            width: AppSpacing.x48,
                            height: AppSpacing.x48,
                            child: playlist.coverUrl?.trim().isNotEmpty == true
                                ? CachedNetworkImage(
                                    imageUrl: playlist.coverUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => _defaultCover(),
                                    errorWidget: (_, __, ___) =>
                                        _defaultCover())
                                : _defaultCover())),
                    const SizedBox(width: AppSpacing.x12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(playlist.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: AppSpacing.x4),
                          Text('${playlist.songCount} 首',
                              style: Theme.of(context).textTheme.bodySmall),
                        ])),
                    const SizedBox(width: AppSpacing.x8),
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary),
                  ])),
            )),
      );

  Widget _defaultCover() => ColoredBox(
      color: AppColors.surfaceSunken,
      child: Icon(Icons.queue_music_rounded, color: AppColors.brandPrimary));
}
