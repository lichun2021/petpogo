import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/peer_api_client.dart';
import '../models/pet_peer_models.dart';
import '../models/pet_share_model.dart';

/// 宠物分享Repository
/// 对接 /pet/share/* 接口（通过 PeerApiClient）
class PetShareRepository {
  final PeerApiClient _peer;
  PetShareRepository(this._peer);

  /// POST /pet/share/add — 发起宠物分享
  /// petId、deviceId、mac 三选一
  /// email 为空则匿名分享，返回口令供任何人使用
  /// type: 2=管理员, 3=成员（默认）
  Future<String> createShare({
    int? petId,
    int? deviceId,
    String? mac,
    String? email,
    int type = 3,
  }) async {
    final params = <String, dynamic>{
      if (petId != null) 'petId': petId,
      if (deviceId != null) 'deviceId': deviceId,
      if (mac != null && mac.isNotEmpty) 'mac': mac,
      if (email != null && email.isNotEmpty) 'email': email,
      'type': type,
    };

    final res = await _peer.post<Map<String, dynamic>>(
      '/pet/share/add',
      params: params,
      fromInfo: (d) => d as Map<String, dynamic>,
    );

    final order = (res.info?['order'] as String?) ?? '';
    if (order.isEmpty) {
      throw Exception('[PetShare] 口令生成失败');
    }
    return order;
  }

  /// POST /pet/share/accept — 接受宠物分享
  Future<void> acceptShare(String order) async {
    await _peer.post('/pet/share/accept', params: {'order': order});
  }

  /// POST /pet/share/refuse — 拒绝宠物分享
  Future<void> refuseShare({int? shareId, String? order}) async {
    final params = <String, dynamic>{
      if (shareId != null) 'shareId': shareId,
      if (order != null && order.isNotEmpty) 'order': order,
    };
    await _peer.post('/pet/share/refuse', params: params);
  }

  /// GET /pet/share/mylist — 我分享的列表
  Future<List<PetShareModel>> fetchMyShareList({
    int pageNo = 1,
    int pageSize = 20,
  }) async {
    final res = await _peer.get<List<dynamic>>(
      '/pet/share/mylist',
      params: {'pageNo': pageNo, 'pageSize': pageSize},
      fromInfo: (d) => d as List<dynamic>,
    );
    return (res.list ?? res.info ?? [])
        .map((e) => PetShareModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /pet/share/withme — 分享给我的列表（已接受）
  Future<List<PetShareModel>> fetchSharedWithMeList({
    int pageNo = 1,
    int pageSize = 20,
  }) async {
    final res = await _peer.get<List<dynamic>>(
      '/pet/share/withme',
      params: {'pageNo': pageNo, 'pageSize': pageSize},
      fromInfo: (d) => d as List<dynamic>,
    );
    return (res.list ?? res.info ?? [])
        .map((e) => PetShareModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /pet/share/withme — 共享给我的宠物（已接受），返回 PetInfoModel 列表
  ///
  /// 用于萌宠圈：和 /pet/info/list 合并成"可查看的宠物"。
  /// 兼容两种后端响应结构：
  ///   1. 平铺：每条记录直接是宠物字段（petId/petName/avatar/breed...）
  ///   2. 嵌套：每条记录里有个 pet 子对象
  Future<List<PetInfoModel>> fetchSharedPets({
    int pageNo = 1,
    int pageSize = 20,
  }) async {
    final res = await _peer.get<List<dynamic>>(
      '/pet/share/withme',
      params: {'pageNo': pageNo, 'pageSize': pageSize},
      fromInfo: (d) => d as List<dynamic>,
    );
    final raw = res.list ?? res.info ?? [];
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        // 如果有嵌套的 pet 字段，取它；否则用整条记录
        .map((m) {
          final pet = m['pet'];
          if (pet is Map) return pet.cast<String, dynamic>();
          return m;
        })
        // 只保留有 petId 的（确保是有效宠物）
        .where((m) => (m['petId']?.toString() ?? '').isNotEmpty)
        .map((m) => PetInfoModel.fromJson(m))
        .toList();
  }

  /// POST /pet/share/del — 删除/取消分享
  Future<void> deleteShare(int shareId) async {
    await _peer.post('/pet/share/del', params: {'shareId': shareId});
  }

  /// 查询宠物共享成员列表
  /// POST /pet/share/members
  /// 返回 owner + members 列表
  Future<List<PetMemberModel>> fetchMembers(int petId) async {
    final res = await _peer.post<Map<String, dynamic>>(
      '/pet/share/members',
      params: {'petId': petId},
      fromInfo: (d) => d as Map<String, dynamic>,
    );

    final info = res.info;
    if (info == null) return [];

    final members = <PetMemberModel>[];

    // 添加 owner
    final owner = info['owner'] as Map<String, dynamic>?;
    if (owner != null) {
      members.add(PetMemberModel(
        userId: owner['userId']?.toString() ?? '',
        userName: owner['name']?.toString() ?? '',
        userEmail: owner['account']?.toString(),
        type: '1', // owner
        joinTime: null,
      ));
    }

    // 添加 members
    final membersList = info['members'] as List<dynamic>?;
    if (membersList != null) {
      for (final m in membersList) {
        if (m is Map<String, dynamic>) {
          members.add(PetMemberModel(
            userId: m['userId']?.toString() ?? '',
            userName: m['name']?.toString() ?? '',
            userEmail: m['account']?.toString(),
            type: m['permission']?.toString() ?? '3', // 3=成员
            joinTime: m['joinTime'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    (m['joinTime'] as num).toInt())
                : null,
          ));
        }
      }
    }

    return members;
  }

  /// 移除宠物共享成员
  /// 注：此接口在文档中未明确，参考设备接口添加，实际使用时需根据后端确认
  Future<void> removeMember({
    required int petId,
    required String userId,
  }) async {
    await _peer.post(
      '/pet/share/member/remove',
      params: {'petId': petId, 'userId': userId},
    );
  }
}

final petShareRepositoryProvider = Provider<PetShareRepository>((ref) {
  return PetShareRepository(ref.watch(peerApiClientProvider));
});
