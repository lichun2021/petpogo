import 'dart:typed_data';
import 'package:flutter/services.dart';

/// 原生仅负责 PCM 输出和离线 MP4 编码，不访问网络或申请录音权限。
class DeviceMedia {
  static const channel = MethodChannel('petpogo/device_media');
  Future<void> openAudio() => channel.invokeMethod('openAudio');
  Future<void> feedAudio(Uint8List pcm) =>
      channel.invokeMethod('feedAudio', pcm);
  Future<void> setVolume(double volume) =>
      channel.invokeMethod('setVolume', volume.clamp(0, 1));
  Future<void> closeAudio() => channel.invokeMethod('closeAudio');
  Future<String> encodeRecording(String manifest) async {
    final path =
        await channel.invokeMethod<String>('encodeRecording', manifest);
    if (path == null || path.isEmpty) throw StateError('未生成录像文件');
    return path;
  }
}
