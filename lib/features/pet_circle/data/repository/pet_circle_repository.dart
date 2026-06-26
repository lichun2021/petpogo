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
      final data = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.petCircleFeed,
        params: {
          'petId': petId,
          'page': page,
          'pageSize': pageSize,
        },
      );
      return PetCircleFeedPage.fromJson(data);
    });
  }

  Future<Result<void>> deletePost(String id) {
    return guardResult(() async {
      await _client.delete(ApiEndpoints.petCirclePostDelete(id));
    });
  }
}

final petCircleRepositoryProvider = Provider<PetCircleRepository>((ref) {
  return PetCircleRepository(ref.watch(apiClientProvider));
});
