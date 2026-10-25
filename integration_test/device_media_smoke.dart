// 手工原生冒烟测试：flutter run -t integration_test/device_media_smoke.dart -d <device>
// 不连接硬件、不申请麦克风权限；验证 PCM 输出与可播放的本地 H.264/AAC MP4。
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:petpogo_device_media/petpogo_device_media.dart';
import 'package:video_player/video_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
      home: Scaffold(body: Center(child: Text('正在验证本地音视频')))));
  final media = DeviceMedia();
  try {
    await media.openAudio();
    await media.feedAudio(Uint8List(640));
    await media.setVolume(0.5);
    await media.closeAudio();
    final directory = await Directory(
            '${(await getTemporaryDirectory()).path}/native-media-smoke')
        .create(recursive: true);
    final image = File('${directory.path}/frame.jpg');
    await image.writeAsBytes(
        (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List());
    final pcm = File('${directory.path}/audio.pcm');
    await pcm.writeAsBytes(Uint8List(64000));
    final manifest = File('${directory.path}/recording.json');
    await manifest.writeAsString(jsonEncode({
      'frames': List.generate(
          20, (index) => {'path': image.path, 'timeUs': index * 100000}),
      'audioPath': pcm.path,
      'durationUs': 2000000,
      'outputPath': '${directory.path}/recording.mp4',
    }));
    final output = await media.encodeRecording(manifest.path);
    final controller = VideoPlayerController.file(File(output));
    await controller.initialize();
    final bytes = await File(output).readAsBytes();
    final header = latin1.decode(bytes);
    if (controller.value.duration.inMilliseconds < 1700 ||
        controller.value.size.width <= 0 ||
        !header.contains('avc1') ||
        !header.contains('mp4a')) {
      throw StateError('MP4 音视频轨道或时长不正确');
    }
    final result =
        'DEVICE_MEDIA_SMOKE_OK ${controller.value.duration.inMilliseconds}ms ${controller.value.size} ${bytes.length}bytes';
    debugPrint(result);
    await controller.dispose();
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text(result)))));
  } catch (error, stack) {
    debugPrint('DEVICE_MEDIA_SMOKE_FAILED $error\n$stack');
    runApp(MaterialApp(
        home: Scaffold(
            body: Center(child: Text('DEVICE_MEDIA_SMOKE_FAILED $error')))));
  }
}
