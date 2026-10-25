import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:petpogo_device_media/petpogo_device_media.dart';
import 'recording_diagnostics.dart';
import 'stream_diagnostics.dart';

/// 接收时顺序写临时文件，结束后在原生工作线程编码 MP4，避免整段录像驻留内存。
class LocalStreamRecorder {
  final DeviceMedia media;
  LocalStreamRecorder({DeviceMedia? media}) : media = media ?? DeviceMedia();
  StreamDiagnostics? diagnostics;
  RecordingDiagnostics? trace;
  RecordingDiagnostics? createTrace() =>
      diagnostics == null ? null : RecordingDiagnostics(diagnostics!);
  Directory? _directory;
  IOSink? _audio;
  final _frames = <Map<String, Object>>[];
  final _clock = Stopwatch();
  Future<void> _writes = Future.value();
  Timer? _health;
  bool _active = false, _limitLogged = false;
  int _pendingFrames = 0, _writtenFrames = 0, _droppedFrames = 0;
  int _videoBytes = 0, _audioBytes = 0, _audioPackets = 0, _silenceSamples = 0;
  int _audioSamples = 0;
  int? _lastVideoMs;
  Object? _error;
  bool get active => _active;

  Map<String, Object?> _stats() => {
        'recordFrames': _frames.length,
        'writtenFrames': _writtenFrames,
        'recordVideoBytes': _videoBytes,
        'recordAudioPackets': _audioPackets,
        'recordAudioBytes': _audioBytes,
        'audioSamples': _audioSamples,
        'silenceSamples': _silenceSamples,
        'pendingFrames': _pendingFrames,
        'droppedFrames': _droppedFrames,
        'hasAudio': _audioPackets > 0,
        'recordDurationMs': _clock.elapsedMilliseconds,
        'lastVideoAgeMs': _lastVideoMs == null
            ? null
            : _clock.elapsedMilliseconds - _lastVideoMs!,
      };

  Future<void> start(Uint8List firstFrame,
      {RecordingDiagnostics? trace}) async {
    if (_directory != null) throw StateError('上一段录像仍在处理');
    this.trace = trace ?? createTrace();
    final log = this.trace;
    final watch = Stopwatch()..start();
    log?.log('local.start.begin', '录像临时目录', '创建本地 JPEG 和 PCM 录像素材目录',
        fields: {'maxDurationMs': 30000});
    try {
      _directory = await Directory(
              '${(await getTemporaryDirectory()).path}/device-recordings')
          .create(recursive: true)
          .then((dir) => dir.createTemp('clip-'));
      _frames.clear();
      _audioSamples = _pendingFrames = _writtenFrames = _droppedFrames = 0;
      _videoBytes = _audioBytes = _audioPackets = _silenceSamples = 0;
      _error = null;
      _lastVideoMs = null;
      _limitLogged = false;
      _writes = Future.value();
      _audio = File('${_directory!.path}/audio.pcm').openWrite();
      unawaited(_audio!.done.catchError((Object error, StackTrace stack) {
        _writeFailed('audio', error, stack);
      }));
      _active = true;
      _clock
        ..reset()
        ..start();
      _health?.cancel();
      _health = Timer.periodic(const Duration(seconds: 5), (_) {
        final stalled = _lastVideoMs != null &&
            _clock.elapsedMilliseconds - _lastVideoMs! > 5000;
        log?.log('health', '录像素材接收',
            stalled ? '录像期间超过 5 秒没有新视频，当前素材仍保留' : '录像素材接收与写盘统计',
            level: stalled ? 'warning' : 'info',
            fields: {
              ..._stats(),
              'diagnosis':
                  stalled ? 'recording_video_stalled' : 'recording_sources'
            });
      });
      log?.log('local.start.ok', '录像素材接收', '本地录像已启动，开始写入当前画面与设备声音', fields: {
        'durationMs': watch.elapsedMilliseconds,
        'sourceFolder':
            _directory!.uri.pathSegments.where((s) => s.isNotEmpty).last,
      });
      addVideo(firstFrame);
    } catch (error, stack) {
      log?.failure('local.start.failed', '录像临时目录', '本地录像初始化失败', error,
          stackTrace: stack);
      rethrow;
    }
  }

