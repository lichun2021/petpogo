import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../../core/logging/app_log.dart';
import 'stream/stream_diagnostics.dart';

/// Android 录像使用项目已有的软件解码路径，避开部分设备的 MediaCodec 初始化故障。
/// 其他平台保留系统播放器。界面统一接住打开、异步播放、重试和释放时的错误。
abstract class RecordedVideoBackend {
  String get name;
  bool get softwareDecoding;
  Stream<String> get errors;
  Future<void>? get firstFrame;
  Future<void> open(String source);
  Widget buildVideo();
  Map<String, Object?> get stats;
  Future<void> pause();
  Future<void> dispose();
}

class SoftwareRecordedVideoBackend implements RecordedVideoBackend {
  final _player = mk.Player();
  late final _video = VideoController(_player,
      configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: false, hwdec: 'no'));
  @override
  String get name => 'media_kit';
  @override
  bool get softwareDecoding => true;
  @override
  Stream<String> get errors => _player.stream.error;
  @override
  Future<void> get firstFrame => _video.waitUntilFirstFrameRendered;
  @override
  Future<void> open(String source) => _player.open(mk.Media(source));
  @override
  Widget buildVideo() =>
      Video(controller: _video, controls: AdaptiveVideoControls);
  @override
  Map<String, Object?> get stats => {
        'positionMs': _player.state.position.inMilliseconds,
        'durationMs': _player.state.duration.inMilliseconds,
        'playing': _player.state.playing,
        'buffering': _player.state.buffering,
        'width': _player.state.width,
        'height': _player.state.height,
      };
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> dispose() => _player.dispose();
}

class SystemRecordedVideoBackend implements RecordedVideoBackend {
  final _errors = StreamController<String>.broadcast();
  VideoPlayerController? _player;
  String? _lastError;
  @override
  String get name => 'video_player';
  @override
  bool get softwareDecoding => false;
  @override
  Stream<String> get errors => _errors.stream;
  // 系统播放器 initialize 只确认就绪，不把它记作首帧已绘制。
  @override
  Future<void>? get firstFrame => null;
  @override
  Future<void> open(String source) async {
    final uri = Uri.parse(source);
    final player = uri.scheme == 'file'
        ? VideoPlayerController.file(File.fromUri(uri))
        : uri.hasScheme
            ? VideoPlayerController.networkUrl(uri)
            : VideoPlayerController.file(File(source));
    _player = player;
    player.addListener(() {
      final error = player.value.errorDescription;
      if (error != null && error != _lastError && !_errors.isClosed) {
        _lastError = error;
        _errors.add(error);
      }
    });
    await player.initialize();
    await player.play();
  }

  void _command(Future<void> Function() action) {
    unawaited(Future.sync(action).catchError((Object error) {
      if (!_errors.isClosed) _errors.add(error.toString());
    }));
  }

  @override
  Widget buildVideo() {
    final player = _player;
    if (player == null) return const SizedBox();
    return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: player,
        builder: (_, value, __) {
          if (!value.isInitialized) return const SizedBox();
          return Column(children: [
            Expanded(
                child: Center(
                    child: GestureDetector(
              onTap: () =>
                  _command(value.isPlaying ? player.pause : player.play),
              child: AspectRatio(
                  aspectRatio: value.aspectRatio, child: VideoPlayer(player)),
            ))),
            Slider(
              value: value.position.inMilliseconds
                  .toDouble()
                  .clamp(0, value.duration.inMilliseconds.toDouble()),
              max: value.duration.inMilliseconds > 0
                  ? value.duration.inMilliseconds.toDouble()
                  : 1,
              onChanged: value.duration.inMilliseconds <= 0
                  ? null
                  : (position) => _command(() =>
                      player.seekTo(Duration(milliseconds: position.round()))),
            ),
          ]);
        });
  }

  @override
  Map<String, Object?> get stats => {
        'positionMs': _player?.value.position.inMilliseconds,
        'durationMs': _player?.value.duration.inMilliseconds,
        'playing': _player?.value.isPlaying,
        'buffering': _player?.value.isBuffering,
        'width': _player?.value.size.width,
        'height': _player?.value.size.height,
      };
  @override
  Future<void> pause() async {
    await _player?.pause();
  }

  @override
  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } finally {
      await _errors.close();
    }
  }
}

class RecordedVideoPlayerPage extends StatefulWidget {
  final String source;
  final int? mediaId;
  final String? deviceMac;
  final RecordedVideoBackend Function()? backendFactory;
  const RecordedVideoPlayerPage(
      {super.key,
      required this.source,
      this.mediaId,
      this.deviceMac,
      this.backendFactory});
  @override
  State<RecordedVideoPlayerPage> createState() =>
      _RecordedVideoPlayerPageState();
}

