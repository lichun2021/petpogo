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
import '../../shared/theme/app_tokens.dart';
import '../../shared/widgets/pet_toast.dart';
import 'services/collar_bluetooth_service.dart';
import 'services/device_reconnect_tracker.dart';
import 'widgets/current_wifi_name_field.dart';
import 'services/provisioning_account.dart';
import 'widgets/collar_discovery_panel.dart';
import 'widgets/collar_binding_status.dart';
import 'widgets/collar_ui.dart';
import 'services/collar_provisioning_protocol.dart';

class CollarBluetoothSetupPage extends ConsumerStatefulWidget {
  final String productKey;
  final String? existingMac;
  final String? deviceName;

  /// 仅供测试注入假的蓝牙服务；正式流程使用默认实现。
  @visibleForTesting
  final CollarBluetoothService? service;
  const CollarBluetoothSetupPage(
      {super.key,
      required this.productKey,
      this.existingMac,
      this.deviceName,
      this.service});

  @override
  ConsumerState<CollarBluetoothSetupPage> createState() =>
      _CollarBluetoothSetupPageState();
}

class _CollarBluetoothSetupPageState
    extends ConsumerState<CollarBluetoothSetupPage> {
  late final CollarBluetoothService _service =
      widget.service ?? CollarBluetoothService();
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

  @override
  void initState() {
    super.initState();
    // 入口已完成权限检测，首次显示页面后直接寻找项圈。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_scan());
    });
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
        showDragHandle: true,
        builder: (_) => ListenableBuilder(
            listenable: _service.log,
            builder: (context, _) {
              final report = _service.log.entries.join('\n');
              return SafeArea(
                  child: SizedBox(
                      height: MediaQuery.sizeOf(context).height * .65,
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.x20, 0,
                              AppSpacing.x20, AppSpacing.x20),
                          child: Column(children: [
                            Row(children: [
                              Expanded(
                                  child: Text('配网诊断记录',
                                      style: CollarText.title
                                          .copyWith(fontSize: 18))),
                              TextButton(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: report));
                                    if (context.mounted) {
                                      PetToast.success(context, '日志已复制');
                                    }
                                  },
                                  child: const Text('复制日志'))
                            ]),
                            const SizedBox(height: AppSpacing.x8),
                            Expanded(
                                child: Container(
                                    width: double.infinity,
                                    padding:
                                        const EdgeInsets.all(AppSpacing.x12),
                                    decoration: BoxDecoration(
                                        color: AppColors.surfaceSunken,
                                        borderRadius: AppRadius.controlRadius),
                                    child: SingleChildScrollView(
                                        child: SelectableText(
                                            report.isEmpty ? '暂无记录' : report,
                                            style: const TextStyle(
                                                fontSize: 12, height: 1.5))))),
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
          ref
              .read(deviceListProvider.notifier)
              .allowDevice(candidates.single.mac);
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
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.x20, AppSpacing.x12, AppSpacing.x20, AppSpacing.x24),
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: _sent
                ? _buildSent()
                : _sending
                    ? _buildSending()
                    : _selected == null
                        ? _buildDiscovery()
                        : _buildWifiForm(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSending() => [
        CollarSetupSteps(current: 1, finalLabel: _finalLabel),
        CollarSendingView(
            progress: _progress,
            seconds: _seconds,
            onDetails: _showDiagnostics),
      ];

  String get _finalLabel => _reconfiguring ? '确认上线' : '完成绑定';

  Widget _reconfigNotice() => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x12),
      child: CollarNoticeCard(
          message: '正在为「${widget.deviceName ?? '项圈'}」更换 WiFi，仍绑定当前账号'));

  List<Widget> _buildDiscovery() => [
        CollarSetupSteps(current: 0, finalLabel: _finalLabel),
        if (_reconfiguring) _reconfigNotice(),
        CollarDiscoveryPanel(
            scanning: _scanning,
            foundCount: _results.length,
            error: _error,
            onSearch: _scan),
        ..._buildResults(),
      ];

  List<Widget> _buildResults() {
    if (_results.isEmpty) return const [];
    final duplicated = _results.length > 1;
    return [
      Text('附近设备 · ${_results.length}',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
      if (duplicated) ...[
        const SizedBox(height: AppSpacing.x12),
        const CollarNoticeCard(
            tone: CollarNoticeTone.warning,
            message: '发现多台同名项圈，请关闭其他项圈的配网模式后重新搜索。'),
      ],
      for (final result in _results) ...[
        const SizedBox(height: AppSpacing.x12),
        CollarDeviceTile(
            title: '宠物智能项圈',
            subtitle: duplicated ? '同名项圈，暂时无法选择' : '点击设置 WiFi',
            dimmed: duplicated,
            trailing: Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
            onTap: duplicated ? null : () => _select(result)),
      ],
    ];
  }

  void _select(ScanResult result) {
    setState(() {
      _selected = result.device;
      _error = null;
    });
    unawaited(FlutterBluePlus.stopScan()
        .timeout(const Duration(seconds: 3))
        .catchError((Object error) {
      _service.log.failure('stop scan after selection', error);
    }));
  }

  void _changeDevice() => setState(() {
        _selected = null;
        _error = null;
      });

  List<Widget> _buildWifiForm() => [
        CollarSetupSteps(current: 1, finalLabel: _finalLabel),
        if (_reconfiguring) _reconfigNotice(),
        const SizedBox(height: AppSpacing.x20),
        Text('为项圈设置 WiFi', style: CollarText.title),
        const SizedBox(height: AppSpacing.x8),
        Text(_reconfiguring ? '请输入新环境的 WiFi，完成后检查这台项圈重新上线' : '联网后，项圈将自动绑定到当前账号',
            style: CollarText.body.copyWith(height: 1.6)),
        const SizedBox(height: AppSpacing.x20),
        CollarDeviceTile(
            title: '宠物智能项圈',
            subtitle: '已选择，等待连接',
            selected: true,
            trailing:
                TextButton(onPressed: _changeDevice, child: const Text('更换'))),
        const SizedBox(height: AppSpacing.x16),
        Form(
          key: _formKey,
          child: Column(children: [
            CurrentWifiNameField(
              controller: _ssid,
              decoration: const InputDecoration(
                  labelText: 'WiFi 名称',
                  hintText: '输入 WiFi 名称',
                  prefixIcon: Icon(Icons.wifi_rounded)),
              validator: (value) =>
                  CollarProvisioningProtocol.validateSsid(value ?? ''),
            ),
            const SizedBox(height: AppSpacing.x16),
            TextFormField(
              controller: _password,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'WiFi 密码',
                helperText: '开放网络可留空，请仔细核对密码',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  tooltip: _showPassword ? '隐藏密码' : '显示密码',
                  icon: Icon(_showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                ),
              ),
              validator: (value) =>
                  CollarProvisioningProtocol.validatePassword(value ?? ''),
            ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.x16),
          CollarNoticeCard(
              tone: CollarNoticeTone.error,
              message: _error!,
              action: TextButton(
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft),
                  onPressed: _viewDevices,
                  child: const Text('项圈已重启，查看设备列表'))),
        ],
        const SizedBox(height: AppSpacing.x16),
        const CollarNoticeCard(
            tone: CollarNoticeTone.warning,
            message: '如果 WiFi 密码错误，项圈不会自动重新进入配网模式，需要再次按 EN 复位键 3 次后重新配置。'),
        const SizedBox(height: AppSpacing.x20),
        CollarPrimaryButton(
            label: _reconfiguring ? '更新 WiFi 并重新连接' : '配网并绑定账号',
            icon: Icons.bluetooth_connected_rounded,
            onPressed: _send),
      ];

  List<Widget> _buildSent() => [
        CollarSetupSteps(
            current: 2,
            completed: _bound,
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
          const SizedBox(height: AppSpacing.x24),
          CollarPrimaryButton(label: '查看我的设备', onPressed: _viewDevices),
        ] else if (!_waiting) ...[
          const SizedBox(height: AppSpacing.x16),
          CollarPrimaryButton(
              label: _reconfiguring ? '再次检查是否上线' : '再次查询绑定结果',
              onPressed: () => _beginConfirmation(saved: _saveConfirmed)),
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
