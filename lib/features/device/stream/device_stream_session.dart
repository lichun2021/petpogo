import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'device_stream_api.dart';
import 'device_audio_io.dart';
import 'local_stream_recorder.dart';
import 'stream_protocol.dart';
import 'stream_diagnostics.dart';
import '../../../shared/utils/error_presenter.dart';

class DeviceStreamSession extends ChangeNotifier {
  final String mac;
  final DeviceStreamApi api;
  final DeviceAudioIo audio;
  final LocalStreamRecorder recorder;
  final StreamDiagnostics diagnostics;
  final Future<WebSocket> Function(Uri) connect;
  DeviceStreamSession(
      {required this.mac,
      required this.api,
      DeviceAudioIo? audio,
      LocalStreamRecorder? recorder,
      StreamDiagnostics? diagnostics,
      Future<WebSocket> Function(Uri)? connect})
      : audio = audio ?? DeviceAudioIo(),
        recorder = recorder ?? LocalStreamRecorder(),
        diagnostics = diagnostics ?? StreamDiagnostics(mac),
        connect = connect ?? ((uri) => WebSocket.connect(uri.toString())) {
    this.audio.onPlaybackEvent = (event, error) {
      if (_disposed) return;
      if (error == null) {
        this.diagnostics.log(event, 'PCM 播放', '第一包 PCM 已交给原生播放通道');
      } else {
        this.diagnostics.failure(event, 'PCM 播放', '原生 PCM 播放失败，视频继续', error);
      }
    };
  }
  final latestJpeg = ValueNotifier<Uint8List?>(null);
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry, _stats;
  final _clock = Stopwatch()..start();
  bool connected = false, loading = false, talking = false, talkBusy = false;
  bool _wanted = false, _disposed = false, _probeInFlight = false;
  int _generation = 0, _attempt = 0, _bytes = 0, _ticks = 0, _talkPackets = 0;
  DateTime? _lastVideo, _connectedAt;
  bool get waitingTooLong =>
      connected &&
      !hasVideo &&
      _connectedAt != null &&
      DateTime.now().difference(_connectedAt!).inSeconds >= 15;
  String? error, audioError;
  double kbps = 0, volume = 1;
  Future<void>? _closing;
  bool get hasVideo => latestJpeg.value != null;
  bool get frozen =>
      connected &&
      _lastVideo != null &&
      DateTime.now().difference(_lastVideo!).inSeconds > 5;
  String get status => loading
      ? '连接中...'
      : !connected
          ? '连接已断开'
          : !hasVideo
              ? '等待设备画面...'
              : frozen
                  ? '等待新画面...'
                  : '已连接';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start({String reason = 'page_open_or_retry'}) async {
    if (_disposed) return;
    await _closing;
    if (_disposed || loading || connected) return;
    _wanted = true;
    _retry?.cancel();
    final generation = ++_generation;
    diagnostics.begin(reason);
    final attempt = diagnostics.attempt;
    loading = true;
    error = null;
    _notify();
    WebSocket? opened;
    var stage = '启动推流 HTTP';
    try {
      final url = await api.start(mac, diagnostics: diagnostics);
      if (!_valid(generation)) {
        diagnostics.log('session.superseded', stage, '启动响应迟到，当前页面已退出或切换，忽略本次连接',
            forAttempt: attempt);
        return;
      }
      stage = 'WebSocket 握手';
      final handshake = Stopwatch()..start();
      diagnostics.log('ws.connect.begin', stage, '开始连接媒体服务器', fields: {
        'wsUrl': url.toString(),
        'hasQuery': url.hasQuery,
        'timeoutMs': 10000,
      });
      final opening = connect(url);
      var timedOut = false;
      unawaited(opening.then((socket) async {
        if (timedOut || !_valid(generation)) {
          await socket.close();
          diagnostics.log('ws.late_connection_closed', '连接清理', '握手迟到，已关闭失效连接',
              forAttempt: attempt);
        }
      }, onError: (Object _) {}));
      opened =
          await opening.timeout(const Duration(seconds: 10), onTimeout: () {
        timedOut = true;
        throw TimeoutException('WebSocket 握手超过 10 秒');
      });
      if (!_valid(generation)) {
        await opened.close();
        return;
      }
      opened.pingInterval = const Duration(seconds: 15);
      diagnostics
          .log('ws.connect.ok', stage, 'WebSocket 握手成功；开始等待设备媒体帧', fields: {
        'durationMs': handshake.elapsedMilliseconds,
        'pingIntervalMs': 15000,
      });
      diagnostics.websocketConnected();
      stage = 'WebSocket 收流';
      _socket = opened;
      connected = true;
      loading = false;
      _attempt = 0;
      _lastVideo = null;
      _connectedAt = DateTime.now();
      _ticks = _bytes = 0;
      latestJpeg.value = null;
      final activeSocket = opened;
      _subscription = opened.listen((message) {
        if (!_valid(generation)) return;
        if (message is! List<int>) {
          diagnostics.receivedMessage(
              binary: false, bytes: message is String ? message.length : 0);
          return;
        }
        _bytes += message.length;
        diagnostics.receivedMessage(binary: true, bytes: message.length);
        final inspected = DeviceStreamFrame.inspect(message);
        final frame = inspected.frame;
        if (frame == null) {
          diagnostics.rejected(inspected);
          return;
        }
        if (frame.type == 1) {
          diagnostics.videoReceived(frame);
          final first = !hasVideo;
          latestJpeg.value = frame.payload;
          _lastVideo = DateTime.now();
          recorder.addVideo(frame.payload);
          if (first) _notify();
        } else {
          diagnostics.audioReceived(frame);
          audio.play(frame.payload);
          recorder.addAudio(frame.payload);
        }
      }, onError: (Object failure) {
        if (_valid(generation)) {
          diagnostics.failure('ws.error', 'WebSocket 收流', '媒体连接发生异常', failure);
        }
        _lost(generation);
      }, onDone: () {
        if (_valid(generation)) {
          diagnostics.log('ws.closed', 'WebSocket 收流', '媒体连接被关闭',
              level: 'warning',
              fields: {
                'closeCode': activeSocket.closeCode,
                'closeReason': activeSocket.closeReason,
              });
        }
        _lost(generation);
      });
      _stats?.cancel();
      _stats = Timer.periodic(const Duration(seconds: 1), (_) {
        kbps = _bytes / 1024;
        _bytes = 0;
        _ticks++;
        if (_ticks % 5 == 0) {
          diagnostics.health(connected,
              playingAudioChunks: audio.playedChunks,
              talkPackets: _talkPackets);
        }
        if (_ticks % 15 == 0 && (!hasVideo || frozen)) unawaited(probeStatus());
        _notify();
      });
      _notify();
      final audioWatch = Stopwatch()..start();
      diagnostics.log(
          'audio.open.begin', 'PCM 播放初始化', '初始化原生 16kHz 单声道 PCM 播放通道');
      try {
        await audio.open();
        if (!_valid(generation)) {
          await audio.close();
          return;
        }
        await audio.volume(volume);
        audioError = null;
        diagnostics.log('audio.open.ok', 'PCM 播放初始化', '原生播放通道就绪，等待设备 PCM',
            fields: {'durationMs': audioWatch.elapsedMilliseconds});
      } catch (failure) {
        if (_valid(generation)) {
          audioError = '声音播放不可用，画面仍可观看';
          diagnostics.failure(
              'audio.open.failed', 'PCM 播放初始化', audioError!, failure,
              fields: {'durationMs': audioWatch.elapsedMilliseconds});
        }
      }
      _notify();
    } catch (failure) {
      if (!_valid(generation)) {
        await opened?.close();
        return;
      }
      await _subscription?.cancel();
      await opened?.close();
      _socket = null;
      _stats?.cancel();
      loading = false;
      connected = false;
      diagnostics.failure(
          'session.start.failed', stage, '观看启动失败，日志 stage 表示失败环节', failure);
      error = ErrorPresenter.message(failure, fallback: '连接失败，请检查设备和网络后重试');
      _notify();
    }
  }

