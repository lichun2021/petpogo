/// 录像质量 Provider
///
/// 控制录制时的截帧频率：
///   低质量  - 8 fps  （小文件，慢速网络友好）
///   标准    - 15 fps  （默认，流畅）
///   高质量  - 24 fps  （接近电影帧率，文件较大）
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kVideoQualityKey = 'video_quality';

class VideoQualityOption {
  final String key;
  final String label;
  final String description;
  final int fps;       // 截帧频率（每秒帧数）
  final int bitrate;   // 目标码率 kbps（ffmpeg 参数参考）

  const VideoQualityOption({
    required this.key,
    required this.label,
    required this.description,
    required this.fps,
    required this.bitrate,
  });
}

const kVideoQualityOptions = [
  VideoQualityOption(
    key:         'low',
    label:       '低质量',
    description: '8fps · 文件小，适合慢速网络',
    fps:         8,
    bitrate:     500,
  ),
  VideoQualityOption(
    key:         'medium',
    label:       '标准',
    description: '15fps · 默认，流畅平衡',
    fps:         15,
    bitrate:     1000,
  ),
  VideoQualityOption(
    key:         'high',
    label:       '高质量',
    description: '24fps · 接近电影帧率，文件较大',
    fps:         24,
    bitrate:     2000,
  ),
];

VideoQualityOption qualityByKey(String key) =>
    kVideoQualityOptions.firstWhere((o) => o.key == key,
        orElse: () => kVideoQualityOptions[1]);

final videoQualityProvider =
    StateNotifierProvider<VideoQualityNotifier, String>((ref) {
  return VideoQualityNotifier('medium');
});

class VideoQualityNotifier extends StateNotifier<String> {
  VideoQualityNotifier(String initialKey) : super(initialKey);

  Future<void> setQuality(String key) async {
    state = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kVideoQualityKey, key);
  }
}
