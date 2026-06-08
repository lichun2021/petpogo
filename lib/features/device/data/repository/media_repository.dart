/// 媒体库 Repository
///
/// 负责：
///   - 获取列表（个人 / 设备共享）
///   - 保存记录（OSS 上传成功后调用）
///   - 删除文件
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../models/media_model.dart';

class MediaRepository {
  final ApiClient _client;
  MediaRepository(this._client);

  // ── 获取列表 ───────────────────────────────────────────
  /// [deviceId] 传入则返回该设备所有绑定用户的上传（共享图库）
  /// [type]     1图片 2视频 null全部
  Future<MediaListResult> fetchList({
    String? deviceId,
    int? type,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page':     page,
      'pageSize': pageSize,
      if (deviceId != null) 'deviceId': deviceId,
      if (type != null) 'type': type,
    };
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.mediaList,
      params: params,
    );
    return MediaListResult.fromJson(res);
  }

  // ── 保存记录 ───────────────────────────────────────────
  Future<SaveMediaResult> saveRecord({
    required int    type,        // 1图片 2视频
    required String url,         // CDN 完整地址
    required String ossKey,      // OSS 对象 Key
    int?    fileSize,
    int?    duration,            // 视频时长（秒）
    String? deviceId,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.mediaSave,
      data: {
        'type':     type,
        'url':      url,
        'ossKey':   ossKey,
        if (fileSize != null) 'fileSize': fileSize,
        if (duration != null) 'duration': duration,
        if (deviceId != null) 'deviceId': deviceId,
      },
    );
    return SaveMediaResult.fromJson(res);
  }

  // ── 删除文件 ───────────────────────────────────────────
  Future<void> deleteRecord(int id) async {
    await _client.delete(ApiEndpoints.mediaDelete(id.toString()));
  }
}

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(ref.watch(apiClientProvider));
});
