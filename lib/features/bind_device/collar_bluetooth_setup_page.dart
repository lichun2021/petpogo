import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../shared/theme/app_colors.dart';
import 'scan_qr_page.dart';
import 'services/collar_bluetooth_service.dart';
import 'services/collar_provisioning_protocol.dart';

class CollarBluetoothSetupPage extends StatefulWidget {
  final String productKey;
  const CollarBluetoothSetupPage({super.key, required this.productKey});

  @override
  State<CollarBluetoothSetupPage> createState() =>
      _CollarBluetoothSetupPageState();
}

class _CollarBluetoothSetupPageState extends State<CollarBluetoothSetupPage> {
  final _service = CollarBluetoothService();
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<ScanResult> _results = [];
  BluetoothDevice? _selected;
  bool _scanning = false;
  bool _sending = false;
  bool _sent = false;
  bool _showPassword = false;
  String? _error;
  String _progress = '';

  @override
  void dispose() {
    unawaited(_service.close());
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _results = [];
      _selected = null;
    });
    try {
      await _service.scan((results) {
        if (mounted) setState(() => _results = results);
      });
      if (mounted && _results.isEmpty) {
        setState(
            () => _error = '未找到项圈。请确认蓝灯每秒闪烁，靠近手机后重新搜索。Android 11 及以下还需打开系统定位。');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is CollarProvisioningException
            ? error.message
            : '搜索失败，请检查蓝牙和附近设备权限后重试。Android 11 及以下还需允许定位权限并打开系统定位。');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate() || _selected == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _service.provision(_selected!, _ssid.text, _password.text,
          (status) {
        if (mounted) setState(() => _progress = status);
      });
      if (mounted) {
        _password.clear();
        setState(() => _sent = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is CollarProvisioningException
            ? error.message
            : '未能确认 WiFi 信息已保存。请查看项圈指示灯：若绿灯亮起后重启，可继续扫码绑定；若仍闪蓝灯，请重试。');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _bind() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ScanQrPage(productKey: widget.productKey),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('项圈蓝牙配网'),
          automaticallyImplyLeading: !_sending,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: _sent ? _buildSent() : _buildSetup(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSetup() => [
        Icon(Icons.bluetooth_rounded, size: 54, color: AppColors.brandPrimary),
        const SizedBox(height: 16),
        Text('让项圈连接 WiFi', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text(
            '首次开机且未保存 WiFi 时，项圈会进入配网模式。重新配网请按 EN 复位键 3 次，清除原有 WiFi 信息。\n\n确认蓝灯每秒闪烁，并将项圈放在手机附近。',
            style: TextStyle(height: 1.6)),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _scanning || _sending ? null : _scan,
          icon: _scanning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search_rounded),
          label: Text(_scanning ? '正在搜索附近项圈…' : '搜索附近项圈'),
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('选择要配置的项圈'),
          ..._results.map((result) => Card(
                child: ListTile(
                  enabled: !_scanning && !_sending,
                  leading: const Icon(Icons.pets_rounded),
                  title: const Text('PetCollar07-PROV'),
                  subtitle: Text(
                      '${result.device.remoteId.str}\n信号强度 ${result.rssi} dBm'),
                  isThreeLine: true,
                  trailing: Icon(
                      _selected == result.device
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: AppColors.brandPrimary),
                  onTap: () => setState(() {
                    _selected = result.device;
                    _error = null;
                  }),
                ),
              )),
        ],
        if (_selected != null) ...[
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _ssid,
                enabled: !_sending,
                autocorrect: false,
                decoration: const InputDecoration(
                    labelText: 'WiFi 名称', prefixIcon: Icon(Icons.wifi)),
                validator: (value) =>
                    CollarProvisioningProtocol.validateSsid(value ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_sending,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'WiFi 密码',
                  helperText: '开放网络可留空，请仔细核对密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    tooltip: _showPassword ? '隐藏密码' : '显示密码',
                    icon: Icon(_showPassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                  ),
                ),
                validator: (value) =>
                    CollarProvisioningProtocol.validatePassword(value ?? ''),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.bluetooth_connected),
            label: Text(_sending ? '正在配置…' : '发送 WiFi 信息'),
          ),
        ],
        if (_sending) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(_progress),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: AppColors.error, height: 1.5)),
          TextButton(
              onPressed: () async {
                await openAppSettings();
              },
              child: const Text('打开系统权限设置')),
          if (_selected != null && !_sending)
            TextButton(onPressed: _bind, child: const Text('项圈已重启，继续扫码绑定')),
        ],
        const SizedBox(height: 24),
        const Text('如果 WiFi 密码错误，项圈不会自动重新进入配网模式，需要再次按 EN 复位键 3 次后重新配置。',
            style: TextStyle(height: 1.5)),
      ];

  List<Widget> _buildSent() => [
        const SizedBox(height: 32),
        Icon(Icons.check_circle_rounded,
            size: 80, color: AppColors.statusOnline),
        const SizedBox(height: 24),
        Text('WiFi 信息已发送',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        const Text(
            '项圈已接受配置，将亮绿灯约 2.5 秒后重启，并尝试连接 WiFi。此时蓝牙断开属于正常现象。\n\n这一步尚未确认联网，也未绑定账号。请继续扫描项圈二维码完成绑定。',
            style: TextStyle(height: 1.6)),
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: _bind,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('继续扫码绑定')),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('已绑定设备，完成配置')),
        const SizedBox(height: 20),
        const Text('若设备未上线，请核对 WiFi 和密码；需要更正时，按 EN 复位键 3 次后重新配网。',
            style: TextStyle(height: 1.5)),
      ];
}
