import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/result.dart';
import '../models/share_link_model.dart';

class ShareRepository {
  final ApiClient _client;
  ShareRepository(this._client);

  Future<Result<ShareCreateResult>> createShare({
    required String type,
    required String targetId,
    required String title,
    required String description,
    String? imageUrl,
    Map<String, dynamic>? payload,
    int expireDays = 30,
  }) {
    return guardResult(() async {
      final res = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.shareCreate,
        data: {
          'type': type,
          'targetId': targetId,
          'title': title,
          'description': description,
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
          if (payload != null && payload.isNotEmpty) 'payload': payload,
          'expireDays': expireDays,
        },
      );
      final result = ShareCreateResult.fromJson(res);
      debugPrint('[分享] 创建成功 code=${result.code} url=${result.shareUrl}');
      return result;
    });
  }

  Future<Result<ShareResolveResult>> resolveShare(String code) {
    debugPrint('[分享] 解析请求 code=$code');
    return guardResult(() async {
      final res = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.shareResolve,
        params: {'code': code},
      );
      return ShareResolveResult.fromJson(res);
    });
  }
}

final shareRepositoryProvider = Provider<ShareRepository>((ref) {
  return ShareRepository(ref.watch(apiClientProvider));
});
