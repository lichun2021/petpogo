import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';

/// All ratio charts share a fixed 0–100% scale.
double healthRatio(double value) => value.isFinite ? value.clamp(0.0, 1.0) : 0;
String healthPercent(double value) =>
    '${(healthRatio(value) * 100).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%';
String healthDuration(int seconds) {
  if (seconds < 60) return '$seconds秒';
  if (seconds < 3600) {
    return '${seconds ~/ 60}分${seconds % 60 == 0 ? '' : '${seconds % 60}秒'}';
  }
  return '${seconds ~/ 3600}小时${seconds % 3600 ~/ 60}分';
}

Color healthChartColor(int index) => [
      AppColors.statusOnline,
      AppColors.brandPrimary,
      AppColors.statusNeutral,
      AppColors.statusWarning,
      AppColors.textPrimary,
    ][index % 5];

class HealthRatioBar extends StatelessWidget {
  final String label;
  final double ratio;
  final Color color;
  final String? detail;

  const HealthRatioBar(
      {super.key,
      required this.label,
      required this.ratio,
      required this.color,
      this.detail});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x12),
        child: Semantics(
          label: '$label ${healthPercent(ratio)} ${detail ?? ''}',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: AppSpacing.x8, children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              Text(healthPercent(ratio),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              if (detail != null)
                Text(detail!, style: TextStyle(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: AppSpacing.x8),
            ClipRRect(
              borderRadius: AppRadius.pillRadius,
              child: LinearProgressIndicator(
                value: healthRatio(ratio),
                minHeight: AppSpacing.x4,
                color: color,
                backgroundColor: AppColors.surfaceSunken,
              ),
            ),
          ]),
        ),
      );
}

class HealthRing extends StatelessWidget {
  final List<double> ratios;
  final String value;
  final String label;
  const HealthRing(
      {super.key,
      required this.ratios,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          label: '$label $value',
          child: SizedBox.square(
            dimension: AppSize.healthRing *
                math.max(1.0, MediaQuery.textScalerOf(context).scale(14) / 18),
            child: CustomPaint(
              painter: _RingPainter(
                  ratios,
                  List.generate(ratios.length, healthChartColor),
                  AppColors.surfaceSunken),
              child: Center(
                  child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(value,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ]),
              )),
            ),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final List<double> ratios;
  final List<Color> colors;
  final Color track;
  _RingPainter(this.ratios, this.colors, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(AppSpacing.x12);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSpacing.x12
      ..color = track;
    canvas.drawOval(rect, paint);
    final total =
        ratios.fold<double>(0, (sum, value) => sum + healthRatio(value));
    // Preserve unaccounted data as the neutral track; normalize only rounding overflow.
    final denominator = math.max(1.0, total);
    var start = -math.pi / 2;
    for (var i = 0; i < ratios.length; i++) {
      final sweep = healthRatio(ratios[i]) / denominator * math.pi * 2;
      if (sweep > 0) {
        final gap = ratios.where((r) => r > 0).length > 1
            ? math.min(0.035, sweep / 4)
            : 0.0;
        canvas.drawArc(rect, start + gap / 2, sweep - gap, false,
            paint..color = colors[i]);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      !listEquals(ratios, oldDelegate.ratios) ||
      !listEquals(colors, oldDelegate.colors) ||
      track != oldDelegate.track;
}

class HealthChartPoint {
  final String label;
  final double? value;
  final String displayValue;
  const HealthChartPoint(this.label, this.value, this.displayValue);
}

/// Scrollable columns keep every date/hour and exact value readable, even for a month.
/// A missing observation is distinct from a measured zero.
class HealthColumnChart extends StatelessWidget {
  final String title;
  final String unit;
  final List<HealthChartPoint> points;
  final Color color;
  const HealthColumnChart(
      {super.key,
      required this.title,
      required this.unit,
      required this.points,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final values = points
        .map((p) => p.value)
        .whereType<double>()
        .where((v) => v.isFinite && v >= 0);
    final maximum = values.fold<double>(0, math.max);
    if (values.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x12),
        child: Text('$title：暂无数据',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.x4),
        Text('单位：$unit${points.length > 4 ? ' · 左右滑动查看' : ''}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.x12),
        LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final point in points)
                          Semantics(
                            label: '${point.label} ${point.displayValue}',
                            child: SizedBox(
                              width: math.max(AppSize.healthColumnWidth,
                                  constraints.maxWidth / points.length),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.x4),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(point.displayValue,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                      const SizedBox(height: AppSpacing.x4),
                                      SizedBox(
                                        height: AppSize.healthPlotHeight,
                                        child: Stack(children: [
                                          for (final alignment in [
                                            Alignment.topCenter,
                                            Alignment.center,
                                            Alignment.bottomCenter
                                          ])
                                            Align(
                                                alignment: alignment,
                                                child: Divider(
                                                    height: 1,
                                                    thickness: 1,
                                                    color: AppColors
                                                        .borderSubtle
                                                        .withValues(
                                                            alpha: 0.4))),
                                          Align(
                                              alignment: Alignment.bottomCenter,
                                              child: Container(
                                                width: AppSpacing.x20,
                                                height: point.value == null ||
                                                        !point
                                                            .value!.isFinite ||
                                                        maximum == 0
                                                    ? 0
                                                    : (point.value! / maximum)
                                                            .clamp(0.0, 1.0) *
                                                        AppSize
                                                            .healthPlotHeight,
                                                decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          color,
                                                          color.withValues(
                                                              alpha: 0.55)
                                                        ]),
                                                    borderRadius: AppRadius
                                                        .controlRadius),
                                              )),
                                        ]),
                                      ),
                                      Divider(
                                          height: AppSpacing.x4,
                                          color: AppColors.borderSubtle),
                                      const SizedBox(height: AppSpacing.x4),
                                      Text(point.label,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ]),
                              ),
                            ),
                          ),
                      ]),
                )),
      ]),
    );
  }
}
