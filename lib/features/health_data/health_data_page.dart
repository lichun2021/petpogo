import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_tokens.dart';
import '../../shared/theme/app_fonts.dart';
import 'controller/health_data_controller.dart';
import 'data/models/health_data_models.dart';
import 'widgets/health_charts.dart';

/// 健康数据看板页
///
/// 展示 4 个数据段（概览/AI报告/行为分析/运动数据），每段独立加载/失败/重试。
class HealthDataPage extends ConsumerWidget {
  final String petId;

  const HealthDataPage({super.key, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(healthDataControllerProvider(petId));
    final controller = ref.read(healthDataControllerProvider(petId).notifier);

    return Scaffold(
      backgroundColor: AppColors.surfacePage,
      appBar: AppBar(
        backgroundColor: AppColors.surfacePage,
        elevation: 0,
        title: Text(
          '健康数据',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              title: '健康数据概览',
              sectionState: state.overview,
              onRetry: controller.retryOverview,
              builder: (data) => _OverviewContent(data: data),
            ),
            SizedBox(height: AppSpacing.x16),
            _SectionCard(
              title: 'AI 健康报告',
              sectionState: state.report,
              onRetry: controller.retryReport,
              builder: (data) => _ReportContent(data: data),
            ),
            SizedBox(height: AppSpacing.x16),
            _PeriodSelector(
              selected: state.selectedPeriod,
              onChanged: controller.setPeriod,
            ),
            SizedBox(height: AppSpacing.x8),
            _SectionCard(
              title: '行为分析详情',
              sectionState: state.behavior,
              onRetry: controller.retryBehavior,
              builder: (data) => _BehaviorContent(
                data: data,
                selectedBehavior: state.selectedBehavior,
                onSelectBehavior: controller.selectBehavior,
              ),
            ),
            SizedBox(height: AppSpacing.x16),
            _SectionCard(
              title: '运动数据详情',
              sectionState: state.exercise,
              onRetry: controller.retryExercise,
              builder: (data) => _ExerciseContent(data: data),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 通用段落卡片：独立处理 loading/error/data ──────────────────
class _SectionCard<T> extends StatelessWidget {
  final String title;
  final SectionState<T> sectionState;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  const _SectionCard({
    required this.title,
    required this.sectionState,
    required this.onRetry,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSpacing.x20),
          if (sectionState.isLoading && sectionState.data != null) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.x12),
          ],
          if (sectionState.error != null && sectionState.data != null) ...[
            const _Note('刷新失败，当前显示上次数据'),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
          if (sectionState.isLoading && sectionState.data == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.x24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (sectionState.error != null && sectionState.data == null)
            _ErrorRetry(onRetry: onRetry)
          else if (sectionState.data != null)
            builder(sectionState.data as T)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32),
          SizedBox(height: AppSpacing.x8),
          Text(
            '加载失败，请重试',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppSpacing.x8),
          FilledButton(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PeriodSelector({required this.selected, required this.onChanged});

  static const _periods = [
    ('day', '日'),
    ('week', '周'),
    ('month', '月'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
          color: AppColors.surfaceSunken, borderRadius: AppRadius.pillRadius),
      child: Row(
          children: _periods.map((p) {
        final isSelected = p.$1 == selected;
        return Expanded(
            child: Semantics(
                selected: isSelected,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, AppSize.touchMin),
                    backgroundColor: isSelected ? AppColors.surfaceCard : null,
                    foregroundColor: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillRadius),
                  ),
                  onPressed: () => onChanged(p.$1),
                  child: Text(p.$2,
                      style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400)),
                )));
      }).toList()),
    );
  }
}

// ── 概览内容 ──────────────────────────────────────────────
class _OverviewContent extends StatelessWidget {
  final HealthOverview data;
  const _OverviewContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final behaviors = data.behaviorAnalysis.behaviors;
    final hasData = data.dataQuality.level != DataQualityLevel.none &&
        data.dataQuality.validReportCount > 0 &&
        behaviors.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Note('${data.reportDate} · 当日已识别行为占比'),
      const SizedBox(height: AppSpacing.x12),
      if (!hasData)
        const _Note('暂无有效行为数据')
      else ...[
        LayoutBuilder(builder: (context, constraints) {
          final ring = HealthRing(
            ratios: behaviors.map((b) => b.ratio).toList(),
            value: '${data.dataQuality.validReportCount}',
            label: '有效记录',
          );
          final legend = Column(children: [
            for (var i = 0; i < behaviors.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
                child: Row(children: [
                  Container(
                      width: AppSpacing.x8,
                      height: AppSpacing.x8,
                      decoration: BoxDecoration(
                          color: healthChartColor(i), shape: BoxShape.circle)),
                  const SizedBox(width: AppSpacing.x8),
                  Expanded(
                      child: Text(behaviors[i].name,
                          style: Theme.of(context).textTheme.bodyMedium)),
                  Text(healthPercent(behaviors[i].ratio),
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
          ]);
          if (constraints.maxWidth >=
                  AppSize.healthRing + AppSize.healthLegendWidth &&
              MediaQuery.textScalerOf(context).scale(14) <= 18) {
            return Row(children: [
              ring,
              const SizedBox(width: AppSpacing.x16),
              Expanded(child: legend)
            ]);
          }
          return Column(
              children: [ring, const SizedBox(height: AppSpacing.x12), legend]);
        }),
        const SizedBox(height: AppSpacing.x20),
        const _Note('占比基于已采集记录，不代表全天时长。'),
        if (data.dataQuality.unsupportedReportCount > 0)
          _Note(
              '另有 ${data.dataQuality.unsupportedReportCount} 次上报未识别，不计入行为占比。'),
      ],
      const SizedBox(height: AppSpacing.x8),
      _Note(data.disclaimer),
    ]);
  }
}

// ── AI 报告内容 ────────────────────────────────────────────
class _ReportContent extends StatelessWidget {
  final HealthReport data;
  const _ReportContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final categories = data.trend.categories;
    final entries = [
      ('休息', categories.rest),
      ('运动', categories.exercise),
      ('其他行为', categories.behavior)
    ];
    final hourly = [...categories.exercise.hourly]
      ..sort((a, b) => _compareTime(a.hour, b.hour));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(data.dataOverview.summary,
          style: TextStyle(fontFamily: AppFonts.primary)),
      if (data.trend.totalDurationSeconds > 0) ...[
        const SizedBox(height: AppSpacing.x16),
        _Note('已记录时长 ${healthDuration(data.trend.totalDurationSeconds)}'),
        const SizedBox(height: AppSpacing.x12),
        for (var i = 0; i < entries.length; i++)
          HealthRatioBar(
            label: entries[i].$1,
            ratio: entries[i].$2.ratio,
            color: healthChartColor(i),
            detail: healthDuration(entries[i].$2.durationSeconds),
          ),
        HealthColumnChart(
          title: '当日运动时段分布',
          unit: '秒',
          color: AppColors.brandPrimary,
          points: hourly
              .map((h) => HealthChartPoint(_timeLabel(h.hour, hourly: true),
                  h.durationSeconds.toDouble(), '${h.durationSeconds}'))
              .toList(),
        ),
      ],
      for (final observation in data.dataOverview.observations)
        Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x8),
            child: Text(observation)),
      for (final suggestion in data.dataOverview.suggestions)
        Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x8),
            child: _Note(suggestion)),
      const SizedBox(height: AppSpacing.x16),
      _Note(data.disclaimer),
    ]);
  }
}

