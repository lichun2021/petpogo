import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../shared/theme/app_tokens.dart';
import 'services/collar_bluetooth_access.dart';
import 'widgets/collar_ui.dart';

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

  (IconData, String, String) _copy() {
    if (_error != null) {
      return (Icons.sync_problem_rounded, '暂时无法检测', _error!);
    }
    return switch (_access) {
      CollarBluetoothAccess.denied => (
          Icons.lock_outline_rounded,
          '需要蓝牙权限',
          '需要允许蓝牙或附近设备权限，才能寻找项圈。Android 11 及以下还需要定位权限。'
        ),
      CollarBluetoothAccess.bluetoothOff => (
          Icons.bluetooth_disabled_rounded,
          '请打开手机蓝牙',
          '请先在手机系统中打开蓝牙，开启后返回继续。'
        ),
      CollarBluetoothAccess.locationOff => (
          Icons.location_off_outlined,
          '请打开定位服务',
          '此版本的 Android 需要开启系统定位服务，才能搜索蓝牙设备。'
        ),
      CollarBluetoothAccess.unsupported => (
          Icons.phonelink_erase_rounded,
          '当前设备不支持',
          '请使用支持蓝牙的 Android 或 iOS 手机进行配网。'
        ),
      _ => (Icons.bluetooth_searching_rounded, '准备连接项圈', '正在检查蓝牙权限和手机蓝牙状态…'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = _copy();
    return AlertDialog(
      scrollable: true,
      icon: CollarHeroBadge(icon: icon, size: 64, busy: _busy),
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message,
            textAlign: TextAlign.center,
            style: CollarText.body.copyWith(height: 1.6)),
        const SizedBox(height: AppSpacing.x24),
        if (_access != CollarBluetoothAccess.unsupported) ...[
          CollarPrimaryButton(
              label: '重新检测',
              icon: Icons.refresh_rounded,
              onPressed: _busy ? null : () => _check(request: true)),
          const SizedBox(height: AppSpacing.x8),
        ],
        if (_access == CollarBluetoothAccess.denied) ...[
          OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillRadius)),
              onPressed: _busy
                  ? null
                  : () async {
                      await openAppSettings();
                    },
              child: const Text('打开系统权限设置')),
          const SizedBox(height: AppSpacing.x8),
        ],
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂不配网')),
      ]),
    );
  }
}
