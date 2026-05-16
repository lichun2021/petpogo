import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/data/repository/pet_peer_repository.dart';

// ── 宠物位置页 ────────────────────────────────────────────
class PetLocationPage extends ConsumerStatefulWidget {
  final String petName;
  final String deviceMac;
  final String petAvatar;   // 宠物头像 URL

  const PetLocationPage({
    super.key,
    required this.petName,
    required this.deviceMac,
    this.petAvatar = '',
  });

  @override
  ConsumerState<PetLocationPage> createState() => _PetLocationPageState();
}

class _PetLocationPageState extends ConsumerState<PetLocationPage>
    with SingleTickerProviderStateMixin {
  PetPositionModel? _position;
  bool  _isRefreshing = false;
  String? _error;

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _pulseAnim = Tween(begin: 0.0, end: 1.0).animate(_pulseCtrl);
    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isRefreshing = true; _error = null; });
    try {
      final repo = ref.read(petPeerRepositoryProvider);
      final pos = await repo.fetchPosition(mac: widget.deviceMac);
      if (mounted) {
        setState(() {
          _position     = pos;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isRefreshing = false; _error = e.toString(); });
    }
  }

  // 有位置则认为在安全区
  bool get _inFence => _position?.hasLocation ?? false;

  // ── 更新时间格式（HH:mm）
  String get _updateTime {
    if (_position == null || _position!.reportTime == 0) return '--:--';
    final dt = DateTime.fromMillisecondsSinceEpoch(_position!.reportTime);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEE6), // 地图底色
      body: Stack(children: [
        // ── 1. 亮色模拟地图背景 ─────────────────────────────
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => CustomPaint(
              painter: _LightMapPainter(
                hasLocation: _position?.hasLocation ?? false,
                pulse: _pulseAnim.value,
              ),
            ),
          ),
        ),

        // ── 2. 宠物位置标注 pin ─────────────────────────────
        if (_position?.hasLocation ?? false)
          Positioned(
            left: 0, right: 0, top: 0, bottom: 300,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // 头像 pin
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF3EBD6D), width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: ClipOval(child: widget.petAvatar.isNotEmpty
                      ? CachedNetworkImage(imageUrl: widget.petAvatar, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Center(child: Text('🐾', style: TextStyle(fontSize: 28))))
                      : const Center(child: Text('🐾', style: TextStyle(fontSize: 28)))),
                ),
                // 三角尖
                CustomPaint(painter: _PinTailPainter(), size: const Size(16, 10)),
              ]),
            ),
          ),

        // ── 3. 顶部透明 AppBar ───────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(8, safeTop + 4, 8, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.92), Colors.white.withOpacity(0)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
            child: Row(children: [
              Material(color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                  color: AppColors.onSurface,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              if (_isRefreshing)
                const Padding(padding: EdgeInsets.only(right: 16),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)))
              else
                Material(color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppColors.onSurface,
                    onPressed: _load,
                  ),
                ),
            ]),
          ),
        ),

        // ── 4. 右侧工具按钮 ────────────────────────────────
        Positioned(
          right: 14, bottom: 300 + 20,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _MapBtn(icon: Icons.refresh_rounded, onTap: _load),
            const SizedBox(height: 8),
            _MapBtn(icon: Icons.my_location_rounded, onTap: () {
              HapticFeedback.lightImpact();
            }),

          ]),
        ),

        // ── 5. 底部宠物信息卡片 ─────────────────────────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _BottomCard(
            petName:    widget.petName,
            petAvatar:  widget.petAvatar,
            position:   _position,
            inFence:    _inFence,
            error:      _error,
            updateTime: _updateTime,
            safeBottom: safeBottom,
          ),
        ),
      ]),
    );
  }
}

// ── 底部信息卡片 ─────────────────────────────────────────
class _BottomCard extends StatelessWidget {
  final String           petName, petAvatar, updateTime;
  final PetPositionModel? position;
  final bool             inFence;
  final String?          error;
  final double           safeBottom;

  const _BottomCard({
    required this.petName,
    required this.petAvatar,
    required this.position,
    required this.inFence,
    required this.error,
    required this.updateTime,
    required this.safeBottom,
  });

  @override
  Widget build(BuildContext context) {
    final hasLoc = position?.hasLocation ?? false;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + safeBottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 拖拽条
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)))),
        const SizedBox(height: 14),

        // 宠物头像 + 名字 + 安全状态
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF0F0EE),
                border: Border.all(color: const Color(0xFF3EBD6D), width: 2.5)),
            child: ClipOval(child: petAvatar.isNotEmpty
                ? CachedNetworkImage(imageUrl: petAvatar, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Center(child: Text('🐾', style: TextStyle(fontSize: 22))))
                : const Center(child: Text('🐾', style: TextStyle(fontSize: 22)))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(petName, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF3EBD6D)),
              const SizedBox(width: 4),
              Text(
                !hasLoc ? '定位中...' : (inFence ? '安全守护中' : '已离开围栏'),
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w700,
                    color: (!hasLoc || inFence) ? const Color(0xFF3EBD6D) : AppColors.error),
              ),
            ]),
          ])),
        ]),

        const SizedBox(height: 14),

        // 状态徽章行（范围/电量/GPS）
        Row(children: [
          _StatBadge(
            icon: Icons.radio_button_checked_rounded,
            label: inFence ? '范围内' : '范围外',
            color: inFence ? const Color(0xFF3EBD6D) : Colors.grey,
          ),
          const SizedBox(width: 8),
          _StatBadge(
            icon: Icons.gps_fixed_rounded,
            label: hasLoc ? 'GPS' : 'GPS 无信号',
            color: hasLoc ? const Color(0xFF3EBD6D) : Colors.grey,
          ),
          const SizedBox(width: 8),
          _StatBadge(
            icon: Icons.access_time_rounded,
            label: updateTime,
            color: Colors.grey.shade600,
          ),
        ]),

        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF0F0EE)),
        const SizedBox(height: 12),

        // 地址
        if (error != null)
          Row(children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
            const SizedBox(width: 6),
            Expanded(child: Text(error!, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 12, color: AppColors.error))),
          ])
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                hasLoc ? (position!.address.isNotEmpty ? position!.address : '${position!.latitude}, ${position!.longitude}') : '等待设备上报位置...',
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                maxLines: 2,
              ),
              if (hasLoc) ...[ const SizedBox(height: 2),
                Text('更新于 $updateTime', style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11, color: Color(0xFF999999))),
              ],
            ])),
          ]),


      ]),
    );
  }
}

