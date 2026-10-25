import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:petpogo_device_media/petpogo_device_media.dart';
import 'package:record/record.dart';
import 'stream_diagnostics.dart';
import 'stream_protocol.dart';

class DeviceTalkFailure implements Exception {
  final String phase;
  final Object cause;
  const DeviceTalkFailure(this.phase, this.cause);
  @override
  String toString() => '$phase: $cause';
}

class DeviceAudioIo {
  final DeviceMedia media;
  final AudioRecorder recorder;
  DeviceAudioIo({DeviceMedia? media, AudioRecorder? recorder})
      : media = media ?? DeviceMedia(),
        recorder = recorder ?? AudioRecorder();
  void Function(String event, Object? error)? onPlaybackEvent;
  StreamDiagnostics? diagnostics;
  int playedChunks = 0;
  int _playbackFailures = 0;
  StreamSubscription<Uint8List>? _mic;
  StreamSubscription<RecordState>? _recordState;
  Timer? _talkTimer, _talkHealthTimer;
  Future<void>? _talkClosing;
  final _talkWatch = Stopwatch();
  bool _nativeRecording = false;
  int _micBatches = 0, _micBytes = 0, _pcmChunks = 0, _droppedChunks = 0;
  int _sentPackets = 0, _sentBytes = 0, _emptyBatches = 0;
  int _pcmPeak = 0, _nonZeroSamples = 0;
  int? _lastCaptureMs, _lastSendMs;
  final _chunks = Queue<Uint8List>();
  Uint8List _partial = Uint8List(0);
  int _generation = 0;
  bool _open = false;
  bool _feeding = false;
  Uint8List? _pendingPlayback;
  bool get capturing => _mic != null && _talkTimer != null;

  Future<void> open() async {
    await media.openAudio();
    playedChunks = 0;
    _playbackFailures = 0;
    _open = true;
  }

  // 只保留约 300ms 的原生播放缓冲；Dart/平台忙时不累积无限调用。
  void play(Uint8List pcm) {
    if (!_open) return;
    _pendingPlayback = pcm;
    if (_feeding) return;
    _feeding = true;
    () async {
      try {
        while (_open && _pendingPlayback != null) {
          final next = _pendingPlayback!;
          _pendingPlayback = null;
          await media.feedAudio(next);
          if (++playedChunks == 1) {
            onPlaybackEvent?.call('audio.first_chunk.delivered', null);
          }
        }
      } catch (error) {
        if (++_playbackFailures <= 3) {
          onPlaybackEvent?.call('audio.feed.failed', error);
        }
        // 播放失败不终止视频或对讲。
      } finally {
        _feeding = false;
      }
    }();
  }

  Future<void> volume(double value) => media.setVolume(value);

