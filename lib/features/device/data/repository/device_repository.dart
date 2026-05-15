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
  Future<DeviceModel> bindDevice({required String mac, String nickname = ''}) async {
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
  /// data 字段会序列化成 JSON 字符串传给网关
  Future<void> shadowUpdate({required String mac, required Map<String, String> data}) async {
    final jsonData = '{${data.entries.map((e) => '"${e.key}":"${e.value}"').join(",")}}';
    await _peer.post('/device/shadow/update', params: {'mac': mac, 'data': jsonData});
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
  const DeviceListState({this.devices = const [], this.isLoading = false, this.errorMessage});

  DeviceListState copyWith({List<DeviceModel>? devices, bool? isLoading, String? errorMessage}) =>
      DeviceListState(
        devices:      devices      ?? this.devices,
        isLoading:    isLoading    ?? this.isLoading,
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
