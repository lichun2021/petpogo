import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pet/data/repository/pet_peer_repository.dart';
import 'hardware_battery_indicator.dart';

/// 两类硬件共用的电量生命周期：进入、返回和回前台时刷新，避免回显旧缓存。
class DeviceBatteryStatus extends ConsumerStatefulWidget {
  const DeviceBatteryStatus({super.key, required this.mac});
  final String mac;

  @override
  ConsumerState<DeviceBatteryStatus> createState() =>
      _DeviceBatteryStatusState();
}

class _DeviceBatteryStatusState extends ConsumerState<DeviceBatteryStatus>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _entryReady = false;
  bool? _wasCurrent;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleRefresh(force: ref.exists(deviceBatteryProvider(widget.mac)));
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (!mounted ||
          !_entryReady ||
          ModalRoute.of(context)?.isCurrent == false ||
          (lifecycle != null && lifecycle != AppLifecycleState.resumed)) return;
      final provider = deviceBatteryProvider(widget.mac);
      if (!ref.read(provider).isLoading) ref.invalidate(provider);
    });
  }

  void _scheduleRefresh({required bool force}) {
    _entryReady = false;
    final mac = widget.mac;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.mac == mac) unawaited(_refresh(force: force));
    });
  }

  Future<void> _refresh({required bool force}) async {
    final generation = ++_generation;
    final provider = deviceBatteryProvider(widget.mac);
    if (force) ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } catch (_) {
      // 首次查询失败时保持未知，不能回显旧缓存。
    }
    if (mounted && generation == _generation)
      setState(() => _entryReady = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (_wasCurrent == false && current && _entryReady)
      _scheduleRefresh(force: true);
    _wasCurrent = current;
  }

  @override
  void didUpdateWidget(DeviceBatteryStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mac != widget.mac) {
      _generation++;
      _scheduleRefresh(force: ref.exists(deviceBatteryProvider(widget.mac)));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _entryReady &&
        ModalRoute.of(context)?.isCurrent != false) {
      setState(() => _entryReady = false);
      unawaited(_refresh(force: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(deviceBatteryProvider(widget.mac));
    final battery = _entryReady && !status.hasError ? status.valueOrNull : null;
    return HardwareBatteryIndicator(
      percent: battery?.known == true ? battery!.battery : null,
      isCharging: battery?.isCharging ?? false,
    );
  }
}
