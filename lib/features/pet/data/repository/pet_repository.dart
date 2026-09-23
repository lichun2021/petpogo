/// 宠物档案查询与更新。

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/result.dart';
import '../models/pet_model.dart';


class PetRepository {
  /// 通过构造函数注入 ApiClient（依赖注入，方便单元测试时 mock）
  final ApiClient _client;

  PetRepository(this._client);

  // ── 查询 ──────────────────────────────────────────────

  /// 获取当前登录用户的所有宠物列表
  ///
  /// 返回 Result<List<PetModel>>：
  ///   - Success → 宠物列表（可能为空列表 []）
  ///   - Failure → ApiException（网络错误、401等）
  Future<Result<List<PetModel>>> fetchPets() => guardResult(() async {
    const path = ApiEndpoints.petList;
    debugPrint('[🐾宠物] fetchPets → GET $path');
    dynamic rawData;
    try {
      rawData = await _client.get<dynamic>(path);
    } catch (e) {
      debugPrint('[🐾宠物] ❌ 请求失败: $e');
      rethrow;
    }
    debugPrint('[🐾宠物] 原始响应类型: ${rawData.runtimeType}');
    debugPrint('[🐾宠物] 原始响应内容: $rawData');

    List<dynamic> list;
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map) {
      // 服务端返回 {code, info: [...]} 包装格式
      final info = rawData['info'] ?? rawData['data'] ?? rawData['list'];
      debugPrint('[🐾宠物] 检测到 Map 格式，info=$info');
      if (info is List) {
        list = info;
      } else {
        debugPrint('[🐾宠物] ❌ info 字段不是 List: ${info?.runtimeType}');
        list = [];
      }
    } else {
      debugPrint('[🐾宠物] ❌ 未知响应格式: ${rawData.runtimeType}');
      list = [];
    }

    debugPrint('[🐾宠物] 解析到 ${list.length} 只宠物');
    return list
        .map((e) => PetModel.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  /// 获取单个宠物的详细信息（含养成属性 + 背景/形象 id）
  ///
  /// [id] - 宠物的唯一 ID（业务后端 id，非 iPet 网关 petId）
  Future<Result<PetModel>> fetchPetDetail(String id) => guardResult(() async {
    // 调用 GET /sdkapi/pet/:id
    final data = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.petDetail(id),
    );
    return PetModel.fromJson(data);
  });

  // ── 更新 ──────────────────────────────────────────────

  /// 更新宠物信息（全量替换，服务端仅返回 { success }）
  ///
  /// [pet] - 修改后的宠物数据（必须包含 id 与 name）
  Future<Result<void>> updatePet(PetModel pet) => guardResult(() async {
    // PUT /sdkapi/pet/:id
    await _client.put<Map<String, dynamic>>(
      ApiEndpoints.petDetail(pet.id),
      data: pet.toJson(),
    );
  });

}

// ── Riverpod Provider ─────────────────────────────────────
/// PetRepository 的全局 Provider
///
/// 使用方式（在 Controller 的 Provider 里）：
///   final petRepositoryProvider = Provider<PetRepository>((ref) {
///     return PetRepository(ref.read(apiClientProvider));
///   });
///
/// 这样做的好处：
///   - PetRepository 的依赖（ApiClient）由 Riverpod 自动注入
///   - 测试时可以 override 这个 Provider，传入 mock 的 ApiClient
final petRepositoryProvider = Provider<PetRepository>((ref) {
  // 从全局 apiClientProvider 获取 ApiClient 实例
  // 整个 App 共享同一个 Dio 连接（保持 Token、连接池等状态）
  return PetRepository(ref.read(apiClientProvider));
});
