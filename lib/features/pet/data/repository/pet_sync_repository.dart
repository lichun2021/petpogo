/// ════════════════════════════════════════════════════════════
///  宠物档案同步协调器 — PetSyncRepository
///
///  职责：
///    在 iPet 网关（peer.jxpetai.com）侧的绑定/编辑/解绑操作成功后，
///    把同样的变更同步到业务后端（api.jxpetai.com）的宠物档案。
///
///  与 PetPeerRepository / PetRepository 的关系：
///    PetPeerRepository ← UI（绑定/编辑/解绑真正生效的地方）
///           │ 成功后
///           ▼
///    PetSyncRepository（本文件）── 调用 ──▶ PetRepository ──▶ 业务后端
///
///  关键设计（详见 design.md Decision 1/2）：
///    - 业务后端 id 直接等于 iPet 网关的 petId（create 接口接受客户端
///      指定 id 并原样落库/原样返回），不需要任何本地映射表。
///    - `POST /sdkapi/pet/create` 只能由 [syncCreate] 触发，且只能在
///      peer 侧 `pet/info/add` 绑定成功之后调用一次。本类不做任何
///      "打开页面时顺便建档"的懒同步——数字宠页面等只读场景直接查
///      业务后端记录，查不到就当错误处理，绝不反向去建档。
///    - 所有业务后端调用失败都只记录日志，绝不让 peer 侧已经成功的
///      绑定/编辑/解绑操作被判定为失败。
/// ════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pet_model.dart';
import '../models/pet_peer_models.dart';
import 'pet_repository.dart';

/// 业务后端返回 400 表示传入的 id 已存在（此前已同步成功过，id 须全局唯一）。
const _kDuplicateIdStatusCode = 400;

class PetSyncRepository {
  final PetRepository _petRepo;

  PetSyncRepository(this._petRepo);

  /// 把 iPet 网关的 [PetInfoModel] 转成业务后端 create/update 请求需要的
  /// [PetModel]。业务后端 id 直接用 [PetInfoModel.petId]。
  ///
  /// 字段映射（design.md Decision 3）：
  ///   petName → name / breed → breed / sex → gender(int) / avatar → avatar
  ///   species 字段 iPet 网关未采集，默认 "other"
  ///   age/weight 不映射（单位与语义不一致，无法可靠转换，见 design.md 风险说明）
  PetModel _toPetModel(PetInfoModel pet) => PetModel(
        id: pet.petId,
        name: pet.petName,
        type: 'other',
        breed: pet.breed,
        gender: _sexToGender(pet.sex),
        avatar: pet.avatar,
        linkedDeviceId: pet.deviceId,
      );

  static String _sexToGender(String sex) {
    if (sex.startsWith('GG')) return 'male';
    if (sex.startsWith('MM')) return 'female';
    return 'unknown';
  }

  /// 绑定新宠物成功后调用：在业务后端建档。
  ///
  /// 这是本类里唯一会触发 `POST /sdkapi/pet/create` 的方法，且只应该
  /// 在 peer 侧 `pet/info/add` 绑定成功之后调用一次。
  ///
  /// 失败只记录日志，不向调用方抛出——peer 侧的绑定已经成功，
  /// 业务后端同步失败不应该让用户看到"绑定失败"。
  Future<void> syncCreate(PetInfoModel pet) async {
    final result = await _petRepo.addPet(_toPetModel(pet));
    result.when(
      success: (_) => debugPrint('[宠物同步] ✅ 建档成功 petId=${pet.petId}'),
      failure: (err) {
        if (err.statusCode == _kDuplicateIdStatusCode) {
          debugPrint('[宠物同步] ℹ️ petId=${pet.petId} 已存在，跳过');
        } else {
          debugPrint('[宠物同步] ❌ 建档失败 petId=${pet.petId}: $err');
        }
      },
    );
  }

  /// 编辑已绑定宠物成功后调用：同步更新业务后端档案。
  ///
  /// 不做懒建档——业务后端没有该记录（比如从未通过 [syncCreate] 同步
  /// 过）时更新会失败，这里只记录日志，不反向调用 create 补建。
  /// 全程失败只记录日志，不向调用方抛出。
  Future<void> syncUpdate(PetInfoModel pet) async {
    final result = await _petRepo.updatePet(_toPetModel(pet));
    result.when(
      success: (_) => debugPrint('[宠物同步] ✅ 更新成功 petId=${pet.petId}'),
      failure: (err) =>
          debugPrint('[宠物同步] ❌ 更新失败 petId=${pet.petId}: $err'),
    );
  }

  /// 解绑/删除宠物成功后调用：同步软删除业务后端档案。
  ///
  /// 业务后端从未有该记录（404）不算错误——本来就没有可删的东西。
  /// 全程失败只记录日志，不向调用方抛出。
  Future<void> syncDelete(String peerPetId) async {
    final result = await _petRepo.deletePet(peerPetId);
    result.when(
      success: (_) => debugPrint('[宠物同步] ✅ 删除成功 petId=$peerPetId'),
      failure: (err) {
        if (err.statusCode == 404) {
          debugPrint('[宠物同步] ℹ️ petId=$peerPetId 业务后端本无记录，跳过');
        } else {
          debugPrint('[宠物同步] ❌ 删除失败 petId=$peerPetId: $err');
        }
      },
    );
  }
}

// ── Riverpod Provider ─────────────────────────────────────
final petSyncRepositoryProvider = Provider<PetSyncRepository>((ref) {
  return PetSyncRepository(ref.read(petRepositoryProvider));
});