// ── 状态徽章 ─────────────────────────────────────────────
class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
          fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

// ── 右侧地图按钮 ─────────────────────────────────────────
class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, size: 20, color: AppColors.onSurface),
    ),
  );
}

// ── 亮色地图 CustomPainter ─────────────────────────────
class _LightMapPainter extends CustomPainter {
  final bool hasLocation;
  final double pulse;
  const _LightMapPainter({this.hasLocation = false, this.pulse = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 地图底色（卡其/米白）
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFFEEEEE6));

    // 街区灰色建筑块
    final buildingPaint = Paint()..color = const Color(0xFFDFDFD8);
    final blocks = [
      Rect.fromLTWH(0, 0, w * 0.32, h * 0.28),
      Rect.fromLTWH(w * 0.42, 0, w * 0.25, h * 0.22),
      Rect.fromLTWH(w * 0.74, 0, w * 0.26, h * 0.35),
      Rect.fromLTWH(0, h * 0.35, w * 0.22, h * 0.3),
      Rect.fromLTWH(w * 0.58, h * 0.25, w * 0.3, h * 0.22),
      Rect.fromLTWH(w * 0.62, h * 0.52, w * 0.38, h * 0.2),
      Rect.fromLTWH(0, h * 0.7, w * 0.3, h * 0.3),
      Rect.fromLTWH(w * 0.42, h * 0.65, w * 0.18, h * 0.25),
    ];
    for (final b in blocks) {
      canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(4)), buildingPaint);
    }

    // 绿地
    final greenPaint = Paint()..color = const Color(0xFFC8E6C9);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.06, h * 0.06, w * 0.18, h * 0.16), const Radius.circular(6)), greenPaint);

    // 水域（蓝）
    final waterPaint = Paint()..color = const Color(0xFFBBDEFB);
    final waterPath = Path()
      ..moveTo(0, h * 0.55)
      ..cubicTo(w * 0.2, h * 0.52, w * 0.35, h * 0.58, w * 0.55, h * 0.54)
      ..cubicTo(w * 0.7, h * 0.51, w * 0.85, h * 0.56, w, h * 0.53)
      ..lineTo(w, h * 0.62)
      ..cubicTo(w * 0.85, h * 0.65, w * 0.7, h * 0.60, w * 0.55, h * 0.63)
      ..cubicTo(w * 0.35, h * 0.67, w * 0.2, h * 0.61, 0, h * 0.64)
      ..close();
    canvas.drawPath(waterPath, waterPaint);

    // 主干道（白色宽路）
    final road = Paint()..color = Colors.white..strokeWidth = 14..strokeCap = StrokeCap.round;
    // 横向主路
    canvas.drawLine(Offset(0, h * 0.42), Offset(w, h * 0.42), road);
    // 纵向主路
    canvas.drawLine(Offset(w * 0.4, 0), Offset(w * 0.4, h), road);
    // 斜路
    canvas.drawLine(Offset(w * 0.15, 0), Offset(w * 0.55, h * 0.45), road..strokeWidth = 10);

    // 次要道路（浅灰）
    final minorRoad = Paint()..color = const Color(0xFFFAFAF5)..strokeWidth = 6;
    canvas.drawLine(Offset(0, h * 0.28), Offset(w, h * 0.28), minorRoad);
    canvas.drawLine(Offset(w * 0.65, 0), Offset(w * 0.65, h * 0.52), minorRoad);
    canvas.drawLine(Offset(0, h * 0.7), Offset(w, h * 0.7), minorRoad);

    // ── 位置标注（脉冲圆）──
    if (hasLocation) {
      final cx = w * 0.4;
      final cy = h * 0.42;

      // 脉冲
      final pulseRadius = 40.0 + pulse * 40;
      final pulseOpacity = (1 - pulse) * 0.25;
      canvas.drawCircle(
        Offset(cx, cy), pulseRadius,
        Paint()..color = const Color(0xFF3EBD6D).withOpacity(pulseOpacity),
      );

      // 围栏圆
      canvas.drawCircle(
        Offset(cx, cy), 52,
        Paint()..color = const Color(0xFF3EBD6D).withOpacity(0.12),
      );
      canvas.drawCircle(
        Offset(cx, cy), 52,
        Paint()
          ..color = const Color(0xFF3EBD6D).withOpacity(0.5)
          ..style = PaintingStyle.stroke..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LightMapPainter old) =>
      old.hasLocation != hasLocation || old.pulse != pulse;
}

// ── Pin 三角尖 ───────────────────────────────────────────
class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF3EBD6D));
  }

  @override
  bool shouldRepaint(_) => false;
}
