import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import 'data/music_models.dart';
import 'data/music_repository.dart';

// ── 播放状态 Provider ─────────────────────────────────────
final _playerProvider = Provider.autoDispose<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

final _playingIdProvider = StateProvider<int?>((ref) => null);

// ═══════════════════════════════════════════════════════════
// 宠物音乐页
// ═══════════════════════════════════════════════════════════
class PetMusicPage extends ConsumerStatefulWidget {
  const PetMusicPage({super.key});

  @override
  ConsumerState<PetMusicPage> createState() => _PetMusicPageState();
}

class _PetMusicPageState extends ConsumerState<PetMusicPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  List<MusicCategory> _categories = [];
  bool  _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 1, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ref.read(musicRepositoryProvider).fetchAllMusic();
      if (!mounted) return;
      setState(() {
        _categories = list;
        _loading = false;
      });
      if (_categories.isNotEmpty) {
        _tabCtrl.dispose();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              color: AppColors.onSurface,
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('宠物音乐',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 17, fontWeight: FontWeight.w800)),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.playlist_add_rounded),
                color: AppColors.primary,
                onPressed: () => _showCreatePlaylistSheet(),
                tooltip: '新建歌单',
              ),
            ],
            bottom: _categories.isEmpty ? null : TabBar(
              controller: TabController(
                length: _categories.length, vsync: this,
                initialIndex: 0,
              ),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13, fontWeight: FontWeight.w500),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              tabs: _categories.map((c) => Tab(text: c.name)).toList(),
            ),
          ),
        ],
        body: _buildBody(),
      ),
      bottomSheet: const _MiniPlayer(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(_error!, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 13, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        FilledButton(onPressed: _load, child: const Text('重试')),
      ]));
    }
    if (_categories.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.music_off_rounded, size: 72,
            color: AppColors.onSurfaceVariant.withOpacity(0.3)),
        const SizedBox(height: 16),
        const Text('暂无音乐', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        const Text('管理员正在添加适合宠物的音乐，敬请期待',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 13, color: AppColors.onSurfaceVariant)),
      ]));
    }

    // Tab 视图，每个分类一个列表
    return DefaultTabController(
      length: _categories.length,
      child: Column(children: [
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 13, fontWeight: FontWeight.w500),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          tabs: _categories.map((c) => Tab(text: '${c.name} (${c.songs.length})'))
              .toList(),
        ),
        Expanded(
          child: TabBarView(
            children: _categories.map((cat) => _MusicList(category: cat)).toList(),
          ),
        ),
      ]),
    );
  }

  void _showCreatePlaylistSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('新建歌单', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '歌单名称',
                filled: true, fillColor: AppColors.surfaceContainer,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(context);
                try {
                  await ref.read(musicRepositoryProvider)
                      .createPlaylist(name: ctrl.text.trim());
                  if (mounted) PetToast.success(context, '歌单已创建');
                } catch (e) {
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

// ── 分类音乐列表 ──────────────────────────────────────────
class _MusicList extends ConsumerWidget {
  final MusicCategory category;
  const _MusicList({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: category.songs.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
      itemBuilder: (_, i) => _SongTile(song: category.songs[i]),
    );
  }
}

// ── 单曲行 ────────────────────────────────────────────────
class _SongTile extends ConsumerWidget {
  final MusicItem song;
  const _SongTile({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playingId = ref.watch(_playingIdProvider);
    final isPlaying = playingId == song.id;

    return InkWell(
      onTap: () async {
        HapticFeedback.selectionClick();
        final player = ref.read(_playerProvider);
        if (isPlaying) {
          await player.pause();
          ref.read(_playingIdProvider.notifier).state = null;
        } else {
          ref.read(_playingIdProvider.notifier).state = song.id;
          try {
            await player.setUrl(song.url);
            await player.play();
          } catch (e) {
            ref.read(_playingIdProvider.notifier).state = null;
            if (context.mounted) PetToast.warning(context, '播放失败，请检查网络');
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          // 封面 / 播放状态
          Stack(alignment: Alignment.center, children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: song.iconUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(song.iconUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.music_note_rounded, color: AppColors.primary, size: 22)))
                  : const Icon(Icons.music_note_rounded, color: AppColors.primary, size: 22),
            ),
            if (isPlaying)
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pause_rounded, color: Colors.white, size: 20),
              ),
          ]),
          const SizedBox(width: 12),

          // 标题+艺人
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(song.name,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: isPlaying ? AppColors.primary : AppColors.onSurface),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (song.artist != null && song.artist!.isNotEmpty)
              Text(song.artist!,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11, color: AppColors.onSurfaceVariant)),
          ])),

          // 时长
          if (song.durationText.isNotEmpty)
            Text(song.durationText,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11, color: AppColors.onSurfaceVariant)),
          const SizedBox(width: 8),

          // 播放状态指示
          if (isPlaying)
            const Icon(Icons.equalizer_rounded, size: 18, color: AppColors.primary)
          else
            const Icon(Icons.play_circle_outline_rounded, size: 20,
                color: AppColors.onSurfaceVariant),
        ]),
      ),
    );
  }
}

// ── 底部迷你播放器 ────────────────────────────────────────
class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playingId = ref.watch(_playingIdProvider);
    if (playingId == null) return const SizedBox.shrink();

    final player = ref.read(_playerProvider);

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 16)],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('正在播放',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            StreamBuilder<bool>(
              stream: player.playingStream,
              builder: (_, snap) {
                final playing = snap.data ?? false;
                return Row(children: [
                  IconButton(
                    icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white, size: 28),
                    onPressed: () => playing ? player.pause() : player.play(),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
                    onPressed: () {
                      player.stop();
                      ref.read(_playingIdProvider.notifier).state = null;
                    },
                    padding: EdgeInsets.zero,
                  ),
                ]);
              },
            ),
          ]),
        ),
      ),
    );
  }
}
