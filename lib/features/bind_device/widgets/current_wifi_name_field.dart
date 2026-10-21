import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../services/current_wifi.dart';

/// 配网时在名称输入处申请权限、重试读取，并在设置返回后自动补全。
class CurrentWifiNameField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle? style;
  final FormFieldValidator<String>? validator;

  const CurrentWifiNameField({
    super.key,
    required this.controller,
    required this.decoration,
    this.style,
    this.validator,
  });

  @override
  ConsumerState<CurrentWifiNameField> createState() =>
      _CurrentWifiNameFieldState();
}

class _CurrentWifiNameFieldState extends ConsumerState<CurrentWifiNameField>
    with WidgetsBindingObserver {
  bool _loading = false;
  bool _openingSettings = false;
  bool _retriedFromInput = false;
  int _editVersion = 0;
  CurrentWifiIssue? _issue;
  String? _settingsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.text.isEmpty) unawaited(_read());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _issue != null &&
        widget.controller.text.isEmpty) {
      // 返回时只检查，不再次弹权限框。
      unawaited(_read(requestPermission: false));
    }
  }

  Future<void> _read(
      {bool requestPermission = true, bool replace = false}) async {
    if (_loading || _openingSettings) return;
    final controller = widget.controller;
    final initialText = controller.text;
    if (!replace && initialText.isNotEmpty) return;
    final editVersion = _editVersion;
    setState(() {
      _loading = true;
      _settingsError = null;
    });
    try {
      final result = await ref
          .read(currentWifiReaderProvider)
          .read(requestPermission: requestPermission);
      if (!mounted || !identical(controller, widget.controller)) return;
      if (result.name != null &&
          editVersion == _editVersion &&
          controller.text == initialText) {
        controller.value = TextEditingValue(
            text: result.name!,
            selection: TextSelection.collapsed(offset: result.name!.length));
      }
      setState(() => _issue = result.issue);
    } catch (_) {
      if (mounted) setState(() => _issue = CurrentWifiIssue.readFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSettings() async {
    if (_loading || _openingSettings) return;
    setState(() => _openingSettings = true);
    try {
      final opened = await ref.read(currentWifiReaderProvider).openSettings();
      if (mounted && !opened) {
        setState(() => _settingsError = '请在系统设置中允许位置权限，也可手动填写 WiFi 名称');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _settingsError = '请在系统设置中允许位置权限，也可手动填写 WiFi 名称');
      }
    } finally {
      if (mounted) setState(() => _openingSettings = false);
    }
  }

  String? get _hint =>
      _settingsError ??
      switch (_issue) {
        CurrentWifiIssue.permissionDenied => '允许位置权限后可自动获取名称，也可手动填写',
        CurrentWifiIssue.permissionBlocked => '位置权限未开启，可点「去设置」允许位置和精确位置，也可手动填写',
        CurrentWifiIssue.locationDisabled => '请先打开手机的定位服务，再点「自动获取」；也可手动填写',
        CurrentWifiIssue.unavailable => '请确认手机已连接 WiFi，并已允许精确位置；也可手动填写',
        CurrentWifiIssue.readFailed => '暂时无法获取名称，可重试或手动填写',
        null => null,
      };

  @override
  Widget build(BuildContext context) {
    final blocked = _issue == CurrentWifiIssue.permissionBlocked;
    final busy = _loading || _openingSettings;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: widget.controller,
        style: widget.style,
        validator: widget.validator,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (_) => setState(() => _editVersion++),
        onTap: () {
          if (widget.controller.text.isEmpty &&
              _issue != null &&
              !_retriedFromInput &&
              !busy) {
            _retriedFromInput = true;
            unawaited(_read());
          }
        },
        decoration: widget.decoration.copyWith(
          hintText: _loading ? '正在获取当前 WiFi…' : widget.decoration.hintText,
          suffixIcon: busy
              ? const SizedBox(
                  width: AppSize.touchMin,
                  height: AppSize.touchMin,
                  child: Center(
                      child: SizedBox(
                          width: AppSpacing.x20,
                          height: AppSpacing.x20,
                          child: CircularProgressIndicator(strokeWidth: 2))))
              : TextButton(
                  onPressed:
                      blocked ? _openSettings : () => _read(replace: true),
                  child: Text(blocked ? '去设置' : '自动获取')),
        ),
      ),
      if (widget.controller.text.isEmpty && _hint != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x8),
          child: Text(_hint!,
              style: TextStyle(
                  fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
        ),
    ]);
  }
}