  Future<bool> startTalking(
      void Function(Uint8List) send, void Function(Object) onError) async {
    await _talkClosing;
    final generation = ++_generation;
    _micBatches = _micBytes = _pcmChunks = _droppedChunks = 0;
    _sentPackets = _sentBytes = _emptyBatches = 0;
    _pcmPeak = _nonZeroSamples = 0;
    _lastCaptureMs = _lastSendMs = null;
    _talkWatch
      ..reset()
      ..start();
    var stage = '麦克风权限';
    try {
      diagnostics?.log('talk.permission.check', stage, '检查当前麦克风权限，不弹出授权框');
      var granted = await recorder.hasPermission(request: false);
      if (generation != _generation) return false;
      diagnostics?.log('talk.permission.result', stage, '当前麦克风权限检查完成',
          fields: {'permissionGranted': granted, 'permissionRequested': false});
      if (!granted) {
        diagnostics?.log('talk.permission.request', stage, '请求麦克风权限，等待系统授权结果');
        granted = await recorder.hasPermission();
        if (generation != _generation) return false;
        diagnostics?.log('talk.permission.result', stage, '麦克风授权请求完成',
            level: granted ? 'info' : 'warning',
            fields: {
              'permissionGranted': granted,
              'permissionRequested': true
            });
      }
      if (!granted) {
        _talkWatch.stop();
        return false;
      }
      if (Platform.isIOS) {
        stage = 'iOS 音频会话';
        diagnostics?.log('talk.audio_session.begin', stage, '复用播放与录音的系统音频会话');
        await recorder.ios?.manageAudioSession(false);
        if (generation != _generation) return false;
        diagnostics?.log('talk.audio_session.ok', stage, '录音插件音频会话管理已配置');
      }
      stage = '原生麦克风初始化';
      diagnostics?.log('talk.capture.start.request', stage,
          '调用 record.startStream，等待原生 PCM 采集通道',
          fields: {
            'encoder': 'pcm16bits',
            'sampleRate': devicePcmRate,
            'channels': 1,
            'bitsPerSample': 16,
            'byteOrder': 'little_endian',
            'audioSource':
                Platform.isAndroid ? 'voiceCommunication' : 'system_default',
            'echoCancel': true,
            'noiseSuppress': true,
            'chunkBytes': devicePcmChunkBytes,
            'packetIntervalMs': 20,
            'maxQueuedChunks': 10,
            'nativeMethod': 'record.startStream',
          });
      _nativeRecording = true;
      final nativeWatch = Stopwatch()..start();
      final input = await recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: devicePcmRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceCommunication),
      ));
      if (generation != _generation) {
        await recorder.stop();
        _nativeRecording = false;
        diagnostics?.log(
            'talk.capture.start.cancelled', stage, '初始化完成时会话已结束，已释放麦克风');
        return false;
      }
      diagnostics?.log('talk.capture.start.ok', stage, '原生采集通道已创建，等待第一批 PCM',
          fields: {'durationMs': nativeWatch.elapsedMilliseconds});
      _mic = input.listen((bytes) {
        if (generation != _generation) return;
        if (bytes.isEmpty) {
          if (++_emptyBatches <= 3) {
            diagnostics?.log('talk.capture.empty', 'PCM 采集', '原生返回空音频批次',
                level: 'warning');
          }
          return;
        }
        _micBatches++;
        _micBytes += bytes.length;
        _lastCaptureMs = _talkWatch.elapsedMilliseconds;
        if (_micBatches == 1) {
          diagnostics?.log('talk.capture.first_batch', 'PCM 采集',
              '收到第一批麦克风 PCM，开始拼接 20ms 音频包',
              fields: {'bytes': bytes.length, 'durationMs': _lastCaptureMs});
        }
        final data = Uint8List(_partial.length + bytes.length)
          ..setAll(0, _partial)
          ..setAll(_partial.length, bytes);
        final beforeChunks = _pcmChunks;
        var offset = 0;
        while (offset + devicePcmChunkBytes <= data.length) {
          final chunk = Uint8List.fromList(
              data.sublist(offset, offset + devicePcmChunkBytes));
          final samples = ByteData.sublistView(chunk);
          for (var i = 0; i < chunk.length; i += 2) {
            final value = samples.getInt16(i, Endian.little).abs();
            if (value > _pcmPeak) _pcmPeak = value;
            if (value != 0) _nonZeroSamples++;
          }
          _chunks.add(chunk);
          _pcmChunks++;
          offset += devicePcmChunkBytes;
        }
        _partial = Uint8List.fromList(data.sublist(offset));
        if (beforeChunks == 0 && _pcmChunks > 0) {
          diagnostics?.log('talk.packet.first_ready', 'PCM 分包',
              '第一包 640 字节 PCM 已准备好，等待 20ms 发送节拍',
              fields: {
                'chunkBytes': devicePcmChunkBytes,
                'pcmChunks': _pcmChunks,
                'partialBytes': _partial.length,
                'packetIntervalMs': 20,
              });
        }
        final before = _droppedChunks;
        while (_chunks.length > 10) {
          _chunks.removeFirst();
          _droppedChunks++;
        }
        if (before == 0 && _droppedChunks > 0) {
          diagnostics?.log(
              'talk.queue.dropped', 'PCM 分包', '待发语音超过 200ms，丢弃旧包以控制对讲延迟',
              level: 'warning', fields: _talkFields());
        }
      }, onError: (Object error, StackTrace stack) {
        _talkFailed(generation, 'capture', error, stack, onError);
      }, onDone: () {
        _talkFailed(generation, 'capture', StateError('原生麦克风数据流意外结束'),
            StackTrace.current, onError);
      });
      // 状态监控仅用于诊断，监控失败不影响已成功启动的录音。
      try {
        _recordState = recorder.onStateChanged().listen((state) {
          if (generation == _generation) {
            diagnostics?.log('talk.recorder.state', '原生录音状态', '录音插件状态变化',
                fields: {'recorderState': state.name});
          }
        }, onError: (Object error, StackTrace stack) {
          if (generation == _generation) {
            diagnostics?.failure(
                'talk.recorder.state.failed', '原生录音状态', '读取录音状态失败，继续采集', error,
                stackTrace: stack);
          }
        });
      } catch (error, stack) {
        diagnostics?.failure(
            'talk.recorder.state.failed', '原生录音状态', '无法监听录音状态，继续采集', error,
            stackTrace: stack);
      }
      _talkTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
        if (generation != _generation || _chunks.isEmpty) return;
        final pcm = _chunks.removeFirst();
        try {
          send(pcm);
          _sentPackets++;
          _sentBytes += pcm.length;
          _lastSendMs = _talkWatch.elapsedMilliseconds;
        } catch (error, stack) {
          _talkFailed(generation, 'send', error, stack, onError);
        }
      });
      _talkHealthTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (generation == _generation) _talkHealth();
      });
      return true;
    } catch (error, stack) {
      diagnostics?.failure(
          'talk.capture.start.failed', stage, '对讲初始化失败，保留原生错误码和失败环节', error,
          stackTrace: stack);
      try {
        await stopTalking(reason: 'start_failed');
      } catch (_) {/* 清理异常另有日志。 */}
      rethrow;
    }
  }

  Map<String, Object?> _talkFields() => {
        'micBatches': _micBatches,
        'micBytes': _micBytes,
        'pcmChunks': _pcmChunks,
        'queuedChunks': _chunks.length,
        'partialBytes': _partial.length,
        'droppedChunks': _droppedChunks,
        'sentPackets': _sentPackets,
        'sentBytes': _sentBytes,
        'lastCaptureAgeMs': _lastCaptureMs == null
            ? null
            : _talkWatch.elapsedMilliseconds - _lastCaptureMs!,
        'lastSendAgeMs': _lastSendMs == null
            ? null
            : _talkWatch.elapsedMilliseconds - _lastSendMs!,
        'pcmPeak': _pcmPeak,
        'nonZeroSamples': _nonZeroSamples,
        'durationMs': _talkWatch.elapsedMilliseconds,
      };

  void _talkHealth() {
    final reason = _micBatches == 0
        ? 'microphone_no_data'
        : _lastCaptureMs != null &&
                _talkWatch.elapsedMilliseconds - _lastCaptureMs! > 3000
            ? 'microphone_capture_stalled'
            : _pcmChunks == 0
                ? 'pcm_not_enough_for_packet'
                : _nonZeroSamples == 0
                    ? 'microphone_pcm_all_zero'
                    : _sentPackets == 0
                        ? 'waiting_for_websocket_send'
                        : 'talk_sending';
    const messages = {
      'microphone_no_data': '麦克风已启动，但尚未收到任何 PCM 数据',
      'microphone_capture_stalled': '麦克风数据已中断超过 3 秒',
      'pcm_not_enough_for_packet': '已采集音频，但尚未拼出完整的 640 字节音频包',
      'microphone_pcm_all_zero': '已采集音频，但当前累计 PCM 样本全部为零',
      'waiting_for_websocket_send': '音频包已生成，尚未成功交付 WebSocket',
      'talk_sending': '麦克风采集与客户端发送持续进行；设备播放需由硬件端确认',
    };
    diagnostics?.log('talk.health', '对讲巡检', messages[reason]!,
        level: reason == 'talk_sending' ? 'info' : 'warning',
        fields: {..._talkFields(), 'diagnosis': reason});
  }

  void _talkFailed(int generation, String phase, Object error, StackTrace stack,
      void Function(Object) onError) {
    if (generation != _generation) return;
    diagnostics?.failure(
        'talk.$phase.failed',
        phase == 'send' ? 'WebSocket 对讲发送' : 'PCM 采集',
        phase == 'send' ? '发送对讲音频失败，停止麦克风，媒体观看继续' : '原生麦克风流发生异常，停止对讲',
        error,
        fields: _talkFields(),
        stackTrace: stack);
    unawaited(stopTalking(reason: '${phase}_failed').catchError((_) {}));
    onError(DeviceTalkFailure(phase, error));
  }

  Future<void> stopTalking({String reason = 'owner_stop'}) {
    _generation++;
    _talkTimer?.cancel();
    _talkTimer = null;
    _talkHealthTimer?.cancel();
    _talkHealthTimer = null;
    if (_talkClosing != null) return _talkClosing!;
    final mic = _mic;
    final state = _recordState;
    final nativeRecording = _nativeRecording;
    _mic = null;
    _recordState = null;
    _nativeRecording = false;
    final fields = _talkFields();
    if (_talkWatch.isRunning) {
      diagnostics?.log('talk.cleanup.begin', '对讲清理', '取消待发包和录音订阅，释放原生麦克风',
          fields: {...fields, 'reason': reason});
    }
    _chunks.clear();
    _partial = Uint8List(0);
    return _talkClosing = (() async {
      try {
        try {
          await mic?.cancel();
        } finally {
          try {
            await state?.cancel();
          } finally {
            if (nativeRecording) await recorder.stop();
          }
        }
        if (_talkWatch.isRunning) {
          diagnostics?.log('talk.cleanup.ok', '对讲清理', '麦克风已释放，待发语音已清空',
              fields: {...fields, 'reason': reason});
        }
      } catch (error, stack) {
        diagnostics?.failure(
            'talk.cleanup.failed', '对讲清理', '原生麦克风停止或订阅清理失败', error,
            fields: {'reason': reason}, stackTrace: stack);
        rethrow;
      } finally {
        _talkWatch.stop();
      }
    })()
        .whenComplete(() => _talkClosing = null);
  }

  Future<void> close() async {
    _open = false;
    _pendingPlayback = null;
    await stopTalking();
    await media.closeAudio();
  }

  Future<void> dispose() async {
    await close();
    await recorder.dispose();
  }
}
