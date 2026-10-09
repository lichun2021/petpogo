import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'collar_provisioning_protocol.dart';

class CollarBluetoothService {
  BluetoothDevice? _device;
  bool _closed = false;

  void _checkActive() {
    if (_closed) throw const CollarProvisioningException('配网已取消');
  }

  Future<void> scan(void Function(List<ScanResult>) onResults) async {
    _checkActive();
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const CollarProvisioningException('请在 Android 或 iOS 手机上使用蓝牙配网');
    }
    // Disable packet logging before handling credentials.
    await FlutterBluePlus.setLogLevel(LogLevel.none);
    if (Platform.isAndroid) {
      // Request before reading adapter state (unknown without CONNECT on 12+).
      // On older Android these permissions do not apply; startScan requests
      // location there. iOS prompts via CoreBluetooth.
      await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    }
    _checkActive();
    if (!await FlutterBluePlus.isSupported) {
      throw const CollarProvisioningException('此手机不支持蓝牙');
    }
    final state = await FlutterBluePlus.adapterState
        .firstWhere((s) => s != BluetoothAdapterState.unknown)
        .timeout(const Duration(seconds: 10));
    _checkActive();
    if (state != BluetoothAdapterState.on) {
      throw const CollarProvisioningException('请开启手机蓝牙，并在系统设置中允许蓝牙权限');
    }
    Object? scanError;
    final subscription = FlutterBluePlus.onScanResults.listen((results) {
      if (!_closed) {
        onResults(results
            .where((r) =>
                r.advertisementData.advName ==
                    CollarProvisioningProtocol.deviceName ||
                r.device.platformName == CollarProvisioningProtocol.deviceName)
            .toList());
      }
    }, onError: (Object error) {
      scanError = error;
    });
    try {
      // Firmware advertises a name only; never filter by service UUID.
      await FlutterBluePlus.startScan(
        withNames: [CollarProvisioningProtocol.deviceName],
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );
      if (_closed) await FlutterBluePlus.stopScan();
      await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;
      if (scanError != null) throw scanError!;
    } finally {
      await subscription.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  Future<void> provision(BluetoothDevice device, String ssid, String password,
      void Function(String) onProgress) async {
    _checkActive();
    _device = device;
    try {
      onProgress('正在连接项圈');
      await device.connect(timeout: const Duration(seconds: 20), mtu: null);
      _checkActive();
      onProgress('正在准备蓝牙连接');
      if (Platform.isAndroid) await device.requestMtu(247);
      final services = await device.discoverServices();
      _checkActive();
      final matching = services
          .where((s) => s.uuid == Guid(CollarProvisioningProtocol.service));
      if (matching.isEmpty) {
        throw const CollarProvisioningException('未找到项圈配网服务，请确认设备型号和固件');
      }
      final transport = _BleTransport(device, matching.first, _checkActive);
      onProgress('正在发送 WiFi 信息，请保持项圈在附近');
      await CollarProvisioningProtocol.send(transport, ssid, password);
    } finally {
      // Reboot disconnects are expected after the acknowledged CTRL write.
      try {
        await device.disconnect();
      } catch (_) {}
      _device = null;
    }
  }

  Future<void> close() async {
    _closed = true;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      await _device?.disconnect();
    } catch (_) {}
  }
}

class _BleTransport implements CollarProvisioningTransport {
  final BluetoothDevice device;
  final BluetoothService service;
  final void Function() checkActive;
  _BleTransport(this.device, this.service, this.checkActive);

  @override
  Future<int> negotiatedMtu() async {
    // iOS initially reports 23, then negotiates automatically.
    try {
      return await device.mtu
          .firstWhere((mtu) => mtu >= 66)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const CollarProvisioningException('蓝牙连接的数据容量不足，请重新连接或更换手机');
    }
  }

  @override
  Future<void> write(String uuid, List<int> value) async {
    checkActive();
    final matches = service.characteristics.where((c) => c.uuid == Guid(uuid));
    if (matches.isEmpty || !matches.first.properties.write) {
      throw const CollarProvisioningException('项圈配网服务不完整，请检查固件后重试');
    }
    await matches.first
        .write(value, withoutResponse: false, allowLongWrite: false);
  }
}
