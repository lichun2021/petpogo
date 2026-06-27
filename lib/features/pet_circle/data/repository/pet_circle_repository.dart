import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/result.dart';
import '../models/pet_circle_post.dart';

class PetCircleRepository {
  final ApiClient _client;

  const PetCircleRepository(this._client);

  Future<Result<PetCircleFeedPage>> fetchFeed({
    required String petId,
    int page = 1,
    int pageSize = 20,
  }) {
    return guardResult(() async {
      debugPrint(
          '[萌宠圈][API] GET ${ApiEndpoints.petCircleFeed} petId=$petId page=$page pageSize=$pageSize');
      final data = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.petCircleFeed,
        params: {
          'petId': petId,
          'page': page,
          'pageSize': pageSize,
        },
      );
      final pageData = PetCircleFeedPage.fromJson(data);
      debugPrint(
          '[萌宠圈][API] GET feed OK total=${pageData.total} page=${pageData.page} pageSize=${pageData.pageSize} count=${pageData.list.length}');
      return pageData;
    });
  }

  Future<Result<void>> deletePost(String id) {
    return guardResult(() async {
      debugPrint('[萌宠圈][API] DELETE ${ApiEndpoints.petCirclePostDelete(id)}');
      await _client.delete(ApiEndpoints.petCirclePostDelete(id));
      debugPrint('[萌宠圈][API] DELETE post OK id=$id');
    });
  }
}

final petCircleRepositoryProvider = Provider<PetCircleRepository>((ref) {
  return PetCircleRepository(ref.watch(apiClientProvider));
});
