import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:petpogo_device_media/petpogo_device_media.dart';

/// 接收时顺序写临时文件，结束后在原生工作线程编码 MP4，避免整段录像驻留内存。
class LocalStreamRecorder {
  final DeviceMedia media;
  LocalStreamRecorder({DeviceMedia? media}) : media = media ?? DeviceMedia();
  Directory? _directory;
  IOSink? _audio;
  final _frames = <Map<String, Object>>[];
  final _clock = Stopwatch();
  Future<void> _writes = Future.value();
  bool _active = false;
  int _pendingFrames = 0;
  int _audioSamples = 0;
  Object? _error;
  bool get active => _active;

  Future<void> start(Uint8List firstFrame) async {
    if (_directory != null) throw StateError('上一段录像仍在处理');
    _directory = await Directory(
            '${(await getTemporaryDirectory()).path}/device-recordings')
        .create(recursive: true)
        .then((dir) => dir.createTemp('clip-'));
    _audio = File('${_directory!.path}/audio.pcm').openWrite();
    unawaited(_audio!.done.catchError((Object error) {
      _error ??= error;
    }));
    _frames.clear();
    _audioSamples = 0;
    _pendingFrames = 0;
    _error = null;
    _writes = Future.value();
    _active = true;
    _clock
      ..reset()
      ..start();
    addVideo(firstFrame);
  }

  void addVideo(Uint8List jpeg) {
    if (!_active ||
        _pendingFrames >= 3 ||
        _clock.elapsedMicroseconds > 30000000) {
      return;
    }
    final time = _clock.elapsedMicroseconds;
    final path = '${_directory!.path}/${_frames.length}.jpg';
    _frames.add({'path': path, 'timeUs': time});
    _pendingFrames++;
    _writes = _writes.then((_) async {
      try {
        await File(path).writeAsBytes(jpeg);
      } catch (error) {
        _error ??= error;
      } finally {
        _pendingFrames--;
      }
    });
  }

  void addAudio(Uint8List pcm) {
    if (!_active || _clock.elapsedMicroseconds > 30000000) return;
    // 使用本地单调时钟锚定首包和明显断流，正常包按样本数连续写入。
    final target =
        (_clock.elapsedMicroseconds * 16000 ~/ 1000000) - pcm.length ~/ 2;
    final gap = target - _audioSamples;
    if (_audioSamples == 0 || gap > 4000) {
      if (gap > 0) {
        _audio!.add(Uint8List(gap * 2));
        _audioSamples += gap;
      }
    }
    _audio!.add(pcm);
    _audioSamples += pcm.length ~/ 2;
  }

  Future<String> finish() async {
    if (!_active || _directory == null) throw StateError('没有正在录制的视频');
    _active = false;
    _clock.stop();
    final duration = _clock.elapsedMicroseconds.clamp(100000, 30000000);
    await _writes;
    await _audio?.flush();
    await _audio?.close();
    _audio = null;
    if (_error != null) throw StateError('录像写入失败：$_error');
    final directory = _directory!;
    final manifest = File('${directory.path}/recording.json');
    await manifest.writeAsString(jsonEncode({
      'frames': _frames,
      'audioPath': '${directory.path}/audio.pcm',
      'durationUs': duration,
      'outputPath': '${directory.path}/recording.mp4',
    }));
    // 编码失败时保留源文件，便于恢复，成功后只清理 JPEG 和 PCM 临时素材。
    try {
      final output = await media.encodeRecording(manifest.path);
      for (final frame in _frames) {
        await File(frame['path']! as String).delete();
      }
      await File('${directory.path}/audio.pcm').delete();
      await manifest.delete();
      return output;
    } finally {
      _directory = null;
      _frames.clear();
    }
  }

  Future<void> cancel() async {
    _active = false;
    _clock.stop();
    await _writes;
    await _audio?.close();
    _audio = null;
    final directory = _directory;
    _directory = null;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
