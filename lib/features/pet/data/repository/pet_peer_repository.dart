import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/peer_api_client.dart';
import '../models/pet_peer_models.dart';

class PetPeerRepository {
  final PeerApiClient _peer;
  PetPeerRepository(this._peer);

  // ── 宠物信息 ──────────────────────────────────────────

  /// POST /pet/info/get — 获取宠物信息
  Future<PetInfoModel> fetchPetInfo({String? mac, String? deviceId}) async {
    final params = <String, dynamic>{};
    if (mac      != null) params['mac']      = mac;
    if (deviceId != null) params['deviceId'] = deviceId;
    final res = await _peer.post<PetInfoModel>(
      '/pet/info/get',
      params: params,
      fromInfo: (d) => PetInfoModel.fromJson(d as Map<String, dynamic>),
    );
    return res.info!;
  }

  /// POST /pet/info/add — 添加宠物
  Future<void> addPet({
    required String petName,
    String? mac,
    String? deviceId,
    String? breed,
    int?    age,
    String? weight,
    String? sex,
    String? avatar,
  }) async {
    await _peer.post('/pet/info/add', params: {
      'petName': petName,
      if (mac      != null) 'mac':      mac,
      if (deviceId != null) 'deviceId': deviceId,
      if (breed    != null) 'breed':    breed,
      if (age      != null) 'age':      age.toString(),
      if (weight   != null) 'weight':   weight,
      if (sex      != null) 'sex':      sex,
      if (avatar   != null) 'avatar':   avatar,
    });
  }

  /// POST /pet/info/update — 更新宠物信息
  Future<void> updatePet({
    required String petId,
    String? petName,
    String? breed,
    int?    age,
    String? weight,
    String? sex,
    String? avatar,
  }) async {
    await _peer.post('/pet/info/update', params: {
      'petId':                petId,
      if (petName != null) 'petName': petName,
      if (breed   != null) 'breed':   breed,
      if (age     != null) 'age':     age.toString(),
      if (weight  != null) 'weight':  weight,
      if (sex     != null) 'sex':     sex,
      if (avatar  != null) 'avatar':  avatar,
    });
  }

  /// POST /pet/info/del — 删除宠物
  Future<void> deletePet({String? petId, String? deviceId}) async {
    final params = <String, dynamic>{};
    if (petId    != null) params['petId']    = petId;
    if (deviceId != null) params['deviceId'] = deviceId;
    await _peer.post('/pet/info/del', params: params);
  }

  // ── 位置 ─────────────────────────────────────────────

  /// POST /pet/position — 获取宠物位置
  Future<PetPositionModel> fetchPosition({String? mac, String? deviceId}) async {
    final params = <String, dynamic>{'lang': 'zh'};
    if (mac      != null) params['mac']      = mac;
    if (deviceId != null) params['deviceId'] = deviceId;
    final res = await _peer.post<PetPositionModel>(
      '/pet/position',
      params: params,
      fromInfo: (d) => PetPositionModel.fromJson(d as Map<String, dynamic>),
    );
    return res.info ?? const PetPositionModel();
  }

  // ── 围栏 ─────────────────────────────────────────────

  /// POST /pet/fence/list — 围栏列表（响应在 list 字段不是 info）
  Future<List<FenceModel>> fetchFences({String? mac, String? deviceId}) async {
    final params = <String, dynamic>{};
    if (mac      != null) params['mac']      = mac;
    if (deviceId != null) params['deviceId'] = deviceId;
    final res = await _peer.post<void>('/pet/fence/list', params: params);
    return (res.list ?? [])
        .map((e) => FenceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /pet/fence/add — 添加围栏
  Future<void> addFence({
    required String fenceName,
    required String longitude,
    required String latitude,
    required String radius,
    required String address,
    String? mac,
    String? deviceId,
    String? street,
    String? coordinateType,
  }) async {
    await _peer.post('/pet/fence/add', params: {
      'fenceName': fenceName,
      'longitude': longitude,
      'latitude':  latitude,
      'radius':    radius,
      'address':   address,
      if (mac             != null) 'mac':            mac,
      if (deviceId        != null) 'deviceId':       deviceId,
      if (street          != null) 'street':         street,
      if (coordinateType  != null) 'coordinateType': coordinateType,
    });
  }

  /// POST /pet/fence/update — 更新围栏
  Future<void> updateFence({
    required String fenceId,
    String? fenceName,
    String? radius,
    String? address,
  }) async {
    await _peer.post('/pet/fence/update', params: {
      'fenceId':                   fenceId,
      if (fenceName != null) 'fenceName': fenceName,
      if (radius    != null) 'radius':    radius,
      if (address   != null) 'address':   address,
    });
  }

  /// POST /pet/fence/del — 删除围栏
  Future<void> deleteFence(String fenceId) async {
    await _peer.post('/pet/fence/del', params: {'fenceId': fenceId});
  }
}

// ── Provider ─────────────────────────────────────────────
final petPeerRepositoryProvider = Provider<PetPeerRepository>((ref) {
  return PetPeerRepository(ref.read(peerApiClientProvider));
});