  Future<void> probeStatus() async {
    if (_disposed || !connected || _probeInFlight) return;
    final generation = _generation;
    _probeInFlight = true;
    try {
      final result = await api.status(mac, diagnostics: diagnostics);
      if (!_valid(generation)) return;
      diagnostics.serverStatus(result.deviceConnected, result.appViewerCount);
      diagnostics.health(connected,
          playingAudioChunks: audio.playedChunks, talkPackets: _talkPackets);
    } catch (failure) {
      if (_valid(generation)) {
        diagnostics.failure(
            'status.failed', '媒体状态', '状态查询失败，不终止当前观看连接', failure);
      }
    } finally {
      _probeInFlight = false;
    }
  }

  bool _valid(int generation) =>
      !_disposed && _wanted && generation == _generation;
  void _lost(int generation) {
    if (!_valid(generation) || !connected) return;
    connected = false;
    talking = false;
    error = '连接已断开，正在重连';
    _stats?.cancel();
    unawaited(audio.close().catchError((_) {}));
    _notify();
    if (_attempt >= 5) {
      error = '连接已断开，请点击重试';
      diagnostics.log('reconnect.exhausted', '自动重连', '自动重连次数已用完，等待手动重试',
          level: 'warning');
      _notify();
      return;
    }
    final delay = 1 << _attempt++;
    diagnostics.log('reconnect.scheduled', '自动重连', '连接断开，已安排重连',
        fields: {'reconnectDelayMs': delay * 1000});
    _retry = Timer(Duration(seconds: delay), () async {
      await _subscription?.cancel();
      await _socket?.close();
      _socket = null;
      if (_valid(generation)) await start(reason: 'automatic_reconnect');
    });
  }

