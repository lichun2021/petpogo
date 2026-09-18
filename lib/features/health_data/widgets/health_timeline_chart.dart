import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import 'health_charts.dart';

/// Fixed temporal slots prevent sparse records from appearing evenly spread out.
/// Null is unobserved, zero is a measured zero. Neither is painted as a bar.
class HealthTimelineChart extends StatefulWidget {
  final List<HealthChartPoint> points;
  final Color color;
  final String unit;
  final bool hourly;
  const HealthTimelineChart(
      {super.key,
      required this.points,
      required this.color,
      required this.unit,
      this.hourly = false});

  @override
  State<HealthTimelineChart> createState() => _HealthTimelineChartState();
}

class _HealthTimelineChartState extends State<HealthTimelineChart> {
  int? selected;

  @override
  void didUpdateWidget(covariant HealthTimelineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final maximum = points.fold<double>(
        0, (v, p) => math.max(v, p.value?.isFinite == true ? p.value! : 0));
    final top = maximum <= 5 ? 5.0 : (maximum / 5).ceil() * 5.0;
    final textStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textTertiary);
    final active = selected != null && selected! < points.length
        ? points[selected!]
        : null;
    final empty = !points.any((p) => p.value != null && p.value!.isFinite);
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 16;
    final axisLabels = widget.hourly
        ? (largeText
            ? ['0时', '8时', '16时', '24时']
            : ['0时', '4时', '8时', '12时', '16时', '20时', '24时'])
        : points.isEmpty
            ? ['起始', '结束']
            : [
                for (var i = 0; i < points.length; i++)
                  if (i == 0 ||
                      i == points.length - 1 ||
                      i %
                              math.max(
                                  1,
                                  (points.length / (largeText ? 2 : 4))
                                      .ceil()) ==
                          0)
                    points[i].label
              ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: AppSpacing.x12),
      Row(children: [
        Text('(${widget.unit})', style: textStyle),
        const Spacer(),
        Text(
            active == null
                ? (empty ? '待采集' : '')
                : '${active.label}  ${active.displayValue}${active.value == null ? '' : widget.unit}',
            style: textStyle),
      ]),
      const SizedBox(height: AppSpacing.x8),
      SizedBox(
          height: AppSize.healthTimelineHeight,
          child: Row(children: [
            SizedBox(
                width: AppSize.healthAxisWidth *
                    MediaQuery.textScalerOf(context).scale(12) /
                    12,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                        6,
                        (i) => Text(
                            top >= 1000
                                ? '${(top * (5 - i) / 5000).toStringAsFixed(1)}k'
                                : (top * (5 - i) / 5).toStringAsFixed(0),
                            style: textStyle)))),
            Expanded(
                child: LayoutBuilder(
                    builder: (context, constraints) => Semantics(
                          label: empty
                              ? '暂无数据，保留时间坐标'
                              : points
                                  .map((p) => '${p.label} ${p.displayValue}')
                                  .join('，'),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: points.isEmpty
                                ? null
                                : (details) => setState(() => selected =
                                    (details.localPosition.dx /
                                            constraints.maxWidth *
                                            points.length)
                                        .floor()
                                        .clamp(0, points.length - 1)),
                            child: CustomPaint(
                                size: Size(constraints.maxWidth,
                                    AppSize.healthTimelineHeight),
                                painter: _TimelinePainter(
                                    points,
                                    top,
                                    widget.color,
                                    AppColors.borderSubtle,
                                    AppColors.textTertiary,
                                    selected)),
                          ),
                        ))),
          ])),
      Padding(
          padding: const EdgeInsets.only(
              left: AppSize.healthAxisWidth, top: AppSpacing.x8),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: axisLabels
                  .map((label) => Text(label, style: textStyle))
                  .toList())),
    ]);
  }
}

class _TimelinePainter extends CustomPainter {
  final List<HealthChartPoint> points;
  final double top;
  final Color color, grid, axis;
  final int? selected;
  _TimelinePainter(
      this.points, this.top, this.color, this.grid, this.axis, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 5;
      for (double x = 0; x < size.width; x += 6) {
        canvas.drawLine(
            Offset(x, y), Offset(math.min(x + 3, size.width), y), paint);
      }
    }
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height),
        paint..color = axis.withValues(alpha: .5));
    if (points.isEmpty) return;
    final slot = size.width / points.length;
    for (var i = 0; i < points.length; i++) {
      final value = points[i].value;
      if (value == null || !value.isFinite || value <= 0) continue;
      final height = math.max(2.0, value / top * size.height);
      final width = math.min(6.0, slot * .45);
      final rect = Rect.fromLTWH(
          slot * (i + .5) - width / 2, size.height - height, width, height);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect, const Radius.circular(AppRadius.control)),
          paint
            ..color = selected == null || selected == i
                ? color
                : color.withValues(alpha: .35));
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.points != points ||
      old.top != top ||
      old.color != color ||
      old.grid != grid ||
      old.axis != axis ||
      old.selected != selected;
}
