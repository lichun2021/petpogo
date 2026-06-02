import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import 'data/music_models.dart';
import 'music_category_page.dart'; // globalPlayerProvider / playingIdProvider

// ═══════════════════════════════════════════════════════════
// 全屏播放器页
// ═══════════════════════════════════════════════════════════
class MusicPlayerPage extends ConsumerStatefulWidget {
  final List<MusicItem> playlist;
  final int             initialIndex;

  const MusicPlayerPage({
    super.key,
    required this.playlist,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends ConsumerState<MusicPlayerPage>
    with TickerProviderStateMixin {
  late int _index;
  late final AnimationController _rotateCtrl;
  late final AnimationController _vizCtrl;

  // 音频柱状图随机高度（8根）
  static const _barCount = 8;
  final _bars = List.generate(_barCount, (_) => 0.3);
  final _rng  = math.Random();

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;

    // CD 旋转动画（60秒转一圈）
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );

    // 柱状图刷新（每 150ms）
    _vizCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..addListener(_updateBars)
      ..repeat();

    _playIndex(_index, autoPlay: false);
  }

  void _updateBars() {
    if (!mounted) return;
    final player = ref.read(globalPlayerProvider);
    final isPlaying = player.playing;
    setState(() {
      for (var i = 0; i < _barCount; i++) {
        _bars[i] = isPlaying
            ? 0.15 + _rng.nextDouble() * 0.85
            : _bars[i] * 0.85; // 暂停时平缓下降
      }
    });
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _vizCtrl.dispose();
    super.dispose();
  }

  MusicItem get _current => widget.playlist[_index];
  bool get _hasPrev => _index > 0;
  bool get _hasNext => _index < widget.playlist.length - 1;

  Future<void> _playIndex(int idx, {bool autoPlay = true}) async {
    setState(() => _index = idx);
    final player = ref.read(globalPlayerProvider);
    ref.read(playingIdProvider.notifier).state = widget.playlist[idx].id;
    try {
      await player.setUrl(widget.playlist[idx].url);
      if (autoPlay) {
        await player.play();
        _rotateCtrl.repeat();
      }
    } catch (e) {
      debugPrint('[Player] setUrl error: $e');
    }
  }

  Future<void> _togglePlay() async {
    final player = ref.read(globalPlayerProvider);
    if (player.playing) {
      await player.pause();
      _rotateCtrl.stop();
    } else {
      await player.play();
      _rotateCtrl.repeat();
    }
  }

  Future<void> _seek(double ratio) async {
    final player = ref.read(globalPlayerProvider);
    final dur = player.duration;
    if (dur != null) {
      await player.seek(Duration(
          milliseconds: (dur.inMilliseconds * ratio).round()));
    }
  }

  Future<void> _replay() async {
    final player = ref.read(globalPlayerProvider);
    await player.seek(Duration.zero);
    await player.play();
    _rotateCtrl.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final player  = ref.watch(globalPlayerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── 模糊背景（封面颜色溢出）
        if (_current.iconUrl != null)
          Positioned.fill(
            child: Opacity(
              opacity: 0.25,
              child: CachedNetworkImage(
                imageUrl: _current.iconUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),
        // 遮罩
        Positioned.fill(child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Color(0xEE000000)],
            ),
          ),
        )),

        SafeArea(child: Column(children: [
          // ── AppBar ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Text(_current.name,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const Spacer(),
              const SizedBox(width: 48), // 平衡左侧
            ]),
          ),

          const Spacer(),

          // ── CD 旋转封面 ──────────────────────────────
          AnimatedBuilder(
            animation: _rotateCtrl,
            builder: (_, child) => Transform.rotate(
              angle: _rotateCtrl.value * 2 * math.pi,
              child: child,
            ),
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 40, spreadRadius: 10,
                  )
                ],
              ),
              child: ClipOval(
                child: _current.iconUrl != null
                    ? CachedNetworkImage(
                        imageUrl: _current.iconUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _defaultDisc(),
                      )
                    : _defaultDisc(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── 音频柱状图 ──────────────────────────────
          SizedBox(height: 48, child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_barCount, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 5, margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 8 + _bars[i] * 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.6 + _bars[i] * 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          )),

          const Spacer(),

          // ── 歌曲信息 ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(children: [
              Text(_current.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (_current.artist != null && _current.artist!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(_current.artist!,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14, color: Colors.white.withOpacity(0.6))),
              ],
            ]),
          ),

          const SizedBox(height: 32),

          // ── 进度条 ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (_, posSnap) {
                return StreamBuilder<Duration?>(
                  stream: player.durationStream,
                  builder: (_, durSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    final dur = durSnap.data ?? Duration.zero;
                    final ratio = dur.inMilliseconds > 0
                        ? pos.inMilliseconds / dur.inMilliseconds
                        : 0.0;
                    return Column(children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: SliderComponentShape.noOverlay,
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: ratio.clamp(0.0, 1.0),
                          onChanged: (v) => _seek(v),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(pos), style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                              color: Colors.white.withOpacity(0.5))),
                          Text(_fmt(dur), style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                              color: Colors.white.withOpacity(0.5))),
                        ],
                      ),
                    ]);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // ── 控制按钮 ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 重播
                _CtrlBtn(
                  icon: Icons.replay_rounded,
                  onTap: _replay,
                  size: 26,
                ),
                // 上一首
                _CtrlBtn(
                  icon: Icons.skip_previous_rounded,
                  onTap: _hasPrev ? () => _playIndex(_index - 1) : null,
                  size: 36,
                ),
                // 播放/暂停（大按钮）
                StreamBuilder<bool>(
                  stream: player.playingStream,
                  builder: (_, snap) {
                    final playing = snap.data ?? false;
                    // 同步旋转状态
                    if (playing && !_rotateCtrl.isAnimating) {
                      _rotateCtrl.repeat();
                    } else if (!playing && _rotateCtrl.isAnimating) {
                      _rotateCtrl.stop();
                    }
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _togglePlay();
                      },
                      child: Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: 20, spreadRadius: 4)],
                        ),
                        child: Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white, size: 36,
                        ),
                      ),
                    );
                  },
                ),
                // 下一首
                _CtrlBtn(
                  icon: Icons.skip_next_rounded,
                  onTap: _hasNext ? () => _playIndex(_index + 1) : null,
                  size: 36,
                ),
                // 停止
                _CtrlBtn(
                  icon: Icons.stop_rounded,
                  onTap: () {
                    player.stop();
                    _rotateCtrl.stop();
                    ref.read(playingIdProvider.notifier).state = null;
                  },
                  size: 26,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── 播放列表预览（当前歌曲名）─────────────────
          if (widget.playlist.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${_index + 1} / ${widget.playlist.length}',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12, color: Colors.white.withOpacity(0.4)),
              ),
            ),
        ])),
      ]),
    );
  }

  Widget _defaultDisc() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 80),
  );

  String _fmt(Duration d) {
    final m = d.inMinutes % 60, s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ── 控制按钮 ────────────────────────────────────────────────
class _CtrlBtn extends StatelessWidget {
  final IconData   icon;
  final VoidCallback? onTap;
  final double     size;

  const _CtrlBtn({required this.icon, this.onTap, this.size = 28});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap != null ? () {
      HapticFeedback.selectionClick();
      onTap!();
    } : null,
    child: Icon(icon,
        color: onTap != null
            ? Colors.white.withOpacity(0.9)
            : Colors.white.withOpacity(0.25),
        size: size),
  );
}
