import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petpogo_app/features/device/data/wifi_setup_capability.dart';
import 'package:petpogo_app/features/device/data/models/device_model.dart';

void main() {
  const collar =
      DeviceModel(deviceId: 'collar', mac: 'aa:bb', productAlias: 'COLLAR');
  const robot = DeviceModel(deviceId: 'robot', productAlias: 'ROBOT');
  test('cellular or unknown collars do not inherit WiFi from collar type', () {
    expect(supportsWifiSetup(collar, {}), isFalse);
    expect(supportsWifiSetup(collar, {'CC:DD'}), isFalse);
    expect(supportsWifiSetup(robot, {}), isTrue);
    expect(supportsWifiSetup(collar, {'AA:BB'}), isTrue);
  });
  test('confirmed BLE WiFi capability survives provider recreation', () async {
    SharedPreferences.setMockInitialValues({});
    await rememberWifiCollar(' aa:bb ');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final macs = await container.read(wifiCollarMacsProvider.future);
    expect(supportsWifiSetup(collar, macs), isTrue);
  });
}
