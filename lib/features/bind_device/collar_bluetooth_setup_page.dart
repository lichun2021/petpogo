import 'dart:async';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/controller/auth_controller.dart';
import '../device/data/repository/device_repository.dart';
import '../device/device_list_page.dart';
import '../device/data/wifi_setup_capability.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../shared/theme/app_colors.dart';
import 'services/collar_bluetooth_service.dart';
import 'services/device_reconnect_tracker.dart';
import 'services/current_wifi.dart';
import 'services/provisioning_account.dart';
import 'widgets/collar_discovery_panel.dart';
import 'widgets/collar_binding_status.dart';
import 'services/collar_provisioning_protocol.dart';

class CollarBluetoothSetupPage extends ConsumerStatefulWidget {
  final String productKey;
  final String? existingMac;
  final String? deviceName;
  const CollarBluetoothSetupPage(
      {super.key, required this.productKey, this.existingMac, this.deviceName});

  @override
  ConsumerState<CollarBluetoothSetupPage> createState() =>
      _CollarBluetoothSetupPageState();
}

class _CollarBluetoothSetupPageState
    extends ConsumerState<CollarBluetoothSetupPage> {
  final _service = CollarBluetoothService();
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<ScanResult> _results = [];
  BluetoothDevice? _selected;
  bool _scanning = false;
  bool _loadingWifi = false;
  bool _wifiNameEdited = false;
  bool _sending = false;
  bool _sent = false;
  bool _showPassword = false;
  String? _error;
  String _progress = '';
  bool _waiting = false;
  bool _bound = false;
  String? _bindingError;
  int _attempt = 0;
  Timer? _ticker;
  int _seconds = 0;
  int _pollCount = 0;
  bool _saveConfirmed = false;
  Set<String> _existingMacs = {};
  String? _accountUserId;
  String? _boundDevice;
  DeviceReconnectTracker? _reconnect;
  bool get _reconfiguring => widget.existingMac != null;

  Future<void> _fillCurrentWifi() async {
    if (_loadingWifi || _wifiNameEdited || _ssid.text.isNotEmpty) return;
    setState(() => _loadingWifi = true);
    try {
      final name = await readCurrentWifiName();
      if (mounted &&
          !_sending &&
          !_wifiNameEdited &&
          _ssid.text.isEmpty &&
          name != null) {
        _ssid.text = name;
      }
    } catch (error) {
      _service.log.failure('read current WiFi', error);
    } finally {
      if (mounted) setState(() => _loadingWifi = false);
    }
  }

  void _startClock() {
    _ticker?.cancel();
    _seconds = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _status(String value) {
    _service.log.add(value);
    if (mounted) setState(() => _progress = value);
  }

  void _showDiagnostics() {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => ListenableBuilder(
            listenable: _service.log,
            builder: (context, _) {
              final report = _service.log.entries.join('\n');
              return SafeArea(
                  child: SizedBox(
                      height: MediaQuery.sizeOf(context).height * .65,
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(children: [
                            Row(children: [
                              const Expanded(
                                  child: Text('配网诊断记录',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700))),
                              TextButton(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: report));
                                  },
                                  child: const Text('复制日志'))
                            ]),
                            const SizedBox(height: 8),
                            Expanded(
                                child: SingleChildScrollView(
                                    child: SelectableText(
                                        report.isEmpty ? '暂无记录' : report,
                                        style: const TextStyle(
                                            fontSize: 12, height: 1.5)))),
                          ]))));
            }));
  }

  void _beginConfirmation({required bool saved}) {
    _saveConfirmed = saved;
    _password.clear();
    setState(() {
      _sent = true;
      _sending = false;
      _waiting = true;
      _bindingError = null;
    });
    _startClock();
    unawaited(_waitForBinding(_existingMacs, _accountUserId));
  }

  void _checkAccount(String? accountUserId) {
    if (!mounted ||
        !isProvisioningAccount(
            accountUserId, ref.read(authControllerProvider).user?.id)) {
      throw const CollarProvisioningException('登录状态已变化，请重新开始配网');
    }
  }

  Future<void> _waitForBinding(
      Set<String> existingMacs, String? accountUserId) async {
    final attempt = ++_attempt;
    _pollCount = 0;
    _status(_reconfiguring ? '正在等待目标项圈重新上线' : '正在等待项圈联网，开始查询账号设备列表');
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    final repository = ref.read(deviceRepositoryProvider);
    while (
        mounted && attempt == _attempt && DateTime.now().isBefore(deadline)) {
      try {
        _checkAccount(accountUserId);
        final remaining = deadline.difference(DateTime.now());
        _pollCount++;
        _status('第 $_pollCount 次查询绑定结果');
        final devices = await repository.fetchDevices().timeout(
            remaining < const Duration(seconds: 8)
                ? remaining
                : const Duration(seconds: 8));
        _service.log.add('poll #$_pollCount: devices=${devices.length}');
        if (!mounted || attempt != _attempt) return;
        _checkAccount(accountUserId);
        if (!DateTime.now().isBefore(deadline)) break;
        if (_reconfiguring) {
          final target = devices.where((device) =>
              device.mac.toUpperCase() == widget.existingMac!.toUpperCase() &&
              device.isOwner &&
              !device.isShared);
          if (target.isEmpty)
            throw const CollarProvisioningException('当前账号已无法管理此项圈，请返回设备列表核对');
          final remainingForDetail = deadline.difference(DateTime.now());
          if (remainingForDetail <= Duration.zero) break;
          final detail = await repository
              .fetchDeviceDetail(widget.existingMac!)
              .timeout(remainingForDetail < const Duration(seconds: 8)
                  ? remainingForDetail
                  : const Duration(seconds: 8));
          if (!mounted || attempt != _attempt) return;
          _checkAccount(accountUserId);
          if (!DateTime.now().isBefore(deadline)) break;
          _service.log.add(
              'target reconnect: online=${detail.onlineStatus} lastOnline=${detail.lastOnlineTime}');
          if (_reconnect!.observe(
              online: detail.onlineStatus,
              lastOnlineTime: detail.lastOnlineTime)) {
            _ticker?.cancel();
            _boundDevice = target.single.displayName;
            _status('目标项圈已重新上线，账号绑定仍有效');
            unawaited(ref.read(deviceListProvider.notifier).load());
            setState(() {
              _waiting = false;
              _bound = true;
            });
            return;
          }
          _status('尚未确认目标项圈重新上线，3 秒后继续检查');
          await Future<void>.delayed(const Duration(seconds: 3));
          continue;
        }
        final candidates = devices
            .where((device) =>
                device.mac.isNotEmpty &&
                !existingMacs.contains(device.mac.toUpperCase()) &&
                device.isOwner &&
                !device.isShared &&
                (device.isCollar ||
                    device.productKey.toUpperCase() ==
                        widget.productKey.toUpperCase()))
            .toList();
        _service.log
            .add('poll #$_pollCount: new owned collars=${candidates.length}');
        if (candidates.isEmpty) _status('尚未发现新绑定项圈，3 秒后继续检查');
        if (candidates.length > 1) {
          _ticker?.cancel();
          setState(() {
            _waiting = false;
            _bindingError = '账号下同时出现多台新项圈，无法确认本次设备。请在设备列表核对，并一次只配置一台项圈。';
          });
          return;
        }
        if (candidates.length == 1) {
          _ticker?.cancel();
          try {
            await rememberWifiCollar(candidates.single.mac);
            if (!mounted || attempt != _attempt) return;
            ref.invalidate(wifiCollarMacsProvider);
          } catch (error) {
            _service.log.failure('save WiFi capability', error);
          }
          if (!mounted || attempt != _attempt) return;
          _boundDevice = candidates.single.displayName;
          _status('账号已确认绑定成功');
          unawaited(ref.read(deviceListProvider.notifier).load());
          setState(() {
            _waiting = false;
            _bound = true;
          });
          return;
        }
      } on CollarProvisioningException catch (error) {
        if (mounted && attempt == _attempt) {
          _ticker?.cancel();
          setState(() {
            _waiting = false;
            _bindingError = error.message;
          });
        }
        return;
      } catch (error) {
        if (!mounted || attempt != _attempt) return;
        _service.log.failure('poll #$_pollCount', error);
        _status('设备列表查询失败，正在重试；请检查手机网络');
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    if (mounted && attempt == _attempt) {
      _ticker?.cancel();
      _status('绑定检测超时：尚未确认结果');
      setState(() {
        _waiting = false;
        _bindingError = _reconfiguring
            ? '新 WiFi 配置已发送，但尚未确认这台项圈重新上线。请检查 WiFi 和密码，或稍后再次查询；无需解绑设备。'
            : '等待绑定超时，尚未在账号下确认新项圈。请检查 WiFi 名称和密码，或手机网络。已绑定的项圈不会重复新增，可先查看设备列表。也可再次查询；确认未绑定时，请连续按复位键 3 次，确认蓝灯闪烁后重新配网。';
      });
    }
  }

  void _viewDevices() => Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DeviceListPage()));

  @override
  void dispose() {
    _attempt++;
    _ticker?.cancel();
    unawaited(_service.close());
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_scanning) return;
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
      _service.log.add('scan results: ${_results.length} matching collars');
      if (mounted && _results.isEmpty) {
        setState(() => _error = '暂未发现项圈，请确认蓝灯闪烁，并将项圈靠近手机后重新搜索。');
      }
    } catch (error) {
      if (mounted) {
        _service.log.failure('operation', error);
        setState(() => _error = error is CollarProvisioningException
            ? error.message
            : '搜索暂时中断，请重试。若蓝牙或权限已关闭，请返回配网入口重新检测。');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate() || _selected == null) return;
    if (_sending) return;
    _startClock();
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    final accountUserId = ref.read(authControllerProvider).user?.id;
    _accountUserId = accountUserId;
    try {
      final repository = ref.read(deviceRepositoryProvider);
      Set<String> existingMacs = {};
      if (accountUserId == null || accountUserId.isEmpty) {
        throw const CollarProvisioningException('请先登录账号，再进行蓝牙绑定');
      }
      _status('正在读取账号设备列表（最多 15 秒）');
      // A fresh snapshot is required; stale cache could misidentify a device.
      try {
        final current = await repository
            .fetchDevices()
            .timeout(const Duration(seconds: 15));
        existingMacs =
            current.map((device) => device.mac.toUpperCase()).toSet();
        if (_reconfiguring) {
          final owned = current.where((device) =>
              device.mac.toUpperCase() == widget.existingMac!.toUpperCase() &&
              device.isOwner &&
              !device.isShared);
          if (owned.isEmpty)
            throw const CollarProvisioningException('仅设备主人可以重新配网，请核对当前账号');
          final detail = await repository
              .fetchDeviceDetail(widget.existingMac!)
              .timeout(const Duration(seconds: 10));
          _reconnect = DeviceReconnectTracker(
              initiallyOnline: detail.onlineStatus,
              previousLastOnlineTime: detail.lastOnlineTime,
              startedAt: DateTime.now().millisecondsSinceEpoch);
        }
      } on CollarProvisioningException {
        rethrow;
      } catch (error) {
        _service.log.failure('device snapshot', error);
        throw const CollarProvisioningException('无法获取当前设备列表，请检查手机网络后重试');
      }
      _existingMacs = existingMacs;
      _service.log.add('snapshot: ${existingMacs.length} devices');
      _checkAccount(accountUserId);
      if (!mounted) return;
      await _service.provision(_selected!, _ssid.text, _password.text,
          (status) {
        if (mounted) setState(() => _progress = status);
      }, acquireBindToken: () async {
        _checkAccount(accountUserId);
        _status('正在获取一次性绑定凭证（最多 15 秒）');
        try {
          final credential = await repository
              .createDeviceQrToken()
              .timeout(const Duration(seconds: 15));
          _checkAccount(accountUserId);
          _service.log.add(
              'bind credential received: expiresIn=${credential.expireIn}s');
          return credential.token;
        } on CollarProvisioningException {
          rethrow;
        } catch (error) {
          _service.log.failure('bind credential', error);
          throw const CollarProvisioningException('获取绑定凭证失败，请检查登录状态和手机网络后重试');
        }
      });
      if (mounted) _beginConfirmation(saved: true);
    } on CollarSaveUnconfirmedException {
      _service.log.add(
          'save response missing after disconnect; checking server instead');
      if (mounted) _beginConfirmation(saved: false);
    } catch (error) {
      if (mounted) {
        _service.log.failure('operation', error);
        setState(() => _error = error is CollarProvisioningException
            ? error.message
            : '未能确认配置已保存。若项圈已亮绿灯并重启，请先查看设备列表确认绑定；否则确认蓝灯闪烁后重试。');
      }
    } finally {
      if (!_waiting) _ticker?.cancel();
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Text(_reconfiguring ? '更换项圈 WiFi' : '项圈蓝牙配网'),
          automaticallyImplyLeading: !_sending,
          actions: [
            IconButton(
                onPressed: _showDiagnostics,
                tooltip: '配网诊断记录',
                icon: const Icon(Icons.receipt_long_outlined))
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            physics: const ClampingScrollPhysics(),
            children: _sent
                ? _buildSent()
                : _sending
                    ? _buildSending()
                    : _buildSetup(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSending() => [
        const CollarSetupSteps(current: 1),
        const SizedBox(height: 24),
        Icon(Icons.bluetooth_connected,
            size: 52, color: AppColors.brandPrimary),
        const SizedBox(height: 20),
        const Text('正在为项圈配网',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Text(_progress,
            textAlign: TextAlign.center, style: const TextStyle(height: 1.6)),
        const SizedBox(height: 16),
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text('已用时 $_seconds 秒', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        const Text('请将项圈保持在手机附近。配置保存后，将自动检测账号绑定结果。',
            textAlign: TextAlign.center, style: TextStyle(height: 1.6)),
        TextButton(onPressed: _showDiagnostics, child: const Text('查看详细进度')),
      ];

  List<Widget> _buildSetup() => [
        CollarSetupSteps(
            current: _selected == null ? 0 : 1,
            finalLabel: _reconfiguring ? '确认上线' : '完成绑定'),
        if (_reconfiguring)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('正在为「${widget.deviceName ?? '项圈'}」更换 WiFi，仍绑定当前账号',
                  style: const TextStyle(fontSize: 13))),
        if (_selected == null)
          CollarDiscoveryPanel(
              scanning: _scanning,
              foundCount: _results.length,
              onSearch: _sending ? null : _scan),
        if (_selected != null) ...[
          const SizedBox(height: 16),
          Text('为项圈设置 WiFi', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
              _reconfiguring
                  ? '请输入新环境的 WiFi，完成后检查这台项圈重新上线'
                  : '联网后，项圈将自动绑定到当前账号',
              style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.6)),
          const SizedBox(height: 20),
          Container(
              decoration: BoxDecoration(
                  color: AppColors.brandPrimarySoft,
                  borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                  leading: Icon(Icons.bluetooth_rounded,
                      color: AppColors.brandPrimary),
                  title: const Text('宠物智能项圈'),
                  subtitle: const Text('已选择，等待连接'),
                  trailing: TextButton(
                      onPressed: _sending
                          ? null
                          : () => setState(() => _selected = null),
                      child: const Text('更换')))),
        ],
        if (_selected == null && _results.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('附近设备 · ${_results.length}',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if (_results.length > 1) const Text('发现多台同名项圈，请关闭其他项圈的配网模式后重新搜索。'),
          ..._results.map((result) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(top: 12),
                color: AppColors.surfaceCard,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                        color: AppColors.brandPrimary.withValues(alpha: 0.18))),
                child: ListTile(
                  enabled: !_sending && _results.length == 1,
                  leading: const Icon(Icons.bluetooth_rounded),
                  title: const Text('宠物智能项圈',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('点击设置 WiFi'),
                  trailing: Icon(
                      _selected == result.device
                          ? Icons.check_circle
                          : Icons.chevron_right_rounded,
                      color: AppColors.brandPrimary),
                  onTap: () {
                    setState(() {
                      _selected = result.device;
                      _error = null;
                    });
                    unawaited(_fillCurrentWifi());
                    unawaited(FlutterBluePlus.stopScan()
                        .timeout(const Duration(seconds: 3))
                        .catchError((Object error) {
                      _service.log.failure('stop scan after selection', error);
                    }));
                  },
                ),
              )),
        ],
        if (_selected != null) ...[
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _ssid,
                onChanged: (_) => _wifiNameEdited = true,
                enabled: !_sending,
                autocorrect: false,
                decoration: InputDecoration(
                    labelText: 'WiFi 名称',
                    hintText: _loadingWifi ? '正在获取当前 WiFi…' : '输入 WiFi 名称',
                    prefixIcon: const Icon(Icons.wifi)),
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
            label: Text(_sending
                ? '正在配置…'
                : _reconfiguring
                    ? '更新 WiFi 并重新连接'
                    : '配网并绑定账号'),
          ),
        ],
        if (_sending) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text('$_progress · 已用时 $_seconds 秒'),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: AppColors.error, height: 1.5)),
          if (_selected != null && !_sending)
            TextButton(
                onPressed: _viewDevices, child: const Text('项圈已重启，查看设备列表')),
        ],
        if (_selected != null) const SizedBox(height: 12),
        if (_selected != null)
          const Text('如果 WiFi 密码错误，项圈不会自动重新进入配网模式，需要再次按 EN 复位键 3 次后重新配置。',
              style: TextStyle(height: 1.5)),
      ];

  List<Widget> _buildSent() => [
        CollarSetupSteps(
            current: 2,
            finalLabel: _reconfiguring
                ? '确认上线'
                : _bound
                    ? '完成绑定'
                    : '确认绑定'),
        CollarBindingStatus(
            bound: _bound,
            waiting: _waiting,
            saved: _saveConfirmed,
            reconfiguring: _reconfiguring,
            seconds: _seconds,
            deviceName: _boundDevice,
            error: _bindingError,
            queryFailed: _progress.contains('查询失败')),
        if (_bound) ...[
          const SizedBox(height: 24),
          FilledButton(onPressed: _viewDevices, child: const Text('查看我的设备')),
        ] else if (!_waiting) ...[
          const SizedBox(height: 16),
          FilledButton(
              onPressed: () => _beginConfirmation(saved: _saveConfirmed),
              child: Text(_reconfiguring ? '再次检查是否上线' : '再次查询绑定结果')),
          TextButton(onPressed: _viewDevices, child: const Text('去设备列表核对')),
          TextButton(
              onPressed: () => setState(() {
                    _attempt++;
                    _sent = false;
                    _bound = false;
                    _waiting = false;
                    _bindingError = null;
                    _selected = null;
                    _results = [];
                    _error = null;
                  }),
              child: const Text('修改 WiFi，重新配网')),
        ],
      ];
}
