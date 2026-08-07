/// 设备事件模型（对应后端 GET /sdkapi/device-event/list 返回的单条）
///
/// 后端 t_device_event 表字段：id/event_type/pet_name/device_mac/device_name/
/// description/extra(JSON)/is_read/created_at
class DeviceEvent {
  final String id;
  final String type; // 'breach' / 'offline' / 'low_battery'
  final String petName;
  final String deviceMac;
  final String deviceName;
  final String deviceProductKey; // 从 extra.product_key 取，可能为空
  final String desc;
  final DateTime time;
  final bool read;

  const DeviceEvent({
    required this.id,
    required this.type,
    required this.petName,
    required this.deviceMac,
    required this.deviceName,
    required this.deviceProductKey,
    required this.desc,
    required this.time,
    required this.read,
  });

  factory DeviceEvent.fromJson(Map<String, dynamic> json) {
    // time: 后端返回毫秒时间戳
    final t = json['time'];
    final millis = t is int
        ? t
        : t is num
            ? t.toInt()
            : int.tryParse('$t') ?? 0;
    return DeviceEvent(
      id: json['id']?.toString() ?? '',
      type: (json['type'] as String?) ?? '',
      petName: (json['pet_name'] as String?) ?? '',
      deviceMac: (json['device_mac'] as String?) ?? '',
      deviceName: (json['device_name'] as String?) ?? '',
      deviceProductKey: (json['device_product_key'] as String?) ?? '',
      desc: (json['desc'] as String?) ?? '',
      time: DateTime.fromMillisecondsSinceEpoch(millis),
      read: json['read'] == true,
    );
  }
}
