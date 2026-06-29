import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/peer_api_client.dart';
import '../models/device_model.dart';

class DeviceRepository {
  final PeerApiClient _peer;
  DeviceRepository(this._peer);

  /// POST /user/device/list — 我的设备列表
  Future<List<DeviceModel>> fetchDevices() async {
    final res = await _peer.post<List<dynamic>>(
      '/user/device/list',
      fromInfo: (d) => d as List<dynamic>,
    );
    return (res.info ?? [])
        .map((e) => DeviceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /user/device/detail — 设备详情
  Future<DeviceDetailModel> fetchDeviceDetail(String mac) async {
    final res = await _peer.post<DeviceDetailModel>(
      '/user/device/detail',
      params: {'mac': mac},
      fromInfo: (d) => DeviceDetailModel.fromJson(d as Map<String, dynamic>),
    );
    return res.info!;
  }

  /// GET /user/device/online/state — 在线状态（用 POST 模拟，实际为 GET）
  Future<bool> fetchOnlineState(String mac) async {
    final res = await _peer.post<Map<String, dynamic>>(
      '/user/device/online/state',
      params: {'mac': mac},
      fromInfo: (d) => d as Map<String, dynamic>,
    );
    return (res.info?['onlineState'] as bool?) ?? false;
  }

  /// POST /user/device/update — 更新设备昵称
  Future<void> updateDeviceName(String mac, String nickname) async {
    await _peer.post('/user/device/update',
        params: {'mac': mac, 'deviceNickName': nickname});
  }

  /// POST /user/device/unbind — 解绑设备
  Future<void> unbindDevice(String mac) async {
    await _peer.post('/user/device/unbind', params: {'mac': mac});
  }

  /// [临时日志] POST /device/product/list — 打印所有产品 productKey，用于类型绑定研究
  Future<void> debugLogProductList() async {
    try {
      final res = await _peer.post<List<dynamic>>(
        '/device/product/list',
        fromInfo: (d) => (d is List) ? d : [],
      );
      final items = res.info ?? res.list ?? [];
      debugPrint('[ProductList] 共 ${items.length} 条产品:');
      for (final item in items) {
        debugPrint('[ProductList] ${jsonEncode(item)}');
      }
      if (items.isEmpty) debugPrint('[ProductList] 列表为空或字段在 list 中');
    } catch (e) {
      debugPrint('[ProductList] 拉取失败: $e');
    }
  }

  /// POST /user/device/member/query — 查询设备共享成员列表
  /// 返回该设备下的所有被分享成员（不含主人自己）
  Future<List<DeviceMemberModel>> fetchMembers(String mac) async {
    final res = await _peer.post<List<dynamic>>(
      '/user/device/member/query',
      params: {'mac': mac},
      fromInfo: (d) => d as List<dynamic>,
    );
    return (res.info ?? [])
        .map((e) => DeviceMemberModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /user/device/member/remove — 移除共享成员
  Future<void> removeMember({required String deviceId, required String userId}) async {
    await _peer.post(
      '/user/device/member/remove',
      params: {'deviceId': deviceId, 'userId': userId},
    );
  }

  /// POST /device/share/push/add — 创建设备分享，返回口令码 order
  Future<String> createShareOrder({required String deviceId}) async {
    final res = await _peer.post<Map<String, dynamic>>(
      '/device/share/push/add',
      params: {'deviceId': deviceId, 'type': '3'},
      fromInfo: (d) => d as Map<String, dynamic>,
    );
    final order = (res.info?['order'] as String?) ?? '';
    if (order.isEmpty) {
      throw Exception('[iPet] 口令生成失败');
    }
    return order;
  }

  /// POST /user/device/accept — 接收者凭口令绑定设备
  Future<void> acceptShare(String order) async {
    await _peer.post('/user/device/accept', params: {'order': order});
  }

  /// POST /user/device/bind — 绑定设备
  Future<DeviceModel> bindDevice(
      {required String mac, String nickname = ''}) async {
    final res = await _peer.post<DeviceModel>(
      '/user/device/bind',
      params: {
        'mac': mac,
        if (nickname.isNotEmpty) 'deviceNickName': nickname,
      },
      fromInfo: (d) => DeviceModel.fromJson(d as Map<String, dynamic>),
    );
    return res.info!;
  }

  /// POST /user/device/mcuota/get — OTA 信息
  Future<OtaInfoModel> fetchOtaInfo(String mac) async {
    final res = await _peer.post<OtaInfoModel>(
      '/user/device/mcuota/get',
      params: {'mac': mac},
      fromInfo: (d) => OtaInfoModel.fromJson(d as Map<String, dynamic>),
    );
    return res.info!;
  }

  /// POST /device/shadow/update — 设备影子控制
  /// [mac]  设备 MAC
  /// [data] 键值对，如 {'led_r': 'true'} 或 {'ring_tone': '1'}
  Future<void> shadowUpdate(
      {required String mac, required Map<String, String> data}) async {
    final jsonData = jsonEncode(data);
    await _peer
        .post('/device/shadow/update', params: {'mac': mac, 'data': jsonData});
  }

  /// POST /device/shadow/update — 机器人电机控制 (PeerApiSpeed 接口)
  /// motor_0 = 左轮，motor_1 = 右轮
  /// direction: 0=停止, 1=正转(前进方向), 2=反转(后退方向)
  /// speed: 0~100 (速度百分比)
  Future<void> motorControl({
    required String mac,
    required int motor0Direction,
    required int motor0Speed,
    required int motor1Direction,
    required int motor1Speed,
  }) async {
    _validateMotorDirection('motor0Direction', motor0Direction);
    _validateMotorDirection('motor1Direction', motor1Direction);
    _validateMotorSpeed('motor0Speed', motor0Speed);
    _validateMotorSpeed('motor1Speed', motor1Speed);

    final data = jsonEncode({
      'motor_0': {
        'direction': motor0Direction,
        'speed': motor0Speed,
      },
      'motor_1': {
        'direction': motor1Direction,
        'speed': motor1Speed,
      },
    });
    await _peer
        .post('/device/shadow/update', params: {'mac': mac, 'data': data});
  }

  void _validateMotorDirection(String name, int value) {
    if (value < 0 || value > 2) {
      throw ArgumentError.value(value, name, 'must be 0, 1, or 2');
    }
  }

  void _validateMotorSpeed(String name, int value) {
    if (value < 0 || value > 100) {
      throw RangeError.range(value, 0, 100, name);
    }
  }

  /// POST /pet/agora/getToken — 获取 Agora RTC Token（同时触发 ESP32 加入频道）
  /// 返回 [AgoraTokenInfo]，包含 appId / channelName / token / userId
  Future<AgoraTokenInfo> getAgoraToken({
    required String mac,
    required String customerId,
  }) async {
    final res = await _peer.post<AgoraTokenInfo>(
      '/pet/agora/getToken',
      params: {'mac': mac, 'loginCustomerId': customerId},
      fromInfo: (d) => AgoraTokenInfo.fromJson(d as Map<String, dynamic>),
    );
    return res.info!;
  }
}

// ── Agora Token 数据模型 ──────────────────────────────────
class AgoraTokenInfo {
  final String appId;
  final String channelName;
  final String token;
  final int userId;

  const AgoraTokenInfo({
    required this.appId,
    required this.channelName,
    required this.token,
    required this.userId,
  });

  factory AgoraTokenInfo.fromJson(Map<String, dynamic> json) {
    // userId 可能是 int(10003) 或 String("10003")，兼容两种格式
    final rawId = json['userId'];
    final userId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 10001;
    return AgoraTokenInfo(
      appId: json['appId'] as String,
      channelName: json['channelName'] as String,
      token: json['token'] as String,
      userId: userId,
    );
  }
}

// ── Providers ────────────────────────────────────────────
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(ref.read(peerApiClientProvider));
});

// ── 设备列表 StateNotifier ────────────────────────────────
class DeviceListState {
  final List<DeviceModel> devices;
  final bool isLoading;
  final String? errorMessage;
  const DeviceListState(
      {this.devices = const [], this.isLoading = false, this.errorMessage});

  DeviceListState copyWith(
          {List<DeviceModel>? devices,
          bool? isLoading,
          String? errorMessage}) =>
      DeviceListState(
        devices: devices ?? this.devices,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class DeviceListNotifier extends StateNotifier<DeviceListState> {
  final DeviceRepository _repo;
  DeviceListNotifier(this._repo) : super(const DeviceListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // [临时日志] 打印产品列表，用于确认所有 productKey
      unawaited(_repo.debugLogProductList());
      final list = await _repo.fetchDevices();
      // 先展示基础列表（快速反馈）
      state = state.copyWith(devices: list, isLoading: false);
      // 再用实时接口校正在线态 + 回填成员设备缺失的 productKey
      await _enrich(list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// 列表接口对「被分享设备」可能返回 connect=false 且不含 productKey。
  /// 这里按 mac 调实时在线接口校正在线态，并对缺 productKey 的设备
  /// 用 detail 回填，避免类型判断（项圈/机器人）出错。
  Future<void> _enrich(List<DeviceModel> base) async {
    final enriched = await Future.wait(base.map((d) async {
      if (d.mac.isEmpty) return d;
      var result = d;
      // 实时在线态（与 owner/member 身份无关，按 mac 查）
      try {
        final online = await _repo.fetchOnlineState(d.mac);
        result = result.copyWith(connect: online);
      } catch (_) {/* 保留列表原值 */}
      // 回填 productKey（成员设备列表不含此字段）
      if (result.productKey.isEmpty) {
        try {
          final detail = await _repo.fetchDeviceDetail(d.mac);
          if (detail.productKey.isNotEmpty) {
            result = result.copyWith(productKey: detail.productKey);
          }
        } catch (_) {/* 忽略，回退按名称判断 */}
      }
      return result;
    }));
    if (!mounted) return;
    state = state.copyWith(devices: enriched);
  }

  void removeDevice(String mac) {
    state = state.copyWith(
      devices: state.devices.where((d) => d.mac != mac).toList(),
    );
  }
}

final deviceListProvider =
    StateNotifierProvider<DeviceListNotifier, DeviceListState>((ref) {
  return DeviceListNotifier(ref.read(deviceRepositoryProvider));
});
