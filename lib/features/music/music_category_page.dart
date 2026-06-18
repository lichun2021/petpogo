import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import 'data/music_models.dart';
import 'music_player_page.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';
import '../../core/api/peer_api_client.dart';
import '../device/data/repository/device_repository.dart';
import '../device/data/models/device_model.dart';

// ── 全局播放状态 ──────────────────────────────────────────
// 注意：不用 autoDispose，播放器需全局存活
final globalPlayerProvider = Provider<AudioPlayer>((ref) {
  final p = AudioPlayer();
  ref.onDispose(p.dispose);
  return p;
});
final playingIdProvider = StateProvider<int?>((ref) => null);

// ── 设备投送状态 —— (设备MAC, 歌曲ID) ────────────────────────
typedef _CastState = ({String mac, int songId});
final castingDeviceProvider = StateProvider<_CastState?>((_) => null);

// ═══════════════════════════════════════════════════════════
// 分类/歌单详情页
// ═══════════════════════════════════════════════════════════
class MusicCategoryPage extends ConsumerStatefulWidget {
  final MusicCategory? category;
  final Playlist?      playlist;
  const MusicCategoryPage({super.key, this.category, this.playlist})
      : assert(category != null || playlist != null);

  @override
  ConsumerState<MusicCategoryPage> createState() => _MusicCategoryPageState();
}

class _MusicCategoryPageState extends ConsumerState<MusicCategoryPage> {
  List<MusicItem> _songs = [];
  bool _loading = true;

  String get _title => widget.category?.name ?? widget.playlist?.name ?? '歌单';

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      setState(() { _songs = widget.category!.songs; _loading = false; });
    } else {
      _loadPlaylist();
    }
  }

  Future<void> _loadPlaylist() async {
    // 歌单详情（如后端支持歌单歌曲列表接口，此处调用）
    setState(() => _loading = false);
  }

  Duration get _totalDuration {
    final secs = _songs.fold<int>(0, (s, e) => s + (e.duration ?? 0));
    final h = secs ~/ 3600, m = (secs % 3600) ~/ 60, s = secs % 60;
    if (h > 0) return Duration(hours: h, minutes: m, seconds: s);
    return Duration(minutes: m, seconds: s);
  }

  String get _totalDurationText {
    final d = _totalDuration;
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  Future<void> _playAll() async {
    if (_songs.isEmpty) return;
    HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MusicPlayerPage(playlist: _songs, initialIndex: 0),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // 取第一个在线机器人设备的 MAC（productKey 以 'iPet' / 'robot' 等标识）
    final devices = ref.watch(deviceListProvider).devices;
    // robot 设备通过 productKey 判断（不区分大小写含 'pet' 或 mac 不为空的设备）
    final robotDevices = devices.where((d) => d.mac.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.playlist != null ? '歌单' : '分类',
            style: TextStyle(fontFamily: AppFonts.primary,
                fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          if (robotDevices.isNotEmpty)
            IconButton(
              tooltip: '投送到设备',
              icon: Icon(Icons.cast_rounded),
              color: AppColors.primary,
              onPressed: () => _showCastSheet(context, robotDevices),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(slivers: [
              // ── 歌单头部 ──
              SliverToBoxAdapter(child: _buildHeader()),
              // ── 全部播放 ──
              SliverToBoxAdapter(child: _buildPlayAllRow()),
              // ── 歌曲列表 ──
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _SongRow(
                    song: _songs[i], index: i + 1,
                    playlist: _songs,
                    robotDevices: robotDevices,
                    onAddToPlaylist: widget.playlist == null ? null
                        : () => _addToPlaylist(_songs[i]),
                  ),
                  childCount: _songs.length,
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 80)),
            ]),
      bottomSheet: const _MiniPlayer(),
    );
  }

  /// 投送整个歌单的第一首到设备
  void _showCastSheet(BuildContext context, List<DeviceModel> devices) {
    if (_songs.isEmpty) { PetToast.warning(context, '暂无歌曲'); return; }
    final song = _songs.first;
    if (devices.length == 1) {
      _castToDevice(context, devices.first.mac, song);
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _DevicePickerSheet(
          devices: devices,
          onPick: (mac) => _castToDevice(context, mac, song),
        ),
      );
    }
  }

  Future<void> _castToDevice(BuildContext ctx, String mac, MusicItem song) async {
    try {
      await ref.read(peerApiClientProvider).soundPlay(mac: mac, url: song.url);
      if (mounted) PetToast.success(ctx, '已投送「${song.name}」到设备 🎵');
    } catch (e) {
      if (mounted) PetToast.error(ctx, '投送失败：$e');
    }
  }

  Widget _buildHeader() {
    final coverUrl = _songs.isNotEmpty ? _songs.first.iconUrl : null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 封面
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: coverUrl != null
              ? CachedNetworkImage(imageUrl: coverUrl, width: 80, height: 80,
                  fit: BoxFit.cover, errorWidget: (_, __, ___) => _defaultCover())
              : _defaultCover(),
        ),
        SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title, style: TextStyle(fontFamily: AppFonts.primary,
              fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
          SizedBox(height: 6),
          Text(
            widget.category != null
                ? '${_songs.length} 首放松心情的精选曲目，专为毛孩子定制'
                : (widget.playlist != null ? '${widget.playlist!.songCount} 首' : ''),
            style: TextStyle(fontFamily: AppFonts.primary,
                fontSize: 12, color: AppColors.onSurfaceVariant),
            maxLines: 3,
          ),
        ])),
      ]),
    );
  }

  Widget _buildPlayAllRow() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(children: [
      GestureDetector(
        onTap: _playAll,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
        ),
      ),
      SizedBox(width: 12),
      Text('全部播放', style: TextStyle(fontFamily: AppFonts.primary,
          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
      SizedBox(width: 8),
      Text('共 ${_songs.length} 首  ${'  '}$_totalDurationText',
          style: TextStyle(fontFamily: AppFonts.primary,
              fontSize: 11, color: AppColors.onSurfaceVariant)),
    ]),
  );

  Widget _defaultCover() => Container(
    width: 80, height: 80,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Icon(Icons.music_note_rounded, color: Colors.white, size: 36),
  );

  Future<void> _addToPlaylist(MusicItem song) async {
    // TODO: 选择目标歌单 sheet
    PetToast.warning(context, '添加到歌单功能即将完善');
  }
}

