import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/pet_toast.dart';
import '../controller/im_controller.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';


/// 扫码加好友页
/// 扫描 petpogo://user/{userId} 格式的二维码，自动弹出加好友确认框
class ScanAddFriendPage extends ConsumerStatefulWidget {
  const ScanAddFriendPage({super.key});

  @override
  ConsumerState<ScanAddFriendPage> createState() => _ScanAddFriendPageState();
}

class _ScanAddFriendPageState extends ConsumerState<ScanAddFriendPage> {
  final _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _scanned = false; // 已扫到，避免重复处理

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // 解析 petpogo://user/{userId}
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'petpogo' || uri.host != 'user') {
      _showInvalid();
      return;
    }
    final userId = uri.pathSegments.firstOrNull ?? '';
    if (userId.isEmpty) {
      _showInvalid();
      return;
    }

    setState(() => _scanned = true);
    HapticFeedback.mediumImpact();
    _ctrl.stop();
    _showAddFriendDialog(userId);
  }

  void _showInvalid() {
    PetToast.warning(context, '二维码无效，请扫描 PetPogo 用户的二维码');
  }

  void _showAddFriendDialog(String userId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddFriendDialog(
        userId: userId,
        onConfirm: (wording) async {
          Navigator.pop(ctx); // 关闭 dialog
          final ok = await ref.read(imControllerProvider.notifier).addFriend(
            toUserId: userId,
            wording: wording.isNotEmpty ? wording : '我通过扫描二维码添加你为好友',
          );
          if (!mounted) return;
          if (ok) {
            PetToast.success(context, '好友申请已发送 🐾');
            Navigator.pop(context);
          } else {
            PetToast.error(context, '发送失败，请稍后重试');
          }
        },
        onCancel: () {
          Navigator.pop(ctx);
          setState(() => _scanned = false);
          _ctrl.start();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 摄像头预览 ──────────────────────────────────
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),

          // ── 扫描框遮罩 ──────────────────────────────────
          _ScanOverlay(),

          // ── 顶部栏 ─────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      '扫码加好友',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontSize: 18,
                        fontWeight: FontWeight.w700, color: Colors.white,
                      ),
                    ),
                  ),
                  // 手电筒
                  IconButton(
                    icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white, size: 24),
                    onPressed: () => _ctrl.toggleTorch(),
                  ),
                ],
              ),
            ),
          ),

          // ── 底部提示 ────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 60,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      '将对方的 PetPogo 二维码对准扫描框',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontSize: 13,
                        color: Colors.white, fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 扫描框遮罩 ──────────────────────────────────────────────
class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final boxW   = size.width * 0.68;
    const boxH   = 280.0;
    final left   = (size.width - boxW) / 2;
    final top    = (size.height - boxH) / 2 - 30;

    return Stack(
      children: [
        // 四周暗色遮罩
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(color: Colors.transparent),
              Positioned(
                left: left, top: top, width: boxW, height: boxH,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 四角装饰线
        Positioned(
          left: left, top: top, width: boxW, height: boxH,
          child: CustomPaint(painter: _CornerPainter()),
        ),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const r = 20.0;
    const len = 28.0;

    // 四个角
    final corners = [
      Offset(r, 0),      Offset(0, r),      // 左上
      Offset(size.width - r, 0), Offset(size.width, r),  // 右上
      Offset(0, size.height - r), Offset(r, size.height), // 左下
      Offset(size.width, size.height - r), Offset(size.width - r, size.height), // 右下
    ];

    void corner(Offset a, Offset mid, Offset b) {
      final path = Path()
        ..moveTo(a.dx + (mid.dx - a.dx).sign * len, a.dy + (mid.dy - a.dy).sign * len)
        ..lineTo(a.dx, a.dy)
        ..arcToPoint(b, radius: const Radius.circular(r))
        ..lineTo(b.dx + (mid.dx - b.dx).sign * len, b.dy + (mid.dy - b.dy).sign * len);
      canvas.drawPath(path, paint);
    }

    corner(corners[0], const Offset(0, 0), corners[1]);
    corner(corners[2], Offset(size.width, 0), corners[3]);
    corner(corners[4], Offset(0, size.height), corners[5]);
    corner(corners[6], Offset(size.width, size.height), corners[7]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 加好友确认弹窗 ──────────────────────────────────────────
class _AddFriendDialog extends StatefulWidget {
  final String userId;
  final void Function(String wording) onConfirm;
  final VoidCallback onCancel;

  const _AddFriendDialog({
    required this.userId,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final _ctrl = TextEditingController(text: '我通过扫描二维码添加你为好友');
  bool _adding = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 40, spreadRadius: -4,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              '添加好友',
              style: TextStyle(
                fontFamily: AppFonts.primary, fontSize: 20,
                fontWeight: FontWeight.w800, color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '用户 ID: ${widget.userId}',
              style: const TextStyle(
                fontFamily: AppFonts.primary, fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            // 验证消息
            TextField(
              controller: _ctrl,
              maxLength: 50,
              style: const TextStyle(fontFamily: AppFonts.primary, fontSize: 14),
              decoration: InputDecoration(
                labelText: '验证消息',
                labelStyle: const TextStyle(fontFamily: AppFonts.primary, fontSize: 13),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                counterStyle: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 20),
            // 按钮
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: widget.onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.outlineVariant),
                      ),
                    ),
                    child: const Text('取消',
                      style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _adding ? null : () {
                      setState(() => _adding = true);
                      widget.onConfirm(_ctrl.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _adding
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('发送申请',
                            style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontWeight: FontWeight.w700, fontSize: 14,
                            )),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
