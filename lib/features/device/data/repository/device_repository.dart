import 'dart:convert';

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
      final list = await _repo.fetchDevices();
      state = state.copyWith(devices: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
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
