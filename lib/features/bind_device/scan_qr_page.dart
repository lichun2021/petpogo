import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_colors.dart';

class ScanQrPage extends StatefulWidget {
  final String deviceType;
  const ScanQrPage({super.key, required this.deviceType});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> with SingleTickerProviderStateMixin {
  bool _found = false;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  void _simulateFound() {
    setState(() => _found = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(widget.deviceType),
        leading: BackButton(color: Colors.white, onPressed: () => context.pop()),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 相机占位（实际用 mobile_scanner）
          Container(
            color: const Color(0xFF1A1A1A),
            child: const Center(
              child: Icon(Icons.camera_alt, size: 80, color: Colors.white24),
            ),
          ),

          // 扫描框
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 240, height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // 角标
                      ..._buildCorners(),
                      // 扫描线
                      if (!_found)
                        AnimatedBuilder(
                          animation: _scanController,
                          builder: (_, __) => Positioned(
                            top: 4 + (230 * _scanController.value),
                            left: 4, right: 4,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, AppColors.primary, Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 成功状态
                      if (_found)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 40),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _found ? '已找到二维码' : '请将设备背面二维码对准框内',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                if (!_found) ...[
                  const SizedBox(height: 4),
                  const Text('设备背面查看二维码',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ],
            ),
          ),

          // 底部按钮
          Positioned(
            left: 20, right: 20, bottom: 60,
            child: _found
                ? ElevatedButton(
                    onPressed: () {
                      context.go('/');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${widget.deviceType} 绑定成功！'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('已找到二维码，完成绑定', style: TextStyle(fontSize: 16)),
                  )
                : TextButton(
                    onPressed: _simulateFound,
                    child: const Text('模拟扫描成功（测试用）',
                      style: TextStyle(color: Colors.white60)),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 20.0;
    const thick = 3.0;
    const color = AppColors.primary;

    return [
      Positioned(top: 0, left: 0, child: _Corner(size, thick, color, [BorderSide.none, BorderSide.none, BorderSide.none, BorderSide.none], topLeft: true)),
      Positioned(top: 0, right: 0, child: _Corner(size, thick, color, [], topRight: true)),
      Positioned(bottom: 0, left: 0, child: _Corner(size, thick, color, [], bottomLeft: true)),
      Positioned(bottom: 0, right: 0, child: _Corner(size, thick, color, [], bottomRight: true)),
    ];
  }
}

class _Corner extends StatelessWidget {
  final double size;
  final double thick;
  final Color color;
  final List<BorderSide> sides;
  final bool topLeft, topRight, bottomLeft, bottomRight;

  const _Corner(this.size, this.thick, this.color, this.sides,
      {this.topLeft = false, this.topRight = false, this.bottomLeft = false, this.bottomRight = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CornerPainter(thick, color, topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double thick;
  final Color color;
  final bool topLeft, topRight, bottomLeft, bottomRight;

  _CornerPainter(this.thick, this.color, {this.topLeft = false, this.topRight = false, this.bottomLeft = false, this.bottomRight = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = thick..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final s = size.width;

    if (topLeft) {
      canvas.drawLine(const Offset(0, 0), Offset(s, 0), paint);
      canvas.drawLine(const Offset(0, 0), Offset(0, s), paint);
    }
    if (topRight) {
      canvas.drawLine(Offset(0, 0), Offset(s, 0), paint);
      canvas.drawLine(Offset(s, 0), Offset(s, s), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(Offset(0, 0), Offset(0, s), paint);
      canvas.drawLine(Offset(0, s), Offset(s, s), paint);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(0, s), Offset(s, s), paint);
      canvas.drawLine(Offset(s, 0), Offset(s, s), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
