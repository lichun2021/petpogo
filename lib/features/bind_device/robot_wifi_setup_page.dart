/// 机器人 WiFi 配网流程页（重构版）
/// 步骤：填写 WiFi 账号密码 → 生成二维码 → 机器人扫码自动配网 → 等待绑定成功
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/pet_toast.dart';
import '../device/data/repository/device_repository.dart';

// ── 配网步骤枚举 ──────────────────────────────────────────
enum _SetupStep { wifi, qrcode, waiting, success }

class RobotWifiSetupPage extends ConsumerStatefulWidget {
  const RobotWifiSetupPage({super.key});

  @override
  ConsumerState<RobotWifiSetupPage> createState() => _RobotWifiSetupPageState();
}

class _RobotWifiSetupPageState extends ConsumerState<RobotWifiSetupPage>
    with SingleTickerProviderStateMixin {

  _SetupStep _step = _SetupStep.wifi;

  // ── 表单 ─────────────────────────────────────────────────
  final _ssidCtrl = TextEditingController();
  final _pwdCtrl  = TextEditingController();
  final _formKey  = GlobalKey<FormState>();
  bool _pwdVisible = false;
  bool _loadingWifi = true;

  // ── 二维码 ───────────────────────────────────────────────
  String _qrData = '';

  // ── 轮询 ─────────────────────────────────────────────────
  Timer?       _pollTimer;
  int          _pollCount  = 0;
  static const _maxPoll    = 10;    // 10 轮 × 5s = 50s
  String?      _boundMac;
  Set<String>  _existingMacs = {};

  // ── 动画 ─────────────────────────────────────────────────
  late AnimationController _rotateCtrl;
  late AnimationController _progressCtrl;
  late Animation<double>   _progressAnim;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut),
    );
    _fetchCurrentWifi();
  }

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _pwdCtrl.dispose();
    _pollTimer?.cancel();
    _rotateCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  // ── 自动获取当前连接的 WiFi SSID ─────────────────
  Future<void> _fetchCurrentWifi() async {
    try {
      // Android 需要位置权限才能读取 WiFi SSID
      final locStatus = await Permission.locationWhenInUse.status;
      debugPrint('[WiFi] 位置权限状态: $locStatus');
      if (!locStatus.isGranted) {
        final result = await Permission.locationWhenInUse.request();
        debugPrint('[WiFi] 权限请求结果: $result');
        if (!result.isGranted) {
          debugPrint('[WiFi] 未授权位置权限，无法读取 SSID');
          return;
        }
      }
      final info = NetworkInfo();
      final ssid = await info.getWifiName();
      debugPrint('[WiFi] 获取到 SSID: $ssid');
      if (ssid != null && ssid.isNotEmpty && mounted) {
        final cleaned = ssid.replaceAll('"', '');
        debugPrint('[WiFi] 清洗后 SSID: $cleaned');
        setState(() => _ssidCtrl.text = cleaned);
      } else {
        debugPrint('[WiFi] SSID 为空或 null');
      }
    } catch (e) {
      debugPrint('[WiFi] 获取失败: $e');
    } finally {
      if (mounted) setState(() => _loadingWifi = false);
    }
  }

  // ── 步骤1→2 生成二维码 ───────────────────────────────────
  Future<void> _generateQr() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();
    final ssid  = _ssidCtrl.text.trim();
    final pwd   = _pwdCtrl.text;
    // 读取当前用户 token
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token') ?? '';
    final data = jsonEncode({
      'ssid': ssid,
      'password': pwd,
      'type': 'wifi_config',
      'token': token,
    });
    debugPrint('[QR] 生成二维码内容: $data');
    setState(() {
      _qrData = data;
      _step   = _SetupStep.qrcode;
    });
  }

  // ── 步骤2→3 开始等待 ──────────────────────────────────────
  Future<void> _startWaiting() async {
    HapticFeedback.mediumImpact();
    try {
      final current = await ref.read(deviceRepositoryProvider).fetchDevices();
      _existingMacs = current.map((d) => d.mac).toSet();
    } catch (_) {
      _existingMacs = {};
    }
    if (!mounted) return;
    setState(() {
      _step      = _SetupStep.waiting;
      _pollCount = 0;
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  Future<void> _poll() async {
    _pollCount++;
    // 平滑动画到新进度
    if (mounted) {
      final target = (_pollCount / _maxPoll).clamp(0.0, 1.0);
      _progressAnim = Tween<double>(
        begin: _progressAnim.value,
        end: target,
      ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));
      _progressCtrl.forward(from: 0);
      setState(() {});
    }
    if (_pollCount > _maxPoll) {
      _pollTimer?.cancel();
      if (mounted) {
        // 超时弹窗，确认后回步骤1重新填写 WiFi
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 22),
              const SizedBox(width: 8),
              Text('配网超时', style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w800)),
            ]),
            content: Text(
              '机器人未能在 50 秒内连接 WiFi\n\n请检查：\n• WiFi 名称和密码是否正确\n• 确保使用 2.4GHz 频段\n• 机器人是否已扫描二维码',
              style: TextStyle(fontFamily: AppFonts.primary, fontSize: 13, height: 1.6, color: AppColors.onSurfaceVariant),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _step      = _SetupStep.wifi;
                    _pollCount = 0;
                  });
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('重新填写 WiFi', style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }
      return;
    }
    try {
      final devices = await ref.read(deviceRepositoryProvider).fetchDevices();
      final newMac  = devices
          .map((d) => d.mac)
          .firstWhere((m) => !_existingMacs.contains(m), orElse: () => '');
      if (newMac.isNotEmpty) {
        _pollTimer?.cancel();
        await ref.read(deviceListProvider.notifier).load();
        if (mounted) {
          setState(() {
            _boundMac = newMac;
            _step     = _SetupStep.success;
          });
          HapticFeedback.heavyImpact();
        }
      }
    } catch (_) {}
  }

  void _goBack() {
    _pollTimer?.cancel();
    if (_step == _SetupStep.qrcode || _step == _SetupStep.waiting) {
      setState(() => _step = _SetupStep.wifi);
    } else {
      Navigator.pop(context);
    }
  }

  // ════════════════════════════════════════════════════════
  //  Build
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _SetupStep.wifi || _step == _SetupStep.success,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _goBack(); },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(children: [
          _buildHeader(),
          _buildStepBar(),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  // ── 顶部渐变栏 ────────────────────────────────────────────
  Widget _buildHeader() {
    const titles = ['配置 WiFi', '让机器人扫码', '等待连接', '配网成功 🎉'];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(children: [
            const SizedBox(width: 4),
            IconButton(
              onPressed: _goBack,
              icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: AppColors.onPrimary),
            ),
            Expanded(
              child: Text(
                titles[_step.index],
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── 步骤进度条 ────────────────────────────────────
  Widget _buildStepBar() {
    final labels  = ['输入WiFi', '扫码', '等待', '成功'];
    final current = _step.index;
    const circleSize = 26.0;
    return Container(
      color: AppColors.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 圆圈 + 连接线（固定高度，严格居中）──────────────
          SizedBox(
            height: circleSize,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(labels.length * 2 - 1, (i) {
                if (i.isOdd) {
                  final done = (i ~/ 2) < current;
                  return Expanded(
                    child: Container(
                      height: 2,
                      color: done ? AppColors.primary : AppColors.outlineVariant,
                    ),
                  );
                }
                final idx    = i ~/ 2;
                final done   = idx < current;
                final active = idx == current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: circleSize, height: circleSize,
                  decoration: BoxDecoration(
                    color: done || active ? AppColors.primary : AppColors.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                      : Text('${idx + 1}',
                          style: TextStyle(
                            color: active ? Colors.white : AppColors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          )),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 5),
          // ── 标签行（与圆圈对齐）────────────────────────────
          Row(
            children: List.generate(labels.length * 2 - 1, (i) {
              if (i.isOdd) return const Expanded(child: SizedBox());
              final idx    = i ~/ 2;
              final active = idx == current;
              return SizedBox(
                width: circleSize,
                child: Text(
                  labels[idx],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? AppColors.primary : AppColors.onSurfaceVariant,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }


  // ── 页面路由 ──────────────────────────────────────────────
  Widget _buildBody() {
    switch (_step) {
      case _SetupStep.wifi:    return _buildWifiForm();
      case _SetupStep.qrcode:  return _buildQrCode();
      case _SetupStep.waiting: return _buildWaiting();
      case _SetupStep.success: return _buildSuccess();
    }
  }

  // ════════════════════════════════════════════════════════
  //  步骤1：WiFi 表单
  // ════════════════════════════════════════════════════════
  Widget _buildWifiForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── 顶部图示 ─────────────────────────────────────
          Center(
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Stack(alignment: Alignment.center, children: [
                Icon(Icons.wifi_rounded, size: 52, color: AppColors.primary.withValues(alpha: 0.25)),
                Icon(Icons.smart_toy_rounded, size: 28, color: AppColors.primary),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── 标题 ─────────────────────────────────────────
          Text('连接家庭 WiFi',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              letterSpacing: -0.3,
            )),
          const SizedBox(height: 4),
          Text('请填写家中的 2.4GHz WiFi 信息（机器人不支持5GHz）',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            )),
          const SizedBox(height: 20),

          // ── WiFi SSID ────────────────────────────────────
          _Label('WiFi 名称'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _ssidCtrl,
            textInputAction: TextInputAction.next,
            style: TextStyle(fontFamily: AppFonts.primary, fontSize: 15, color: AppColors.onSurface),
            decoration: _deco(
              hint: _loadingWifi ? '正在获取当前 WiFi...' : '输入 WiFi 名称',
              icon: Icons.wifi_rounded,
              suffix: _loadingWifi
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : null,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入 WiFi 名称';
              if (v.trim().length > 32) return '不能超过 32 个字符';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── WiFi 密码 ────────────────────────────────────
          _Label('WiFi 密码'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _pwdCtrl,
            obscureText: !_pwdVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _generateQr(),
            style: TextStyle(fontFamily: AppFonts.primary, fontSize: 15, color: AppColors.onSurface),
            decoration: _deco(
              hint: '输入 WiFi 密码',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                icon: Icon(
                  _pwdVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  size: 18, color: AppColors.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _pwdVisible = !_pwdVisible),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return '请输入 WiFi 密码';
              return null;
            },
          ),
          const SizedBox(height: 6),

          // ── 粘贴密码快捷行 ──────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('如记不住密码，可从密码管理器复制后粘贴',
              style: TextStyle(fontFamily: AppFonts.primary, fontSize: 11, color: AppColors.onSurfaceVariant)),
            GestureDetector(
              onTap: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final text = data?.text ?? '';
                if (text.isNotEmpty) {
                  setState(() => _pwdCtrl.text = text);
                  _pwdCtrl.selection = TextSelection.collapsed(offset: text.length);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已粘贴密码', style: TextStyle(fontFamily: AppFonts.primary)),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('剪贴板为空', style: TextStyle(fontFamily: AppFonts.primary)),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                }
              },
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.content_paste_rounded, size: 13, color: AppColors.primary),
                const SizedBox(width: 3),
                Text('粘贴',
                  style: TextStyle(fontFamily: AppFonts.primary, fontSize: 12,
                    fontWeight: FontWeight.w600, color: AppColors.primary)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),

          // ── 提示卡 ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('仅支持 2.4GHz 频段，不支持 5GHz',
                  style: TextStyle(fontFamily: AppFonts.primary, fontSize: 12, color: AppColors.primary)),
              ),
            ]),
          ),
          const SizedBox(height: 28),


          // ── 生成二维码按钮 ────────────────────────────────
          SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton.icon(
              onPressed: _generateQr,
              icon: const Icon(Icons.qr_code_rounded, size: 20),
              label: Text('生成配网二维码',
                style: TextStyle(fontFamily: AppFonts.primary, fontSize: 15, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  步骤2：显示二维码
  // ════════════════════════════════════════════════════════
  Widget _buildQrCode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(children: [

        // ── 二维码卡片 ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(children: [
            QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: 210,
              backgroundColor: Colors.white,
              eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primary),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text('将此二维码对准机器人摄像头',
              style: TextStyle(fontFamily: AppFonts.primary, fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
            const SizedBox(height: 2),
            Text('机器人会自动扫描并连接 WiFi',
              style: TextStyle(fontFamily: AppFonts.primary, fontSize: 12, color: AppColors.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(height: 20),

        // ── 提示 ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('将机器人摄像头对准上方二维码',
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                )),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity, height: 52,
          child: FilledButton.icon(
            onPressed: _startWaiting,
            icon: const Icon(Icons.sensors_rounded, size: 20),
            label: Text('机器人已扫描，等待连接',
              style: TextStyle(fontFamily: AppFonts.primary, fontSize: 15, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════
  //  步骤3：等待上线
  // ════════════════════════════════════════════════════════
  Widget _buildWaiting() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // 旋转圈
          RotationTransition(
            turns: _rotateCtrl,
            child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                gradient: SweepGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.05), AppColors.primary],
                ),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.smart_toy_rounded, size: 38, color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Text('正在等待机器人上线',
          //   style: TextStyle(
          //     fontFamily: AppFonts.primary,
          //     fontSize: 19,
          //     fontWeight: FontWeight.w800,
          //     color: AppColors.onSurface,
          //   )),
          const SizedBox(height: 6),
          Text('机器人连接 WiFi 后会自动完成绑定\n请保持手机在附近',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
              height: 1.6,
            )),
          const SizedBox(height: 24),

          // 进度条 + 百分比（居中，平滑动画）
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (context, _) {
              final pct = (_progressAnim.value * 100).toInt();
              return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text('$pct%',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  )),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progressAnim.value,
                    minHeight: 7,
                    backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.3),
                    color: AppColors.primary,
                  ),
                ),
              ]);
            },
          ),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  步骤4：成功
  // ════════════════════════════════════════════════════════
  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                  blurRadius: 36, spreadRadius: -4,
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🤖', style: TextStyle(fontSize: 42)),
                Icon(Icons.check_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Text('配网成功！',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              letterSpacing: -0.4,
            )),
          const SizedBox(height: 8),
          Text('已连接到 ${_ssidCtrl.text.trim()}\n设备已与账号绑定',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
              height: 1.6,
            )),
          if (_boundMac != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_boundMac!,
                style: TextStyle(fontFamily: AppFonts.primary, fontSize: 11,
                    color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              icon: const Icon(Icons.home_rounded),
              label: Text('查看设备',
                style: TextStyle(fontFamily: AppFonts.primary, fontSize: 15, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: Text('继续添加设备',
              style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ]),
      ),
    );
  }

  // ── 输入框样式 ────────────────────────────────────────────
  InputDecoration _deco({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: AppFonts.primary,
        fontSize: 14,
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      prefixIcon: Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

// ── 字段标签 ──────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: TextStyle(
      fontFamily: AppFonts.primary,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.onSurfaceVariant,
    ));
}

// ── 步骤提示卡 ────────────────────────────────────────────
class _StepTips extends StatelessWidget {
  final List<String> steps;
  const _StepTips({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('操作步骤',
            style: TextStyle(fontFamily: AppFonts.primary, fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: Center(
                  child: Text('${e.key + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(e.value,
                    style: TextStyle(fontFamily: AppFonts.primary, fontSize: 13, color: AppColors.onSurface, height: 1.4)),
                ),
              ),
            ]),
          )),
        ],
      ),
    );
  }
}