// ── 歌曲行 ────────────────────────────────────────────────
class _SongRow extends ConsumerStatefulWidget {
  final MusicItem        song;
  final int              index;
  final List<MusicItem>  playlist;       // 全列表（用于传入播放器）
  final List<DeviceModel> robotDevices;  // 可投送的设备列表
  final VoidCallback?    onAddToPlaylist;
  const _SongRow({required this.song, required this.index,
      required this.playlist, this.robotDevices = const [], this.onAddToPlaylist});

  @override
  ConsumerState<_SongRow> createState() => _SongRowState();
}

class _SongRowState extends ConsumerState<_SongRow> {
  bool _casting = false;
  bool _stopping = false;

  /// 投送音频到设备
  Future<void> _cast(BuildContext context, String mac) async {
    setState(() => _casting = true);
    try {
      await ref.read(peerApiClientProvider).soundPlay(mac: mac, url: widget.song.url);
      // 记录投送状态
      ref.read(castingDeviceProvider.notifier).state =
          (mac: mac, songId: widget.song.id);
      if (mounted) PetToast.success(context, '已投送「${widget.song.name}」🎵');
    } catch (e) {
      if (mounted) PetToast.error(context, '投送失败');
    } finally {
      if (mounted) setState(() => _casting = false);
    }
  }

