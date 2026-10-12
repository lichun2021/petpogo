import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/device_model.dart';

/// Confirmed BLE WiFi collars only. A product's COLLAR alias does not prove
/// WiFi support: it is also used by cellular collars. Unknown stays hidden.
final wifiCollarMacsProvider = FutureProvider<Set<String>>((ref) async {
  final preferences = await SharedPreferences.getInstance();
  return (preferences.getStringList(_key) ?? const <String>[]).toSet();
});
const _key = 'device.confirmedBleWifiCollars.v1';

String _normalize(String mac) => mac.trim().toUpperCase();

bool supportsWifiSetup(DeviceModel device, Set<String> confirmedCollars) =>
    device.isRobot ||
    (device.isCollar && confirmedCollars.contains(_normalize(device.mac)));

Future<void> rememberWifiCollar(String mac) async {
  if (mac.trim().isEmpty) return;
  final preferences = await SharedPreferences.getInstance();
  final macs = (preferences.getStringList(_key) ?? const <String>[]).toSet()
    ..add(_normalize(mac));
  if (!await preferences.setStringList(_key, macs.toList())) {
    throw StateError('Could not persist WiFi capability');
  }
}