  bool _pastLimit() {
    if (_clock.elapsedMicroseconds <= 30000000) return false;
    if (!_limitLogged) {
      _limitLogged = true;
      trace?.log('limit.reached', '录像时长', '已到 30 秒素材上限，等待页面停止并导出',
          fields: _stats());
    }
    return true;
  }

  void _writeFailed(String source, Object error, StackTrace stack) {
    if (_error == null) {
      trace?.failure(
          'source.write.failed',
          source == 'audio' ? 'PCM 素材写盘' : 'JPEG 素材写盘',
          '录像素材写入失败，结束时将保留已有素材并报告错误',
          error,
          fields: _stats(),
          stackTrace: stack);
    }
    _error ??= error;
  }

  void addVideo(Uint8List jpeg) {
    if (!_active || _pastLimit()) return;
    _lastVideoMs = _clock.elapsedMilliseconds;
    if (_pendingFrames >= 3) {
      _droppedFrames++;
      if (_droppedFrames == 1 || (_droppedFrames & (_droppedFrames - 1)) == 0) {
        trace?.log('video.dropped', 'JPEG 素材写盘', '写盘队列繁忙，跳过此帧以限制内存',
            level: 'warning', fields: _stats());
      }
      return;
    }
    final time = _clock.elapsedMicroseconds;
    final path = '${_directory!.path}/${_frames.length}.jpg';
    _frames.add({'path': path, 'timeUs': time});
    _pendingFrames++;
    _videoBytes += jpeg.length;
    _writes = _writes.then((_) async {
      try {
        await File(path).writeAsBytes(jpeg);
        if (++_writtenFrames == 1) {
          trace?.log('video.first_written', 'JPEG 素材写盘', '第一帧录像画面已写入临时文件',
              fields: {'bytes': jpeg.length});
        }
      } catch (error, stack) {
        _writeFailed('video', error, stack);
      } finally {
        _pendingFrames--;
      }
    });
  }

  void addAudio(Uint8List pcm) {
    if (!_active || _pastLimit()) return;
    try {
      // 使用本地单调时钟锚定首包和明显断流，正常包按样本数连续写入。
      final target =
          (_clock.elapsedMicroseconds * 16000 ~/ 1000000) - pcm.length ~/ 2;
      final gap = target - _audioSamples;
      if (_audioSamples == 0 || gap > 4000) {
        if (gap > 0) {
          _audio!.add(Uint8List(gap * 2));
          _audioSamples += gap;
          _silenceSamples += gap;
        }
      }
      _audio!.add(pcm);
      _audioSamples += pcm.length ~/ 2;
      _audioBytes += pcm.length;
      if (++_audioPackets == 1) {
        trace?.log('audio.first_buffered', 'PCM 素材缓冲', '第一包设备声音已加入录像缓冲，结束时统一刷盘',
            fields: {'bytes': pcm.length, 'sampleRate': 16000, 'channels': 1});
      }
    } catch (error, stack) {
      _writeFailed('audio', error, stack);
    }
  }

