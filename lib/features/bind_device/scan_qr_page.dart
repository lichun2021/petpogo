import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import '../device/data/repository/device_repository.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

// ── 扫码绑定页 ────────────────────────────────────────────
class ScanQrPage extends ConsumerStatefulWidget {
  final String deviceType;
  const ScanQrPage({super.key, required this.deviceType});

  @override
  ConsumerState<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends ConsumerState<ScanQrPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanAnim;
  late MobileScannerController _cameraCtrl;

  // 状态机
  _ScanState _state = _ScanState.scanning;
  String? _scannedMac;
  String?  _errorMsg;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _cameraCtrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    _cameraCtrl.dispose();
    super.dispose();
  }

  // ── 扫描回调 ────────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    if (_state != _ScanState.scanning) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // 提取 MAC：支持纯 MAC 或 "mac=XX:XX..." 格式
    final mac = _extractMac(raw);
    if (mac == null) {
      PetToast.error(context, '二维码格式不正确，请扫设备背面标签');
      return;
    }

    HapticFeedback.mediumImpact();
    _cameraCtrl.stop();
    setState(() {
      _scannedMac = mac;
      _state      = _ScanState.found;
    });
  }

  /// 从原始字符串里提取 MAC
  String? _extractMac(String raw) {
    // 匹配 MAC 地址格式：XX:XX:XX:XX:XX:XX 或 ipet-xxx 形式
    final macReg = RegExp(r'([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}');
    final match  = macReg.firstMatch(raw);
    if (match != null) return match.group(0);

    // iPet 设备 ID 格式：ipet-xxx 直接当 mac
    final ipetReg = RegExp(r'ipet[-_][a-zA-Z0-9\-_]+');
    final ipetMatch = ipetReg.firstMatch(raw);
    if (ipetMatch != null) return ipetMatch.group(0);

    // 如果二维码内容就是纯 MAC/设备ID，长度合理就接受
    final trimmed = raw.trim();
    if (trimmed.length >= 4 && trimmed.length <= 64 && !trimmed.contains(' ')) {
      return trimmed;
    }
    return null;
  }

  // ── 调用绑定接口 ────────────────────────────────────────
  Future<void> _bindDevice() async {
    if (_scannedMac == null) return;
    setState(() => _state = _ScanState.binding);
    try {
      await ref.read(deviceRepositoryProvider).bindDevice(mac: _scannedMac!);
      // 刷新首页设备列表
      await ref.read(deviceListProvider.notifier).load();
      if (mounted) setState(() => _state = _ScanState.success);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString().replaceAll('Exception: ', '');
          _state    = _ScanState.error;
        });
      }
    }
  }

  // ── 重新扫描 ────────────────────────────────────────────
  void _retry() {
    _cameraCtrl.start();
    setState(() {
      _state      = _ScanState.scanning;
      _scannedMac = null;
      _errorMsg   = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // ── 相机画面 ───────────────────────────────────
        if (_state == _ScanState.scanning || _state == _ScanState.found)
          MobileScanner(
            controller: _cameraCtrl,
            onDetect: _onDetect,
          ),

        // 暗色遮罩（扫描框外）
        _buildMask(),

        // ── AppBar ─────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: _buildAppBar(context),
        ),

        // ── 扫描框 ─────────────────────────────────────
        Center(child: _buildScanBox()),

        // ── 底部说明 + 按钮 ────────────────────────────
        Positioned(
          left: 24, right: 24, bottom: 60,
          child: _buildBottomContent(context),
        ),
      ]),
    );
  }

  // ── 遮罩：扫描框外压暗 ──────────────────────────────────
  Widget _buildMask() {
    return CustomPaint(
      painter: _OverlayPainter(
        boxSize: 260,
        radius: 16,
        color: Colors.black.withOpacity(0.55),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(4, top, 4, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text('扫码绑定设备', textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontFamily: AppFonts.primary,
                  fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        // 手电筒
        IconButton(
          icon: ValueListenableBuilder(
            valueListenable: _cameraCtrl,
            builder: (_, value, __) => Icon(
              value.torchState == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: Colors.white,
            ),
          ),
          onPressed: () => _cameraCtrl.toggleTorch(),
        ),
      ]),
    );
  }

  // ── 扫描框 ──────────────────────────────────────────────
  Widget _buildScanBox() {
    const boxSize = 260.0;
    return SizedBox(width: boxSize, height: boxSize,
      child: Stack(children: [
        // 四角装饰
        ..._buildCorners(boxSize),
        // 扫描线（扫描中）
        if (_state == _ScanState.scanning)
          AnimatedBuilder(
            animation: _scanAnim,
            builder: (_, __) => Positioned(
              top: 4 + ((boxSize - 8) * _scanAnim.value),
              left: 4, right: 4,
              child: Container(height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, AppColors.primary, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        // 成功/绑定中状态
        if (_state == _ScanState.found || _state == _ScanState.binding || _state == _ScanState.success)
          Center(child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _state == _ScanState.success ? const Color(0xFF22C55E) : AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: _state == _ScanState.binding
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                : Icon(
                    _state == _ScanState.success ? Icons.check_rounded : Icons.qr_code_rounded,
                    color: Colors.white, size: 36),
          )),
        // 错误状态
        if (_state == _ScanState.error)
          Center(child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 36),
          )),
      ]),
    );
  }

  // ── 底部内容 ────────────────────────────────────────────
  Widget _buildBottomContent(BuildContext context) {
    switch (_state) {
      case _ScanState.scanning:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('将设备背面二维码对准扫描框',
              style: TextStyle(color: Colors.white, fontFamily: AppFonts.primary,
                  fontSize: 15, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          const Text('支持 QR 码 / MAC 地址条码',
              style: TextStyle(color: Colors.white54, fontFamily: AppFonts.primary,
                  fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          // 手动输入入口
          GestureDetector(
            onTap: () => _showManualInput(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('手动输入 MAC 地址',
                  style: TextStyle(color: Colors.white70, fontFamily: AppFonts.primary,
                      fontSize: 14), textAlign: TextAlign.center),
            ),
          ),
        ]);

      case _ScanState.found:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('已识别设备', style: TextStyle(color: Colors.white,
              fontFamily: AppFonts.primary, fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(_scannedMac ?? '', style: const TextStyle(color: Colors.white60,
              fontFamily: AppFonts.primary, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: FilledButton(
              onPressed: _bindDevice,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('确认绑定', style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: _retry,
              child: const Text('重新扫描', style: TextStyle(color: Colors.white70,
                  fontFamily: AppFonts.primary))),
        ]);

      case _ScanState.binding:
        return const Column(mainAxisSize: MainAxisSize.min, children: [
          Text('正在绑定设备...', style: TextStyle(color: Colors.white,
              fontFamily: AppFonts.primary, fontSize: 15), textAlign: TextAlign.center),
        ]);

      case _ScanState.success:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('绑定成功 🎉', style: TextStyle(color: Color(0xFF4ADE80),
              fontFamily: AppFonts.primary, fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(_scannedMac ?? '', style: const TextStyle(color: Colors.white54,
              fontFamily: AppFonts.primary, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity,
            child: FilledButton(
              onPressed: () {
                // 弹出所有绑定流程页，直接回到底部导航根页面
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('完成', style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]);

      case _ScanState.error:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_errorMsg ?? '绑定失败', style: const TextStyle(color: Color(0xFFFC8181),
              fontFamily: AppFonts.primary, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _retry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('重新扫描'),
            )),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(
              onPressed: _bindDevice,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('重试绑定'),
            )),
          ]),
        ]);
    }
  }

  // ── 手动输入 MAC ────────────────────────────────────────
  void _showManualInput(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
          decoration: BoxDecoration(
            color: const Color(0xFF1e1e2e),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('手动输入设备 MAC', style: TextStyle(color: Colors.white,
                fontFamily: AppFonts.primary, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. ipet-esp32-Device',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true, fillColor: Colors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final mac = ctrl.text.trim();
                if (mac.isEmpty) return;
                Navigator.pop(ctx);
                _cameraCtrl.stop();
                setState(() { _scannedMac = mac; _state = _ScanState.found; });
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('确认', style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w700)),
            ),
          ]),
        );
      },
    );
  }

  // ── 四角装饰 ─────────────────────────────────────────────
  List<Widget> _buildCorners(double box) {
    const size = 22.0, thick = 3.0;
    const color = AppColors.primary;
    return [
      Positioned(top: 0, left: 0,     child: _Corner(size, thick, color, topLeft: true)),
      Positioned(top: 0, right: 0,    child: _Corner(size, thick, color, topRight: true)),
      Positioned(bottom: 0, left: 0,  child: _Corner(size, thick, color, bottomLeft: true)),
      Positioned(bottom: 0, right: 0, child: _Corner(size, thick, color, bottomRight: true)),
    ];
  }
}

