/// 抓拍 / 打招呼 / 声音 Repository
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../models/capture_model.dart';

class CaptureRepository {
  final ApiClient _client;
  CaptureRepository(this._client);

  // ── 自动抓拍列表 ─────────────────────────────────────────
  Future<CaptureListResult> fetchCaptureList({
    required String deviceId,
    String? eventType,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.captureList,
      params: {
        'deviceId': deviceId,
        'page': page,
        'pageSize': pageSize,
        if (eventType != null) 'eventType': eventType,
      },
    );
    return CaptureListResult.fromJson(res);
  }

  // ── 打招呼记录列表 ────────────────────────────────────────
  Future<GreetingListResult> fetchGreetingList({
    required String deviceId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.greetingList,
      params: {
        'deviceId': deviceId,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return GreetingListResult.fromJson(res);
  }

  // ── 声音列表（预设+用户合并）──────────────────────────────
  /// [petType] 'cat' | 'dog'，传给服务端过滤，默认 cat
  /// [emotion] 不传则返回全部情绪
  Future<List<SoundPreset>> fetchSoundList({
    required String petType,
    String? emotion,
    int pageSize = 100,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.soundPresetList,
      params: {
        'petType': petType,
        'pet_type': petType,
        'pageSize': pageSize,
        if (emotion != null) 'emotion': emotion,
      },
    );
    final list = (res['list'] as List?) ?? [];
    return list
        .map((e) => SoundPreset.fromJson(
              e as Map<String, dynamic>,
              fallbackPetType: petType,
            ))
        .toList();
  }

  // ── 保存用户录音 ─────────────────────────────────────────
  Future<int> saveUserSound({
    required String name,
    required String url,
    String? emotion,
    String? petType,
    int? duration,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/sdkapi/sound/user/save',
      data: {
        'name': name,
        'url': url,
        if (emotion != null) 'emotion': emotion,
        if (petType != null) ...{
          'petType': petType,
          'pet_type': petType,
        },
        if (duration != null) 'duration': duration,
      },
    );
    return (res['id'] as num?)?.toInt() ?? 0;
  }

  // ── 删除用户声音 ─────────────────────────────────────────
  Future<void> deleteUserSound(int id) async {
    await _client.delete('/sdkapi/sound/user/$id');
  }

  // ── 删除抓拍记录 ─────────────────────────────────────────
  Future<void> deleteCapture(int id) async {
    await _client.delete(ApiEndpoints.captureDelete(id));
  }
}

// ── Provider ────────────────────────────────────────────────
final captureRepositoryProvider = Provider<CaptureRepository>((ref) {
  return CaptureRepository(ref.watch(apiClientProvider));
});