// ── 行为分析内容 ──────────────────────────────────────────
class _BehaviorContent extends StatelessWidget {
  final BehaviorAnalysis data;
  final String? selectedBehavior;
  final ValueChanged<String> onSelectBehavior;

  const _BehaviorContent(
      {required this.data,
      required this.selectedBehavior,
      required this.onSelectBehavior});

  @override
  Widget build(BuildContext context) {
    final behaviors = data.behaviors;
    final selected = behaviors.isEmpty
        ? null
        : behaviors.firstWhere(
            (b) => b.behavior == selectedBehavior,
            orElse: () => behaviors.first,
          );
    final baseline = data.baseline;
    final history = [...baseline.dailyBehaviorDistribution]
      ..sort((a, b) => a.date.compareTo(b.date));
    final baselineRatio = selected == null
        ? null
        : selected.baselineRatio ??
            baseline.behaviors[selected.behavior]?.ratio;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Note('${data.range.start} — ${data.range.end}'),
      const SizedBox(height: AppSpacing.x8),
      Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x4, children: [
        for (final b in behaviors)
          ChoiceChip(
              showCheckmark: false,
              selectedColor: AppColors.brandPrimarySoft,
              backgroundColor: AppColors.surfaceCard,
              side: BorderSide(
                  color: b.behavior == selected?.behavior
                      ? AppColors.brandPrimarySoft
                      : AppColors.borderSubtle),
              shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.pillRadius),
              label: Text(b.name),
              selected: b.behavior == selected?.behavior,
              onSelected: (_) => onSelectBehavior(b.behavior)),
      ]),
      const SizedBox(height: AppSpacing.x12),
      if (selected == null || data.totalReportCount <= 0)
        const _Note('当前周期暂无有效行为数据')
      else ...[
        HealthRatioBar(
            label: '${selected.name}占比',
            ratio: selected.ratio,
            color: AppColors.brandPrimary,
            detail: '${selected.reportCount} 次上报'),
        if (baseline.unlocked && baselineRatio != null)
          HealthRatioBar(
              label: '历史基准占比',
              ratio: baselineRatio,
              color: AppColors.statusNeutral),
        if (baseline.unlocked && baselineRatio == null)
          const _Note('该行为暂无可用基准'),
      ],
      if (!baseline.unlocked) ...[
        Text('基准采集进度', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.x8),
        LinearProgressIndicator(
          value: baseline.requiredDays > 0
              ? healthRatio(baseline.days / baseline.requiredDays)
              : 0,
          minHeight: AppSpacing.x8,
          color: AppColors.statusOnline,
          backgroundColor: AppColors.surfaceSunken,
        ),
        const SizedBox(height: AppSpacing.x8),
        _Note(
            '已累计 ${baseline.days} / ${baseline.requiredDays} 个有效采集日，解锁后可对比历史基准。'),
      ],
      if (selected != null)
        HealthColumnChart(
          title: '${selected.name}每日记录时长（基准采集期）',
          unit: '秒',
          color: AppColors.statusOnline,
          points: history.map((day) {
            final entry = day.behaviors[selected.behavior];
            final value = day.totalDurationSeconds > 0
                ? entry?.durationSeconds.toDouble()
                : null;
            return HealthChartPoint(_timeLabel(day.date), value,
                value == null ? '无数据' : '${value.toInt()}');
          }).toList(),
        ),
      const SizedBox(height: AppSpacing.x8),
      _Note(data.disclaimer),
    ]);
  }
}

