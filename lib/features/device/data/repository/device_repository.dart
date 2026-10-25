import 'package:petpogo_app/core/logging/app_log.dart';
import 'package:petpogo_app/core/providers/account_session_provider.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/peer_api_client.dart';
import '../models/device_model.dart';
import '../models/device_product_model.dart';
import '../../../../shared/utils/error_presenter.dart';

Map<String, dynamic> buildMotorControlPayload({
  required int motor0Direction,
  required int motor0Speed,
  required int motor1Direction,
  required int motor1Speed,
}) {
  void validateDirection(String name, int value) {
    if (value < 0 || value > 2) {
      throw ArgumentError.value(value, name, 'must be 0, 1, or 2');
    }
  }

  void validateSpeed(String name, int value) {
    if (value < 0 || value > 100) {
      throw RangeError.range(value, 0, 100, name);
    }
  }

  validateDirection('motor0Direction', motor0Direction);
  validateDirection('motor1Direction', motor1Direction);
  validateSpeed('motor0Speed', motor0Speed);
  validateSpeed('motor1Speed', motor1Speed);

  return {
    'motor_0': {'direction': motor0Direction, 'speed': motor0Speed},
    'motor_1': {'direction': motor1Direction, 'speed': motor1Speed},
  };
}

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

  /// GET /user/device/online/state — 在线状态（服务端只接受 GET）
  Future<bool> fetchOnlineState(String mac) async {
    final res = await _peer.get<Map<String, dynamic>>(
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

  /// POST /user/device/qr/token
  /// App 携带 Bearer 登录凭证和 SDK 签名，Body 为空表单。
  /// 服务端转发时将登录凭证放入上游 token Header；返回 info.token 为配网令牌。
  Future<DeviceQrTokenModel> createDeviceQrToken() async {
    final res = await _peer.post<DeviceQrTokenModel>(
      '/user/device/qr/token',
      fromInfo: (data) => DeviceQrTokenModel.fromJson(
        (data as Map).cast<String, dynamic>(),
      ),
    );
    final result = res.info;
    if (result == null || result.token.isEmpty || result.expireIn <= 0) {
      throw Exception('[iPet] 配网凭证无效');
    }
    return result;
  }

  /// POST /device/product/list — 产品目录，用 productKey 关联设备类型。
  Future<List<DeviceProductModel>> fetchProducts() async {
    final res = await _peer.post<List<dynamic>>(
      '/device/product/list',
      fromInfo: (data) => data is List<dynamic> ? data : const [],
    );
    final items = res.info ?? res.list ?? const <dynamic>[];
    final products = items
        .whereType<Map>()
        .map((item) => DeviceProductModel.fromJson(
              item.cast<String, dynamic>(),
            ))
        .where((product) =>
            product.isEnabled && product.productKey.trim().isNotEmpty)
        .toList(growable: false);
    AppLog.debug('[ProductList] 已加载 ${products.length} 条启用产品');
    for (final product in products) {
      AppLog.debug(
        '[ProductList] productKey=${product.productKey} '
        'alias=${product.alias} name=${product.displayName}',
      );
    }
    return products;
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
  Future<void> removeMember(
      {required String deviceId, required String userId}) async {
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
    final data = jsonEncode(buildMotorControlPayload(
      motor0Direction: motor0Direction,
      motor0Speed: motor0Speed,
      motor1Direction: motor1Direction,
      motor1Speed: motor1Speed,
    ));
    await _peer
        .post('/device/shadow/update', params: {'mac': mac, 'data': data});
  }
}

// ── Providers ────────────────────────────────────────────
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(ref.read(peerApiClientProvider));
});

// ── 设备列表 StateNotifier ────────────────────────────────
class DeviceListState {
  final List<DeviceModel> devices;
  final List<DeviceProductModel> products;
  final bool isLoading;
  final String? errorMessage;
  /// Successful unbinds stay hidden while the upstream list catches up.
  final Set<String> removedDeviceIds;
  const DeviceListState(
      {this.devices = const [],
      this.products = const [],
      this.isLoading = false,
      this.removedDeviceIds = const {},
      this.errorMessage});

  DeviceListState copyWith(
          {List<DeviceModel>? devices,
          List<DeviceProductModel>? products,
          bool? isLoading,
          Set<String>? removedDeviceIds,
          String? errorMessage}) =>
      DeviceListState(
        devices: devices ?? this.devices,
        products: products ?? this.products,
        isLoading: isLoading ?? this.isLoading,
        removedDeviceIds: removedDeviceIds ?? this.removedDeviceIds,
        errorMessage: errorMessage,
      );

  DeviceProductModel? productForKey(String productKey) {
    final normalized = productKey.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    for (final product in products) {
      if (product.productKey.trim().toUpperCase() == normalized) {
        return product;
      }
    }
    return null;
  }
}

