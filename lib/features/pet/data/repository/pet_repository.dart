/// ════════════════════════════════════════════════════════════
///  Pet 数据仓库 — PetRepository
///
///  在架构中的位置：
///    View → Controller → [Repository] → ApiClient → 服务器
///
///  职责（只做这三件事）：
///    1. 调用 ApiClient 发起 HTTP 请求
///    2. 把响应 JSON 解析为 PetModel 数据类
///    3. 用 guardResult 包装，统一处理异常 → Result<T>
///
///  不做的事（保持单一职责）：
///    ❌ 不持有任何状态（无 state）
///    ❌ 不操作 UI（无 BuildContext）
///    ❌ 不知道 Riverpod（只接受 ApiClient 依赖注入）
/// ════════════════════════════════════════════════════════════

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

  /// 获取单个宠物的详细信息（兼容旧调用名，等价于 [fetchPetDetail]）
  Future<Result<PetModel>> fetchPetById(String id) => fetchPetDetail(id);

  // ── 创建 ──────────────────────────────────────────────

  /// 添加新宠物
  ///
  /// [pet] - 用户填写的宠物信息，[pet.id] 必须显式传入（调用方通常传
  ///         iPet 网关的 petId，让业务后端 id 与网关 id 保持一致）。
  ///         业务后端会原样落库并原样返回这个 id；若该 id 已存在，
  ///         接口报错而不覆盖已有记录（[ApiClient] 拦截器统一转为
  ///         [ApiException] 抛出，由调用方决定如何处理冲突）。
  Future<Result<PetModel>> addPet(PetModel pet) => guardResult(() async {
    assert(pet.id.isNotEmpty, 'addPet 需要显式传入 id（peer petId）');
    // POST /sdkapi/pet/create
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.petCreate,
      data: pet.toJson(),
    );
    final returnedId = data['id']?.toString() ?? '';
    final name = (data['name'] as String?) ?? pet.name;
    return pet.copyWith(id: returnedId, name: name);
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

  // ── 删除 ──────────────────────────────────────────────

  /// 删除宠物（软删除，服务端仅返回 { success }）
  ///
  /// [id] - 要删除的宠物 ID（业务后端 id）
  Future<Result<void>> deletePet(String id) => guardResult(() async {
    // DELETE /sdkapi/pet/:id
    await _client.delete(ApiEndpoints.petDetail(id));
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
