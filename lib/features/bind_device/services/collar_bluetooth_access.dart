import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum CollarBluetoothAccess {
  ready,
  denied,
  bluetoothOff,
  locationOff,
  unsupported
}

abstract final class CollarBluetoothAccessCheck {
  static const _platform = MethodChannel('petpogo/bluetooth_access');

  static Future<CollarBluetoothAccess> check({bool request = false}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return CollarBluetoothAccess.unsupported;
    }
    final sdk = Platform.isAndroid
        ? await _platform.invokeMethod<int>('androidSdkInt')
        : null;
    if (Platform.isAndroid && sdk == null) {
      throw StateError('Android version unavailable');
    }
    final legacyAndroid = Platform.isAndroid && sdk! < 31;
    final permissions = Platform.isIOS
        ? [Permission.bluetooth]
        : legacyAndroid
            ? [Permission.locationWhenInUse]
            : [Permission.bluetoothScan, Permission.bluetoothConnect];
    for (final permission in permissions) {
      var status = await permission.status;
      if (!status.isGranted &&
          request &&
          !status.isPermanentlyDenied &&
          !status.isRestricted) {
        status = await permission.request();
      }
      if (!status.isGranted) return CollarBluetoothAccess.denied;
    }
    if (legacyAndroid &&
        !await Permission.locationWhenInUse.serviceStatus.isEnabled) {
      return CollarBluetoothAccess.locationOff;
    }
    await FlutterBluePlus.setLogLevel(LogLevel.none);
    if (!await FlutterBluePlus.isSupported) {
      return CollarBluetoothAccess.unsupported;
    }
    final adapter = await FlutterBluePlus.adapterState
        .firstWhere((state) =>
            state != BluetoothAdapterState.unknown &&
            state != BluetoothAdapterState.turningOn)
        .timeout(const Duration(seconds: 8));
    return adapter == BluetoothAdapterState.on
        ? CollarBluetoothAccess.ready
        : CollarBluetoothAccess.bluetoothOff;
  }
}
