/// ════════════════════════════════════════════════════════════
///  数字宠数据仓库 — DigitalPetRepository
///
///  在架构中的位置：
///    View → Controller → [Repository] → ApiClient → 业务后端
///
///  职责：包装数字宠首页需要的 4 个业务后端接口——
///    GET  /sdkapi/pet/:id/status    一次性拉取基本信息+养成属性+背景/形象
///    POST /sdkapi/pet/:id/interact  执行互动
///    GET  /sdkapi/pet/resources     背景/形象/动作码/互动类型清单
///    GET  /sdkapi/pet/:id/action    硬件动作轮询
///    PUT  /sdkapi/pet/:id           仅用于写回 backgroundId/modelId 选择
///
///  [id] 参数在本文件里始终是宠物的 peer 网关 petId（与业务后端 id
///  相同字符串，见 pet_sync_repository.dart 顶部说明），调用方不需要
///  额外做任何映射查找。
///
///  updateResourceSelection 为什么不复用 PetRepository.updatePet：
///    PetModel.toJson() 会无条件带上 species/breed/gender（哪怕用默认值），
///    如果只想改 backgroundId，用一个"半空"的 PetModel 去调用会把这些
///    字段覆盖成默认值，污染宠物档案。这里改用只发必要字段的独立 PUT
///    调用，`name` 必须由调用方传入当前已知的名字（后端要求 name 必填），
///    `backgroundId`/`modelId` 未传的一侧按后端约定保持不变。
/// ════════════════════════════════════════════════════════════
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/result.dart';
import '../models/pet_status_model.dart';
import '../models/pet_resources_model.dart';

class DigitalPetRepository {
  final ApiClient _client;

  DigitalPetRepository(this._client);

  /// GET /sdkapi/pet/:id/status
  Future<Result<PetStatusModel>> fetchStatus(String petId) =>
      guardResult(() async {
        final data = await _client.get<Map<String, dynamic>>(
          ApiEndpoints.petStatus(petId),
        );
        return PetStatusModel.fromJson(data);
      });

  /// POST /sdkapi/pet/:id/interact
  Future<Result<InteractResult>> interact(
    String petId,
    String interactionCode,
  ) =>
      guardResult(() async {
        final data = await _client.post<Map<String, dynamic>>(
          ApiEndpoints.petInteract(petId),
          data: {'interactionCode': interactionCode},
        );
        return InteractResult.fromJson(data);
      });

  /// GET /sdkapi/pet/resources
  Future<Result<PetResourcesModel>> fetchResources() => guardResult(() async {
        final data = await _client.get<Map<String, dynamic>>(
          ApiEndpoints.petResources,
        );
        return PetResourcesModel.fromJson(data);
      });

  /// GET /sdkapi/pet/:id/action
  Future<Result<PetActionModel>> fetchAction(String petId) =>
      guardResult(() async {
        final data = await _client.get<Map<String, dynamic>>(
          ApiEndpoints.petAction(petId),
        );
        return PetActionModel.fromJson(data);
      });

  /// PUT /sdkapi/pet/:id — 仅写回背景/形象选择
  ///
  /// [currentName] - 当前宠物名字（后端 name 字段必填，即便本次只改
  ///                  背景/形象也要带上，取自已加载的 [PetStatusModel.name]）
  /// [backgroundId]/[modelId] - 传 null 表示不修改该项（与后端约定一致）
  Future<Result<void>> updateResourceSelection(
    String petId, {
    required String currentName,
    String? backgroundId,
    String? modelId,
  }) =>
      guardResult(() async {
        await _client.put<Map<String, dynamic>>(
          ApiEndpoints.petDetail(petId),
          data: {
            'name': currentName,
            if (backgroundId != null) 'backgroundId': backgroundId,
            if (modelId != null) 'modelId': modelId,
          },
        );
      });
}

// ── Riverpod Provider ─────────────────────────────────────
final digitalPetRepositoryProvider = Provider<DigitalPetRepository>((ref) {
  return DigitalPetRepository(ref.read(apiClientProvider));
});
