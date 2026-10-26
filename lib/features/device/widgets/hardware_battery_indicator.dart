import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_fonts.dart';
import '../../../shared/theme/app_tokens.dart';

/// 手机式电量：按实际百分比连续填充，充电显示绿色闪电，低电显示红色。
class HardwareBatteryIndicator extends StatelessWidget {
  const HardwareBatteryIndicator(
      {super.key, this.percent, this.isCharging = false});

  final int? percent;
  final bool isCharging;

  @override
  Widget build(BuildContext context) {
    final color = isCharging
        ? AppColors.charging
        : percent != null && percent! < 20
            ? AppColors.batteryLow
            : AppColors.textOnBrand;
    return Semantics(
      container: true,
      label: '电量',
      value: percent == null ? '暂未上报' : '$percent%',
      hint: isCharging
          ? '充电中'
          : percent != null && percent! < 20
              ? '电量偏低'
              : null,
      child: ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
        CustomPaint(
          size: const Size(26, 15),
          painter: HardwareBatteryPainter(
            fraction: percent == null ? null : percent!.clamp(0, 100) / 100,
            color: color,
          ),
        ),
        if (isCharging) Icon(Icons.bolt_rounded, size: 14, color: color),
        const SizedBox(width: AppSpacing.x4),
        Flexible(
            child: Text(percent == null ? '—' : '$percent%',
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOnBrand,
                ))),
      ])),
    );
  }
}

class HardwareBatteryPainter extends CustomPainter {
  const HardwareBatteryPainter({required this.fraction, required this.color});
  final double? fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(.75, 2.25, 21.5, 10.5), const Radius.circular(2.5));
    canvas.drawRRect(
        body,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(23.2, 5, 2, 5), const Radius.circular(.8)),
        Paint()..color = color);
    const inner = Rect.fromLTWH(3, 4.5, 17, 6);
    final innerShape = RRect.fromRectAndRadius(inner, const Radius.circular(1));
    canvas.drawRRect(innerShape, Paint()..color = color.withValues(alpha: .16));
    if (fraction == null || fraction! <= 0) return;
    canvas.save();
    canvas.clipRRect(innerShape);
    canvas.drawRect(
        Rect.fromLTWH(inner.left, inner.top,
            inner.width * fraction!.clamp(0, 1), inner.height),
        Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(HardwareBatteryPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}
