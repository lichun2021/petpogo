/// 设备模型 — DeviceModel
/// 对应后端 GET /sdkapi/device/list 返回的单个设备数据
class DeviceModel {
  final String id;
  final String mac;
  final String name;         // 设备名称（用户自定义）
  final String bindName;     // 绑定时设置的昵称
  final bool   onlineStatus; // 0=离线 1=在线
  final String lastOnlineAt;
  final double longitude;
  final double latitude;
  final String address;
  final int    uType;        // 用户类型：1=主人 2=共享

  const DeviceModel({
    required this.id,
    this.mac = '',
    this.name = '',
    this.bindName = '',
    this.onlineStatus = false,
    this.lastOnlineAt = '',
    this.longitude = 0,
    this.latitude = 0,
    this.address = '',
    this.uType = 1,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
    id:           (json['id'] as String?) ?? '',
    mac:          (json['mac'] as String?) ?? '',
    name:         (json['name'] as String?) ?? '',
    bindName:     (json['bind_name'] as String?) ?? '',
    onlineStatus: (json['online_status'] as int?) == 1,
    lastOnlineAt: (json['last_online_at'] as String?) ?? '',
    longitude:    (json['longitude'] as num?)?.toDouble() ?? 0,
    latitude:     (json['latitude'] as num?)?.toDouble() ?? 0,
    address:      (json['address'] as String?) ?? '',
    uType:        (json['u_type'] as int?) ?? 1,
  );

  String get displayName => bindName.isNotEmpty ? bindName : name;

  @override
  String toString() => 'DeviceModel(id: $id, name: $displayName, online: $onlineStatus)';
}
