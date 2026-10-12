import 'dart:async';
import 'dart:io';
import 'collar_setup_log.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'collar_bluetooth_access.dart';
import 'collar_provisioning_protocol.dart';

class CollarBluetoothService {
  final CollarSetupLog log;
  CollarBluetoothService({CollarSetupLog? log}) : log = log ?? CollarSetupLog();
  BluetoothDevice? _device;
  bool _closed = false;

  void _checkActive() {
    if (_closed) throw const CollarProvisioningException('配网已取消');
  }

  Future<void> scan(void Function(List<ScanResult>) onResults) async {
    _checkActive();
    // Recheck silently in case access was revoked after entering the page.
    final access = await CollarBluetoothAccessCheck.check()
        .timeout(const Duration(seconds: 15));
    _checkActive();
    if (access != CollarBluetoothAccess.ready) {
      throw const CollarProvisioningException('蓝牙或权限状态已变化，请返回配网入口重新检测');
    }
    log.add('scan: start, timeout=15s');
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
      ).timeout(const Duration(seconds: 8));
      if (_closed)
        await FlutterBluePlus.stopScan().timeout(const Duration(seconds: 3));
      await FlutterBluePlus.isScanning
          .where((scanning) => !scanning)
          .first
          .timeout(const Duration(seconds: 18));
      if (scanError != null) throw scanError!;
      log.add('scan: complete');
    } finally {
      await subscription.cancel();
      await FlutterBluePlus.stopScan().timeout(const Duration(seconds: 3));
    }
  }

  Future<void> provision(BluetoothDevice device, String ssid, String password,
      void Function(String) onProgress,
      {required Future<String> Function() acquireBindToken}) async {
    _checkActive();
    _device = device;
    var stage = '连接项圈';
    void progress(String value) {
      stage = value;
      log.add('stage: $value');
      onProgress(value);
    }

    final connection = device.connectionState.listen((state) {
      log.add('connection: ${state.name}');
    });
    try {
      progress('连接项圈（最多 20 秒）');
      await device.connect(timeout: const Duration(seconds: 20), mtu: null);
      _checkActive();
      progress('协商蓝牙传输容量（最多 10 秒）');
      if (Platform.isAndroid) {
        final mtu = await device.requestMtu(247, timeout: 10);
        log.add('MTU: $mtu');
      }
      progress('识别项圈配网服务（最多 10 秒）');
      final services = await device.discoverServices(timeout: 10);
      log.add('services: count=${services.length}');
      _checkActive();
      final matching = services
          .where((s) => s.uuid == Guid(CollarProvisioningProtocol.service));
      if (matching.isEmpty) {
        throw const CollarProvisioningException('未找到项圈配网服务，请确认设备型号和固件');
      }
      final transport =
          _BleTransport(device, matching.first, _checkActive, progress, log);
      if (!matching.first.characteristics.any((c) =>
          c.uuid == Guid(CollarProvisioningProtocol.bindToken) &&
          c.properties.write)) {
        throw const CollarProvisioningException('当前固件不支持蓝牙账号绑定，请升级固件后重新配网');
      }
      progress('准备发送 WiFi 信息');
      await CollarProvisioningProtocol.send(transport, ssid, password,
          acquireBindToken: acquireBindToken);
      progress('设备已确认保存，准备检测账号绑定');
    } on CollarProvisioningException {
      rethrow;
    } catch (error) {
      log.add(
          'failed: stage=$stage type=${error.runtimeType} code=${error is FlutterBluePlusException ? error.code : null}');
      throw CollarProvisioningException('$stage 未完成，请保持项圈靠近手机后重试。');
    } finally {
      // Reboot disconnects are expected after the acknowledged CTRL write.
      try {
        await device.disconnect(timeout: 3).timeout(const Duration(seconds: 4));
      } catch (_) {}
      await connection.cancel();
      log.add('BLE cleanup complete');
      _device = null;
    }
  }

  Future<void> close() async {
    _closed = true;
    try {
      await FlutterBluePlus.stopScan().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await _device?.disconnect(timeout: 3).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
}

class _BleTransport implements CollarProvisioningTransport {
  final BluetoothDevice device;
  final BluetoothService service;
  final void Function() checkActive;
  final void Function(String) progress;
  final CollarSetupLog log;
  _BleTransport(
      this.device, this.service, this.checkActive, this.progress, this.log);

  @override
  Future<int> negotiatedMtu(int minimum) async {
    // iOS initially reports 23, then negotiates automatically.
    try {
      return await device.mtu
          .firstWhere((mtu) => mtu >= minimum)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const CollarProvisioningException('蓝牙连接的数据容量不足，请重新连接或更换手机');
    }
  }

  @override
  Future<void> write(String uuid, List<int> value) async {
    checkActive();
    final label = {
      CollarProvisioningProtocol.ssid: '发送 WiFi 名称',
      CollarProvisioningProtocol.password: '发送 WiFi 密码',
      CollarProvisioningProtocol.bindToken: '发送账号绑定凭证',
      CollarProvisioningProtocol.control: '保存配置并重启项圈',
    }[uuid]!;
    progress('$label（最多 10 秒）');
    final matches = service.characteristics.where((c) => c.uuid == Guid(uuid));
    if (matches.isEmpty || !matches.first.properties.write) {
      throw const CollarProvisioningException('项圈配网服务不完整，请检查固件后重试');
    }
    try {
      await matches.first.write(value,
          withoutResponse: false, allowLongWrite: false, timeout: 10);
      log.add('write acknowledged: $label');
    } catch (error) {
      log.add(
          'write failed: $label type=${error.runtimeType} code=${error is FlutterBluePlusException ? error.code : null} connected=${device.isConnected}');
      if (uuid == CollarProvisioningProtocol.control && !device.isConnected) {
        throw const CollarSaveUnconfirmedException();
      }
      throw CollarProvisioningException('$label 失败，请确认项圈仍在闪蓝灯后重试。');
    }
  }
}