// ── 状态枚举 ──────────────────────────────────────────────
enum _ScanState { scanning, found, binding, success, error }

// ── 四角 Widget ───────────────────────────────────────────
class _Corner extends StatelessWidget {
  final double size, thick;
  final Color color;
  final bool topLeft, topRight, bottomLeft, bottomRight;
  const _Corner(this.size, this.thick, this.color,
      {this.topLeft = false, this.topRight = false,
       this.bottomLeft = false, this.bottomRight = false});
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size),
    painter: _CornerPainter(thick, color,
        topLeft: topLeft, topRight: topRight,
        bottomLeft: bottomLeft, bottomRight: bottomRight),
  );
}

class _CornerPainter extends CustomPainter {
  final double thick;
  final Color color;
  final bool topLeft, topRight, bottomLeft, bottomRight;
  _CornerPainter(this.thick, this.color,
      {this.topLeft = false, this.topRight = false,
       this.bottomLeft = false, this.bottomRight = false});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = thick
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final s = size.width;
    if (topLeft)    { canvas.drawLine(Offset.zero, Offset(s, 0), p); canvas.drawLine(Offset.zero, Offset(0, s), p); }
    if (topRight)   { canvas.drawLine(Offset(0, 0), Offset(s, 0), p); canvas.drawLine(Offset(s, 0), Offset(s, s), p); }
    if (bottomLeft) { canvas.drawLine(Offset(0, 0), Offset(0, s), p); canvas.drawLine(Offset(0, s), Offset(s, s), p); }
    if (bottomRight){ canvas.drawLine(Offset(0, s), Offset(s, s), p); canvas.drawLine(Offset(s, 0), Offset(s, s), p); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── 扫描框外遮罩 Painter ──────────────────────────────────
class _OverlayPainter extends CustomPainter {
  final double boxSize;
  final double radius;
  final Color color;
  const _OverlayPainter({required this.boxSize, required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final half = boxSize / 2;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half),
          Radius.circular(radius)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = color);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