  /// 停止设备播放
  Future<void> _stop(BuildContext context, String mac) async {
    setState(() => _stopping = true);
    try {
      await ref.read(peerApiClientProvider).soundStop(mac: mac);
      ref.read(castingDeviceProvider.notifier).state = null;
      if (mounted) PetToast.success(context, '已停止播放');
    } catch (e) {
      if (mounted) PetToast.error(context, '停止失败');
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  void _onCastTap(BuildContext context) {
    if (widget.robotDevices.isEmpty) {
      PetToast.warning(context, '未绑定设备');
      return;
    }
    if (widget.robotDevices.length == 1) {
      _cast(context, widget.robotDevices.first.mac);
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _DevicePickerSheet(
          devices: widget.robotDevices,
          onPick: (mac) => _cast(context, mac),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playingId = ref.watch(playingIdProvider);
    final isPlaying = playingId == widget.song.id;
    final hasCast = widget.robotDevices.isNotEmpty;
    // 是否正在对设备播放此首歌
    final castState = ref.watch(castingDeviceProvider);
    final isCasting = castState != null && castState.songId == widget.song.id;
    final castingMac = isCasting ? castState!.mac : null;

    return Container(
      color: Colors.white,
      child: Column(children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            final startIdx = widget.playlist.indexOf(widget.song);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => MusicPlayerPage(
                playlist: widget.playlist,
                initialIndex: startIdx < 0 ? 0 : startIdx,
              ),
            ));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              // 序号/封面
              Stack(alignment: Alignment.center, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.song.iconUrl != null
                      ? CachedNetworkImage(imageUrl: widget.song.iconUrl!,
                          width: 44, height: 44, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _emptyThumb())
                      : _emptyThumb(),
                ),
                if (isPlaying)
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.pause_rounded, color: Colors.white, size: 20),
                  ),
              ]),
              SizedBox(width: 12),
              // 名称+艺人
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.song.name,
                    style: TextStyle(fontFamily: AppFonts.primary,
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: isPlaying ? AppColors.primary : AppColors.onSurface),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (widget.song.artist != null && widget.song.artist!.isNotEmpty)
                  Text(widget.song.artist!,
                      style: TextStyle(fontFamily: AppFonts.primary,
                          fontSize: 11, color: AppColors.onSurfaceVariant)),
              ])),
              // 投送/停止按鈕
              if (hasCast)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (isCasting) {
                      // 已在播放：点击停止
                      _stop(context, castingMac!);
                    } else {
                      _onCastTap(context);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: (_casting || _stopping)
                        ? SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2,
                                color: isCasting ? Colors.red.shade400 : AppColors.primary))
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: isCasting
                                ? Icon(Icons.stop_circle_rounded, size: 20,
                                    key: const ValueKey('stop'),
                                    color: Colors.red.shade400)
                                : Icon(Icons.cast_rounded, size: 18,
                                    key: const ValueKey('cast'),
                                    color: AppColors.primary.withOpacity(0.75)),
                          ),
                  ),
                ),
              // 播放/更多
              if (widget.onAddToPlaylist != null)
                IconButton(
                  icon: Icon(Icons.more_horiz_rounded, size: 20,
                      color: AppColors.onSurfaceVariant),
                  onPressed: widget.onAddToPlaylist, padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                )
              else
                Icon(
                  isPlaying ? Icons.equalizer_rounded : Icons.play_circle_outline_rounded,
                  size: 20,
                  color: isPlaying ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
            ]),
          ),
        ),
        Divider(height: 1, indent: 72),
      ]),
    );
  }

  Widget _emptyThumb() => Container(
    width: 44, height: 44,
    color: AppColors.primary.withOpacity(0.08),
    child: Icon(Icons.music_note_rounded, color: AppColors.primary, size: 20),
  );
}

// ── 设备选择底部弹窗 ──────────────────────────────────────
class _DevicePickerSheet extends StatelessWidget {
  final List<DeviceModel> devices;
  final void Function(String mac) onPick;
  const _DevicePickerSheet({required this.devices, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final navBar = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + navBar),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99))),
        const SizedBox(height: 16),
        Row(children: [
          Icon(Icons.cast_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text('选择投送设备', style: TextStyle(
              fontFamily: AppFonts.primary, fontSize: 15,
              fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        ]),
        const SizedBox(height: 12),
        ...devices.map((d) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: d.isOnline
                  ? AppColors.primary.withOpacity(0.10)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.pets_rounded,
                color: d.isOnline ? AppColors.primary : Colors.grey, size: 20),
          ),
          title: Text(d.displayName, style: TextStyle(
              fontFamily: AppFonts.primary, fontSize: 14,
              fontWeight: FontWeight.w600)),
          subtitle: Text(d.isOnline ? '在线' : '离线',
              style: TextStyle(fontSize: 12,
                  color: d.isOnline ? Colors.green : Colors.grey)),
          trailing: d.isOnline
              ? Icon(Icons.chevron_right_rounded, color: AppColors.primary)
              : null,
          onTap: d.isOnline ? () {
            Navigator.pop(context);
            onPick(d.mac);
          } : null,
        )),
      ]),
    );
  }
}


// ── 迷你播放器 ────────────────────────────────────────────
class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(playingIdProvider);
    if (id == null) return const SizedBox.shrink();
    final player = ref.read(globalPlayerProvider);
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12)],
      ),
      child: SafeArea(top: false,
        child: Row(children: [
          SizedBox(width: 16),
          Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Expanded(child: Text('正在播放',
              style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
          StreamBuilder<bool>(
            stream: player.playingStream,
            builder: (_, snap) {
              final playing = snap.data ?? false;
              return Row(children: [
                IconButton(
                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 26),
                  onPressed: () => playing ? player.pause() : player.play(),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: Icon(Icons.stop_rounded, color: Colors.white, size: 22),
                  onPressed: () {
                    player.stop();
                    ref.read(playingIdProvider.notifier).state = null;
                  },
                  padding: EdgeInsets.zero,
                ),
                SizedBox(width: 8),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}
