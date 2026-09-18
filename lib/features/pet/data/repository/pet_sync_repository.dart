/// 宠物档案更新同步；创建和删除在后台 Peer 中转内完成。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pet_model.dart';
import '../models/pet_peer_models.dart';
import 'pet_repository.dart';

class PetSyncRepository {
  final PetRepository _petRepo;

  PetSyncRepository(this._petRepo);

  /// 把 iPet 网关的 [PetInfoModel] 转成业务后端 update 请求需要的
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

  /// 编辑后的更新同步继续保留；创建和删除由 SDKAPI Peer 中转端负责。
  /// 失败只记录日志，不补建业务档案。
  Future<void> syncUpdate(PetInfoModel pet) async {
    final result = await _petRepo.updatePet(_toPetModel(pet));
    result.when(
      success: (_) => debugPrint('[宠物同步] ✅ 更新成功 petId=${pet.petId}'),
      failure: (err) =>
          debugPrint('[宠物同步] ❌ 更新失败 petId=${pet.petId}: $err'),
    );
  }

}

// ── Riverpod Provider ─────────────────────────────────────
final petSyncRepositoryProvider = Provider<PetSyncRepository>((ref) {
  return PetSyncRepository(ref.read(petRepositoryProvider));
});