// ── 运动数据内容 ──────────────────────────────────────────
class _ExerciseContent extends StatelessWidget {
  final ExerciseData data;
  const _ExerciseContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final hasData = data.dataQuality.level != DataQualityLevel.none &&
        data.dataQuality.validReportCount > 0;
    final timeline = [...data.timeline]
      ..sort((a, b) => _compareTime(a.time, b.time));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Note('${data.range.start} — ${data.range.end}'),
      const SizedBox(height: AppSpacing.x12),
      if (!hasData)
        const _Note('暂无有效运动数据')
      else ...[
        HealthRing(
            ratios: [data.summary.exerciseRatio],
            value: healthPercent(data.summary.exerciseRatio),
            label: '运动上报占比'),
        const SizedBox(height: AppSpacing.x12),
        HealthRatioBar(
            label: '运动',
            ratio: data.summary.exerciseRatio,
            color: AppColors.statusOnline,
            detail: '${data.summary.exerciseReportCount} 次上报'),
        const _Note('占比基于行为上报次数，不代表运动时长或目标完成度。'),
        HealthColumnChart(
          title: '行为上报时段分布',
          unit: '次',
          color: AppColors.statusOnline,
          points: timeline
              .map((bucket) => HealthChartPoint(
                    _timeLabel(bucket.time, hourly: data.period == 'day'),
                    bucket.reportCount > 0
                        ? bucket.reportCount.toDouble()
                        : null,
                    bucket.reportCount > 0 ? '${bucket.reportCount}' : '无上报',
                  ))
              .toList(),
        ),
        if (data.summary.steps != null) Text('步数：${data.summary.steps} 步'),
        if (data.summary.caloriesKcal != null)
          Text('热量：${data.summary.caloriesKcal!.toStringAsFixed(1)} 千卡'),
      ],
      for (final metric in data.unavailableMetrics)
        Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x8),
            child: _Note(metric)),
      const SizedBox(height: AppSpacing.x12),
      _Note(data.disclaimer),
    ]);
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: AppColors.textSecondary, height: 1.5));
}

String _timeLabel(String raw, {bool hourly = false}) {
  final date = DateTime.tryParse(raw);
  if (date != null) {
    if (hourly) return '${date.hour.toString().padLeft(2, '0')}:00';
    return '${date.month}/${date.day}';
  }
  if (hourly && RegExp(r'^\d{1,2}$').hasMatch(raw)) {
    return '${raw.padLeft(2, '0')}:00';
  }
  return raw;
}

int _compareTime(String a, String b) {
  final aHour = int.tryParse(a);
  final bHour = int.tryParse(b);
  if (aHour != null && bHour != null) return aHour.compareTo(bHour);
  final aDate = DateTime.tryParse(a);
  final bDate = DateTime.tryParse(b);
  if (aDate != null && bDate != null) return aDate.compareTo(bDate);
  return a.compareTo(b);
}