class DeviceListNotifier extends StateNotifier<DeviceListState> {
  final DeviceRepository _repo;
  final Map<String, String> _removedDevices = {};
  int _generation = 0;
  DeviceListNotifier(this._repo) : super(const DeviceListState());

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final products = await _repo.fetchProducts();
      if (!mounted || generation != _generation) return;
      final list = await _repo.fetchDevices();
      if (!mounted || generation != _generation) return;
      final typedDevices = list
          .where((device) => !_removedDevices.containsKey(device.mac.toUpperCase()))
          .map((device) => _attachProduct(device, products))
          .toList(growable: false);
      state = state.copyWith(
        devices: typedDevices,
        products: products,
        isLoading: false,
      );
      // 再用实时接口校正在线态 + 回填成员设备缺失的 productKey
      await _enrich(typedDevices, products, generation);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(isLoading: false, errorMessage: ErrorPresenter.message(e, fallback: '设备列表加载失败，请稍后重试'));
    }
  }

  /// 列表接口对「被分享设备」可能返回 connect=false 且不含 productKey。
  /// 这里按 mac 调实时在线接口校正在线态，并对缺 productKey 的设备
  /// 用 detail 回填，避免类型判断（项圈/机器人）出错。
  Future<void> _enrich(
    List<DeviceModel> base,
    List<DeviceProductModel> products,
    int generation,
  ) async {
    final enriched = await Future.wait(base.map((d) async {
      if (d.mac.isEmpty) return d;
      var result = d;
      // 实时在线态（与 owner/member 身份无关，按 mac 查）
      try {
        final online = await _repo.fetchOnlineState(d.mac);
        result = result.copyWith(connect: online);
      } catch (_) {/* 保留列表原值 */}
      if (!mounted || generation != _generation) return result;
      // 回填 productKey（成员设备列表不含此字段）
      if (result.productKey.isEmpty) {
        try {
          final detail = await _repo.fetchDeviceDetail(d.mac);
          if (detail.productKey.isNotEmpty) {
            result = _attachProduct(
              result.copyWith(productKey: detail.productKey),
              products,
            );
          }
        } catch (_) {/* 忽略，保留未知产品类型 */}
      }
      return result;
    }));
    if (!mounted || generation != _generation) return;
    state = state.copyWith(devices: enriched);
  }

  DeviceModel _attachProduct(
    DeviceModel device,
    List<DeviceProductModel> products,
  ) {
    final normalized = device.productKey.trim().toUpperCase();
    DeviceProductModel? matched;
    for (final product in products) {
      if (product.productKey.trim().toUpperCase() == normalized) {
        matched = product;
        break;
      }
    }
    if (matched == null) {
      AppLog.debug(
        '[ProductList] 设备 ${device.mac} 未匹配产品 '
        'productKey=${device.productKey}',
      );
      return device;
    }
    return device.copyWith(
      productAlias: matched.alias,
      productTypeName: matched.displayName,
    );
  }

  void removeDevice(String mac, {String? deviceId}) {
    final key = mac.toUpperCase();
    final matching = state.devices.where((d) => d.mac.toUpperCase() == key);
    _removedDevices[key] = deviceId ?? (matching.isNotEmpty ? matching.first.deviceId : '');
    _generation++;
    state = state.copyWith(
      devices: state.devices.where((d) => d.mac.toUpperCase() != key).toList(),
      isLoading: false,
      removedDeviceIds: Set.unmodifiable(_removedDevices.values.where((id) => id.isNotEmpty)),
    );
  }

  /// An explicit successful bind may make a previously removed device visible.
  void allowDevice(String mac) {
    _removedDevices.remove(mac.toUpperCase());
    state = state.copyWith(
      removedDeviceIds: Set.unmodifiable(_removedDevices.values.where((id) => id.isNotEmpty)),
    );
  }

  /// 兜底回填产品类型：扫码绑定后，后端列表接口可能不返回 productKey，
  /// 导致设备类型识别成 unknown/机器人。这里按 mac 找到设备，强制用已知
  /// 的 productKey 关联产品目录回填 alias + productTypeName。
  void ensureProductType(String mac, String productKey) {
    final products = state.products;
    final matched = products.firstWhere(
      (p) =>
          p.productKey.trim().toUpperCase() == productKey.trim().toUpperCase(),
      orElse: () => const DeviceProductModel(
        id: 0,
        productKey: '',
        alias: '',
        name: '',
        productTypeName: '',
        status: 0,
      ),
    );
    if (matched.productKey.isEmpty) return; // 目录里没有这个 productKey
    final devices = state.devices.map((d) {
      if (d.mac != mac) return d;
      // 已经回填且一致，跳过
      if (d.productAlias == matched.alias) return d;
      return d.copyWith(
        productKey: productKey,
        productAlias: matched.alias,
        productTypeName: matched.displayName,
      );
    }).toList();
    state = state.copyWith(devices: devices);
  }
}

final deviceListProvider =
    StateNotifierProvider<DeviceListNotifier, DeviceListState>((ref) {
  ref.watch(accountSessionProvider);
  return DeviceListNotifier(ref.read(deviceRepositoryProvider));
});
