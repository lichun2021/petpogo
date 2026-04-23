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
    // 调用 GET /pets，返回数组
    final data = await _client.get<List<dynamic>>(ApiEndpoints.pets);
    // 把每个 JSON Map 解析为 PetModel
    return data
        .map((e) => PetModel.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  /// 获取单个宠物的详细信息
  ///
  /// [id] - 宠物的唯一 ID（从列表页传入）
  Future<Result<PetModel>> fetchPetById(String id) => guardResult(() async {
    // 调用 GET /pets/:id
    final data = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.petDetail(id),
    );
    return PetModel.fromJson(data);
  });

  // ── 创建 ──────────────────────────────────────────────

  /// 添加新宠物
  ///
  /// [pet] - 用户填写的宠物信息（id 为空，由服务端生成）
  ///
  /// 成功后服务端会返回带有真实 id 的 PetModel
  Future<Result<PetModel>> addPet(PetModel pet) => guardResult(() async {
    // POST /pets，请求体为 pet.toJson()
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.pets,
      data: pet.toJson(), // Freezed 自动生成 toJson
    );
    // 服务端返回创建后的完整宠物数据（含真实 id）
    return PetModel.fromJson(data);
  });

  // ── 更新 ──────────────────────────────────────────────

  /// 更新宠物信息（全量替换）
  ///
  /// [pet] - 修改后的宠物数据（必须包含 id）
  Future<Result<PetModel>> updatePet(PetModel pet) => guardResult(() async {
    // PUT /pets/:id，全量替换
    final data = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.petDetail(pet.id),
      data: pet.toJson(),
    );
    return PetModel.fromJson(data);
  });

  // ── 删除 ──────────────────────────────────────────────

  /// 删除宠物
  ///
  /// [id] - 要删除的宠物 ID
  /// 成功返回 Result<void>，Controller 收到后从本地列表中移除
  Future<Result<void>> deletePet(String id) => guardResult(() async {
    // DELETE /pets/:id
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
