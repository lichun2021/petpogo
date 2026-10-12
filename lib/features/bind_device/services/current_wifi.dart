import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// 项圈和机器人共用手机当前 WiFi 名称读取；无法读取时由用户手动填写。
Future<String?> readCurrentWifiName() async {
  final status = await Permission.locationWhenInUse.status;
  if (!status.isGranted) {
    final granted = await Permission.locationWhenInUse.request();
    if (!granted.isGranted) return null;
  }
  var name = await NetworkInfo().getWifiName();
  if (name == null) return null;
  // Android 会给 SSID 加外围引号，保留名称自身的空格和内部引号。
  if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
    name = name.substring(1, name.length - 1);
  }
  if (name.isEmpty || name == '<unknown ssid>') return null;
  return name;
}
