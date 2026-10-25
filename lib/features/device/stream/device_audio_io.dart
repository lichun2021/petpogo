import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:petpogo_device_media/petpogo_device_media.dart';
import 'package:record/record.dart';
import 'stream_protocol.dart';

class DeviceAudioIo {
  final DeviceMedia media;
  final AudioRecorder recorder;
  DeviceAudioIo({DeviceMedia? media, AudioRecorder? recorder})
      : media = media ?? DeviceMedia(),
        recorder = recorder ?? AudioRecorder();
  void Function(String event, Object? error)? onPlaybackEvent;
  int playedChunks = 0;
  int _playbackFailures = 0;
  StreamSubscription<Uint8List>? _mic;
  Timer? _talkTimer;
  final _chunks = Queue<Uint8List>();
  Uint8List _partial = Uint8List(0);
  int _generation = 0;
  bool _open = false;
  bool _feeding = false;
  Uint8List? _pendingPlayback;

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
    final generation = ++_generation;
    if (!await recorder.hasPermission()) return false;
    if (generation != _generation) return false;
    if (Platform.isIOS) await recorder.ios?.manageAudioSession(false);
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
      return false;
    }
    _mic = input.listen((bytes) {
      final data = Uint8List(_partial.length + bytes.length)
        ..setAll(0, _partial)
        ..setAll(_partial.length, bytes);
      var offset = 0;
      while (offset + devicePcmChunkBytes <= data.length) {
        _chunks.add(Uint8List.fromList(
            data.sublist(offset, offset + devicePcmChunkBytes)));
        offset += devicePcmChunkBytes;
      }
      _partial = Uint8List.fromList(data.sublist(offset));
      while (_chunks.length > 10) {
        _chunks.removeFirst();
      }
    }, onError: (Object error) {
      unawaited(stopTalking());
      onError(error);
    }, onDone: () {
      if (generation == _generation) {
        unawaited(stopTalking());
        onError(StateError('麦克风已停止'));
      }
    });
    _talkTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (generation == _generation && _chunks.isNotEmpty) {
        send(_chunks.removeFirst());
      }
    });
    return true;
  }

  Future<void> stopTalking() async {
    _generation++;
    _talkTimer?.cancel();
    _talkTimer = null;
    final mic = _mic;
    _mic = null;
    await mic?.cancel();
    _chunks.clear();
    _partial = Uint8List(0);
    if (mic != null) await recorder.stop();
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
