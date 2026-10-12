import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../shared/theme/app_colors.dart';
import 'services/collar_bluetooth_access.dart';

/// Keeps permission requests and settings recovery at the mode-selection entry.
class CollarBluetoothAccessDialog extends StatefulWidget {
  const CollarBluetoothAccessDialog(
      {super.key, this.check = CollarBluetoothAccessCheck.check});
  final Future<CollarBluetoothAccess> Function({bool request}) check;
  @override
  State<CollarBluetoothAccessDialog> createState() =>
      _CollarBluetoothAccessDialogState();
}

class _CollarBluetoothAccessDialogState
    extends State<CollarBluetoothAccessDialog> with WidgetsBindingObserver {
  bool _busy = false;
  CollarBluetoothAccess? _access;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check(request: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _check();
  }

  Future<void> _check({bool request = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final access = await widget.check(request: request);
      if (!mounted) return;
      if (access == CollarBluetoothAccess.ready) {
        Navigator.pop(context, true);
        return;
      }
      setState(() => _access = access);
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法检测蓝牙状态，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _error ??
        switch (_access) {
          CollarBluetoothAccess.denied =>
            '需要允许蓝牙或附近设备权限，才能寻找项圈。Android 11 及以下还需要定位权限。',
          CollarBluetoothAccess.bluetoothOff => '请先在手机系统中打开蓝牙，开启后返回继续。',
          CollarBluetoothAccess.locationOff =>
            '此版本的 Android 需要开启系统定位服务，才能搜索蓝牙设备。',
          CollarBluetoothAccess.unsupported => '请使用支持蓝牙的 Android 或 iOS 手机进行配网。',
          _ => '正在检查蓝牙权限和手机蓝牙状态…',
        };
    return AlertDialog(
      icon: Icon(Icons.bluetooth_rounded,
          color: AppColors.brandPrimary, size: 36),
      title: const Text('准备连接项圈'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, style: const TextStyle(height: 1.6)),
        if (_busy) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator()
        ],
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂不配网')),
        if (!_busy && _access == CollarBluetoothAccess.denied)
          TextButton(
              onPressed: () async {
                await openAppSettings();
              },
              child: const Text('打开系统权限设置')),
        if (!_busy && _access != CollarBluetoothAccess.unsupported)
          FilledButton(
              onPressed: () => _check(request: true),
              child: const Text('重新检测')),
      ],
    );
  }
}