  Future<void> toggleTalk() async {
    if (!connected || talkBusy || _disposed) return;
    talkBusy = true;
    _notify();
    final generation = _generation;
    final watch = Stopwatch()..start();
    diagnostics.log(talking ? 'talk.stop.begin' : 'talk.start.begin', '手机麦克风',
        talking ? '停止对讲并清空待发语音' : '检查麦克风权限并启动 PCM 采集');
    try {
      if (talking) {
        await audio.stopTalking();
        talking = false;
        diagnostics.log('talk.stop.ok', '手机麦克风', '对讲采集已停止',
            fields: {'talkPackets': _talkPackets});
      } else {
        _talkPackets = 0;
        final granted = await audio.startTalking((pcm) {
          if (_valid(generation) && connected) {
            _socket?.add(buildTalkFrame(_clock.elapsedMilliseconds, pcm));
            if (++_talkPackets == 1) {
              diagnostics.log('talk.first_packet.sent', '对讲发送',
                  '第一包 20ms PCM 已交给 WebSocket，不代表设备已播放',
                  fields: {'bytes': pcm.length, 'talkPackets': _talkPackets});
            }
          }
        }, (failure) {
          talking = false;
          audioError = '麦克风已停止，请重新开启';
          diagnostics.failure(
              'talk.capture.failed', '手机麦克风', audioError!, failure);
          _notify();
        });
        if (!_valid(generation)) {
          await audio.stopTalking();
          return;
        }
        talking = granted;
        audioError = granted ? null : '请允许麦克风权限后开启对讲';
        diagnostics.log(granted ? 'talk.start.ok' : 'talk.permission.denied',
            '手机麦克风', granted ? '麦克风已启动，等待采集音频后按 20ms 发送' : audioError!,
            level: granted ? 'info' : 'warning',
            fields: {'durationMs': watch.elapsedMilliseconds});
      }
    } catch (failure) {
      talking = false;
      audioError = '对讲启动失败，请重试';
      diagnostics.failure('talk.start.failed', '手机麦克风', audioError!, failure);
    } finally {
      talkBusy = false;
      _notify();
    }
  }

  Future<void> setVolume(double value) async {
    volume = value.clamp(0, 1);
    _notify();
    try {
      await audio.volume(volume);
    } catch (failure) {
      diagnostics.failure(
          'audio.volume.failed', 'PCM 播放', '设置本地播放音量失败', failure);
    }
  }

  Future<void> stop({String reason = 'page_pause_or_leave'}) {
    diagnostics.log('session.stop', '退出观看', '开始停止麦克风和本机媒体连接',
        fields: {'reason': reason});
    _wanted = false;
    _generation++;
    _retry?.cancel();
    _stats?.cancel();
    connected = false;
    loading = false;
    talking = false;
    _notify();
    return _closing ??= _close().whenComplete(() => _closing = null);
  }

  Future<void> _close() async {
    final subscription = _subscription;
    final socket = _socket;
    _subscription = null;
    _socket = null;
    try {
      await audio.close();
    } catch (failure) {
      diagnostics.failure('audio.close.failed', '退出观看', '释放原生音频失败', failure);
    }
    await subscription?.cancel();
    if (socket != null) {
      final watch = Stopwatch()..start();
      diagnostics.log('ws.close.begin', '退出观看', '关闭本机 WebSocket，随后通知后台停止观看');
      try {
        await socket.close().timeout(const Duration(seconds: 2));
        diagnostics.log('ws.close.ok', '退出观看', '本机 WebSocket 已关闭', fields: {
          'durationMs': watch.elapsedMilliseconds,
          'closeCode': socket.closeCode,
          'closeReason': socket.closeReason,
        });
      } catch (failure) {
        diagnostics.failure(
            'ws.close.failed', '退出观看', '关闭连接超时或失败，继续清理', failure);
      }
    }
    try {
      await api.stop(mac, diagnostics: diagnostics);
    } catch (failure) {
      diagnostics.failure(
          'stop.failed', '停止推流 HTTP', '停止观看通知失败，本机连接已经关闭', failure);
    }
  }

  Future<void> release() async {
    if (_disposed) return;
    _disposed = true;
    await stop(reason: 'page_dispose');
    if (recorder.active) await recorder.cancel();
    await audio.dispose();
    latestJpeg.dispose();
    super.dispose();
  }
}

final deviceStreamFactoryProvider =
    Provider<DeviceStreamSession Function(String)>((ref) {
  final api = ref.watch(deviceStreamApiProvider);
  return (mac) => DeviceStreamSession(mac: mac, api: api);
});