  Future<String> finish({String reason = 'user_stop'}) async {
    if (!_active || _directory == null) throw StateError('没有正在录制的视频');
    _active = false;
    _health?.cancel();
    _clock.stop();
    final log = trace;
    final directory = _directory!;
    final duration = _clock.elapsedMicroseconds.clamp(100000, 30000000);
    var stage = '录像素材刷盘';
    var outputReady = false, cleanupStarted = false;
    Timer? encodingHealth;
    final watch = Stopwatch()..start();
    log?.log('stop.begin', stage, '停止接收录像素材，等待待写画面和 PCM 完成',
        fields: {..._stats(), 'reason': reason});
    try {
      await _writes;
      await _audio?.flush();
      await _audio?.close();
      _audio = null;
      if (_error != null) throw _error!;
      log?.log('sources.flushed', stage, 'JPEG 与 PCM 素材刷盘完成',
          fields: {..._stats(), 'durationMs': watch.elapsedMilliseconds});
      stage = '录像清单写入';
      final manifest = File('${directory.path}/recording.json');
      await manifest.writeAsString(jsonEncode({
        'frames': _frames,
        'audioPath': '${directory.path}/audio.pcm',
        'durationUs': duration,
        'outputPath': '${directory.path}/recording.mp4',
        if (log != null) 'recordingId': log.recordingId,
      }));
      log?.log('manifest.ready', stage, '原生编码所需的素材清单已生成', fields: _stats());
      stage = '原生 MP4 编码';
      final encodeWatch = Stopwatch()..start();
      log?.log('encode.begin', stage, '调用原生 JPEG/PCM → H.264/AAC MP4 编码',
          fields: {..._stats(), 'nativeMethod': 'encodeRecording'});
      encodingHealth = Timer.periodic(const Duration(seconds: 5), (_) {
        log?.log('encode.waiting', stage, '原生编码尚未返回，继续等待；此记录不表示编码百分比', fields: {
          'durationMs': encodeWatch.elapsedMilliseconds,
          'recordFrames': _frames.length
        });
      });
      final output = await media.encodeRecording(manifest.path);
      encodingHealth.cancel();
      stage = 'MP4 输出校验';
      final outputBytes = await File(output).length();
      if (outputBytes <= 0) throw StateError('原生返回了空录像文件');
      outputReady = true;
      log?.log('encode.ok', stage, '原生编码成功，MP4 文件已存在且非空', fields: {
        'outputBytes': outputBytes,
        'durationMs': encodeWatch.elapsedMilliseconds,
        'hasAudio': _audioPackets > 0,
        'localFilePreserved': true
      });
      stage = '录像素材清理';
      cleanupStarted = true;
      log?.log('sources.cleanup.begin', stage, 'MP4 已生成，开始清理 JPEG、PCM 和清单临时文件');
      for (final frame in _frames) {
        await File(frame['path']! as String).delete();
      }
      await File('${directory.path}/audio.pcm').delete();
      await manifest.delete();
      log?.log('sources.cleanup.ok', stage, '临时素材已清理，保留 MP4 等待存入相册',
          fields: {'localFilePreserved': true, 'sourcePreserved': false});
      return output;
    } catch (error, stack) {
      log?.failure('finish.failed', stage, '录像导出失败，记录失败阶段与本地保留状态', error,
          fields: {
            ..._stats(),
            'sourcePreserved': cleanupStarted ? null : true,
            'localFilePreserved': outputReady ? true : null,
            'reason': reason,
          },
          stackTrace: stack);
      rethrow;
    } finally {
      encodingHealth?.cancel();
      try {
        await _audio?.close();
      } catch (_) {/* 刷盘异常已在 finish.failed 记录。 */}
      _audio = null;
      _directory = null;
      _frames.clear();
    }
  }

  Future<void> cancel({String reason = 'page_dispose'}) async {
    _active = false;
    _health?.cancel();
    _clock.stop();
    final directory = _directory;
    final log = trace;
    if (directory != null) {
      log?.log('cancel.begin', '取消录像', '取消本段录像，清理未导出的临时素材',
          fields: {..._stats(), 'reason': reason});
    }
    try {
      await _writes;
      await _audio?.close();
      _audio = null;
      if (directory != null && await directory.exists()) {
        await directory.delete(recursive: true);
      }
      if (directory != null) {
        log?.log('cancel.ok', '取消录像', '未导出的临时素材已清理',
            fields: {'reason': reason, 'sourcePreserved': false});
      }
    } catch (error, stack) {
      log?.failure('cancel.failed', '取消录像', '临时素材清理失败', error,
          fields: {'reason': reason}, stackTrace: stack);
      rethrow;
    } finally {
      _audio = null;
      _directory = null;
      _frames.clear();
    }
  }
}