class _RecordedVideoPlayerPageState extends State<RecordedVideoPlayerPage>
    with WidgetsBindingObserver {
  final _playbackId = const Uuid().v4().substring(0, 12);
  final _clock = Stopwatch()..start();
  RecordedVideoBackend? _backend;
  StreamSubscription<String>? _errorSubscription;
  Timer? _health, _openDeadline;
  Future<void> _closing = Future.value();
  int _generation = 0, _attempt = 0;
  bool _opening = true, _waitingForFrame = false;
  String? _error;

  void _log(String event, String stage, String message,
      {String level = 'info', Map<String, Object?> fields = const {}}) {
    AppLog.deviceStream('record.playback.$event', level: level, fields: {
      ...fields,
      'playbackId': _playbackId,
      'mediaId': widget.mediaId,
      'deviceMac': widget.deviceMac,
      'attempt': _attempt,
      'elapsedMs': _clock.elapsedMilliseconds,
      'stage': stage,
      'message': message,
    });
  }

  bool _current(int generation) => mounted && generation == _generation;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    final generation = ++_generation;
    _attempt++;
    _opening = true;
    _error = null;
    _waitingForFrame = false;
    if (mounted) setState(() {});
    try {
      await _closing;
      if (!_current(generation)) return;
      final backend = widget.backendFactory?.call() ??
          (Platform.isAndroid
              ? SoftwareRecordedVideoBackend()
              : SystemRecordedVideoBackend());
      _backend = backend;
      final uri = Uri.tryParse(widget.source);
      _log('open.begin', '录像播放器初始化', '开始打开录像', fields: {
        'backend': backend.name,
        'softwareDecoding': backend.softwareDecoding,
        'mediaSource': uri?.hasScheme == true && uri?.scheme != 'file'
            ? 'network'
            : 'file',
        'mediaHost': uri?.host,
        'timeoutMs': 30000,
      });
      _errorSubscription = backend.errors.listen((error) {
        _fail(generation, StateError(error), '录像播放');
      }, onError: (Object error) {
        _fail(generation, error, '播放器事件流');
      });
      final firstFrame = backend.firstFrame;
      _waitingForFrame = firstFrame != null;
      if (firstFrame != null) {
        unawaited(firstFrame.then((_) {
          if (!_current(generation) || _error != null) return;
          setState(() => _waitingForFrame = false);
          _log('first_frame', '录像首帧绘制', '录像首帧已进入视频输出', fields: backend.stats);
        }, onError: (Object error) {
          _fail(generation, error, '录像视频输出');
        }));
      }
      setState(() {}); // 视频输出需挂载后才会创建 Surface / Texture。
      final deadline = Timer(const Duration(seconds: 30), () {
        _fail(generation, TimeoutException('录像打开超过 30 秒'), '录像播放器初始化');
      });
      _openDeadline = deadline;
      await backend.open(widget.source);
      deadline.cancel();
      if (!_current(generation) || _error != null) return;
      setState(() => _opening = false);
      _log('open.ok', '录像打开', '播放器已接受录像并开始播放', fields: backend.stats);
      _health = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_current(generation)) return;
        _log('health', '录像播放巡检', _waitingForFrame ? '仍在等待录像首帧输出' : '录像播放状态',
            fields: {
              ...backend.stats,
              'diagnosis': _waitingForFrame
                  ? 'waiting_for_playback_frame'
                  : 'playback_ready'
            });
      });
    } catch (error) {
      _fail(generation, error, '录像播放器初始化');
    }
  }

  void _fail(int generation, Object error, String stage) {
    if (!_current(generation) || _error != null) return;
    _log('failed', stage, '录像播放失败，显示重试入口并释放播放器', level: 'warning', fields: {
      ...StreamDiagnostics.safeError(error),
      if (_backend != null) ..._backend!.stats
    });
    setState(() {
      _error = '视频暂时无法播放，请重试';
      _opening = false;
      _waitingForFrame = false;
    });
    _release();
  }

  void _release() {
    _openDeadline?.cancel();
    _openDeadline = null;
    _health?.cancel();
    _health = null;
    final subscription = _errorSubscription;
    final backend = _backend;
    _errorSubscription = null;
    _backend = null;
    if (backend != null) {
      _log('dispose.begin', '播放器清理', '开始取消事件并释放录像播放器',
          fields: {'backend': backend.name});
    }
    _closing = _closing.then((_) async {
      // 先取消监听，再并行等待订阅清理和原生释放，避免事件源等播放器关闭。
      final cancelling =
          Future.sync(() => subscription?.cancel()).catchError((Object error) {
        _log('events.close.failed', '播放器清理', '取消播放器事件监听失败',
            level: 'warning', fields: StreamDiagnostics.safeError(error));
      });
      final disposing = Future.sync(() async {
        if (backend == null) return;
        _log('dispose.native.begin', '播放器清理', '释放原生录像播放器');
        try {
          await backend.dispose();
          _log('dispose.ok', '播放器清理', '录像播放器已释放');
        } catch (error) {
          _log('dispose.failed', '播放器清理', '释放录像播放器失败',
              level: 'warning', fields: StreamDiagnostics.safeError(error));
        }
      });
      await Future.wait([cancelling, disposing]);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _backend != null) {
      final backend = _backend!;
      _log('pause.background', '录像播放', '应用进入后台，暂停录像播放');
      unawaited(Future.sync(backend.pause).catchError((Object error) {
        _log('pause.failed', '录像播放', '暂停播放失败',
            level: 'warning', fields: StreamDiagnostics.safeError(error));
      }));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: _error != null
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline,
                    color: Colors.white70, size: 40),
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: () => unawaited(_open()),
                    child: const Text('重试')),
              ]))
            : Stack(fit: StackFit.expand, children: [
                if (_backend != null) _backend!.buildVideo(),
                if (_opening || _waitingForFrame)
                  const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
              ]),
      );
}
