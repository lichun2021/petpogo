import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_tokens.dart';
import 'controller/health_data_controller.dart';
import 'data/models/health_data_models.dart';
import 'widgets/health_charts.dart';
import 'widgets/health_chart_data.dart';
import 'widgets/health_timeline_chart.dart';

/// Chart-first dashboard: all sections retain their plot when data is missing.
class HealthDataPage extends ConsumerWidget {
  final String petId;
  const HealthDataPage({super.key, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(healthDataControllerProvider(petId));
    final controller = ref.read(healthDataControllerProvider(petId).notifier);
    final date = DateTime.parse(state.selectedDate);
    Future<void> pickDate() async {
      final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now());
      if (picked != null) controller.setDate(_dateKey(picked));
    }

    return Scaffold(
      backgroundColor: AppColors.surfacePage,
      appBar: AppBar(
          backgroundColor: AppColors.surfacePage,
          centerTitle: true,
          scrolledUnderElevation: 0,
          title: const Text('健康数据'),
          actions: [
            IconButton(
                tooltip: '选择日期',
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_month_outlined))
          ]),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  tooltip: '前一天',
                  onPressed: () => controller.setDate(
                      _dateKey(date.subtract(const Duration(days: 1)))),
                  icon: const Icon(Icons.chevron_left_rounded)),
              Flexible(
                  child: TextButton(
                      onPressed: pickDate,
                      child: Text('${date.year}年${date.month}月${date.day}日',
                          style: TextStyle(color: AppColors.textPrimary)))),
              IconButton(
                  tooltip: '后一天',
                  onPressed: state.selectedDate
                              .compareTo(_dateKey(DateTime.now())) >=
                          0
                      ? null
                      : () => controller
                          .setDate(_dateKey(date.add(const Duration(days: 1)))),
                  icon: const Icon(Icons.chevron_right_rounded)),
            ]),
            _DataCard(
                title: '健康数据概览',
                icon: Icons.pets_outlined,
                section: state.overview,
                onRetry: controller.retryOverview,
                builder: (data) => _Overview(data: data)),
            const SizedBox(height: AppSpacing.x16),
            _DataCard(
                title: '健康数据报告',
                icon: Icons.monitor_heart_outlined,
                section: state.report,
                onRetry: controller.retryReport,
                builder: (data) => _Report(data: data)),
            const SizedBox(height: AppSpacing.x24),
            _PeriodSelector(
                selected: state.selectedPeriod,
                onChanged: controller.setPeriod),
            const SizedBox(height: AppSpacing.x16),
            _DataCard(
                title: '行为分析详情',
                icon: Icons.bar_chart_rounded,
                section: state.behavior,
                onRetry: controller.retryBehavior,
                builder: (data) => _Behavior(
                    data: data,
                    selected: state.selectedBehavior,
                    onSelect: controller.selectBehavior)),
            const SizedBox(height: AppSpacing.x16),
            _DataCard(
                title: '运动数据详情',
                icon: Icons.directions_walk_rounded,
                section: state.exercise,
                onRetry: controller.retryExercise,
                builder: (data) =>
                    _Exercise(data: data, period: state.selectedPeriod)),
            const SizedBox(height: AppSpacing.x16),
            const _Caption('基于设备采集记录，仅供日常参考，不作为医疗诊断。'),
            const SizedBox(height: AppSpacing.x16),
          ])),
    );
  }
}

class _DataCard<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final SectionState<T> section;
  final VoidCallback onRetry;
  final Widget Function(T?) builder;
  const _DataCard(
      {required this.title,
      required this.icon,
      required this.section,
      required this.onRetry,
      required this.builder});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.x20),
        decoration: BoxDecoration(
            color: AppColors.surfaceCard, borderRadius: AppRadius.cardRadius),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: AppIconSize.card, color: AppColors.textPrimary),
            const SizedBox(width: AppSpacing.x8),
            Expanded(
                child:
                    Text(title, style: Theme.of(context).textTheme.titleSmall)),
            if (section.isLoading)
              SizedBox.square(
                  dimension: AppIconSize.card,
                  child: CircularProgressIndicator(
                      strokeWidth: AppIconStroke.smallNode,
                      color: AppColors.brandPrimary)),
            if (section.error != null)
              TextButton(onPressed: onRetry, child: const Text('重试')),
          ]),
          if (section.error != null) const _Caption('加载失败'),
          const SizedBox(height: AppSpacing.x20),
          builder(section.data),
        ]),
      );
}

class _Metric extends StatelessWidget {
  final String label, value, unit;
  final Color? color;
  const _Metric(this.label, this.value, {this.unit = '', this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.x12),
        decoration: BoxDecoration(
            color: color?.withValues(alpha: .12) ??
                AppColors.surfaceSunken.withValues(alpha: .5),
            borderRadius: AppRadius.controlRadius),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.x8),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            TextSpan(
                text: unit.isEmpty ? '' : ' $unit',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ])),
        ]),
      );
}

class _Overview extends StatelessWidget {
  final HealthOverview? data;
  const _Overview({this.data});
  @override
  Widget build(BuildContext context) {
    final valid = data != null && data!.dataQuality.validReportCount > 0;
    final entries = data?.behaviorAnalysis.behaviors ?? <BehaviorEntry>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: _Metric('有效上报',
                data == null ? '—' : '${data!.dataQuality.validReportCount}',
                unit: '条')),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
            child: _Metric('运动上报占比',
                valid ? healthPercent(data!.exerciseData.exerciseRatio) : '—',
                color: AppColors.statusOnline))
      ]),
      const SizedBox(height: AppSpacing.x20),
      _RingLegend(
          ratios: valid ? entries.map((b) => b.ratio).toList() : [],
          label: '行为占比',
          rows: [
            for (var i = 0; i < entries.length; i++)
              (
                entries[i].name,
                valid ? healthPercent(entries[i].ratio) : '—',
                healthChartColor(i)
              )
          ]),
      const SizedBox(height: AppSpacing.x24),
      _HealthStatus(data: data?.healthStatus),
      if (data != null && data!.dataQuality.unsupportedReportCount > 0)
        _Caption('未纳入统计 ${data!.dataQuality.unsupportedReportCount} 条'),
    ]);
  }
}

class _Report extends StatefulWidget {
  final HealthReport? data;
  const _Report({this.data});
  @override
  State<_Report> createState() => _ReportState();
}

class _ReportState extends State<_Report> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final categories = [
      data?.trend.categories.rest,
      data?.trend.categories.exercise,
      data?.trend.categories.behavior
    ];
    const names = ['躺卧', '走路', '其他行为'];
    final category = categories[selected];
    final valid = data != null && data.trend.totalDurationSeconds > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RingLegend(
          ratios: valid ? categories.map((c) => c!.ratio).toList() : [],
          label: '估算占比',
          rows: [
            for (var i = 0; i < names.length; i++)
              (
                names[i],
                categories[i] == null
                    ? '—'
                    : healthDuration(categories[i]!.durationSeconds),
                healthChartColor(i)
              ),
          ]),
      const SizedBox(height: AppSpacing.x16),
      Wrap(spacing: AppSpacing.x8, children: [
        for (var i = 0; i < names.length; i++)
          ChoiceChip(
              label: Text(names[i]),
              selected: selected == i,
              showCheckmark: false,
              onSelected: (_) => setState(() => selected = i))
      ]),
      const SizedBox(height: AppSpacing.x12),
      _Metric('${names[selected]}估算时长',
          category == null ? '—' : healthDuration(category.durationSeconds),
          color: healthChartColor(selected)),
      HealthTimelineChart(
          points: healthHourlyPoints(category?.hourly ?? []),
          color: healthChartColor(selected),
          unit: '估算分钟',
          hourly: true),
      const SizedBox(height: AppSpacing.x8),
      const _Caption('按上报条数 × 2 秒估算；其他行为为进食、坐着、站立。'),
      if (data != null)
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(data.dataOverview.aiGenerated ? 'AI 解读' : '数据解读',
                style: Theme.of(context).textTheme.bodyMedium),
            children: [
              for (final text in [
                data.dataOverview.summary,
                ...data.dataOverview.observations,
                ...data.dataOverview.suggestions
              ])
                if (text.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.x12),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: _Caption(text))),
            ]),
    ]);
  }
}

class _RingLegend extends StatelessWidget {
  final List<double> ratios;
  final String label;
  final List<(String, String, Color)> rows;
  const _RingLegend(
      {required this.ratios, required this.label, required this.rows});
  @override
  Widget build(BuildContext context) {
    final ring = HealthRing(
        ratios: ratios,
        value: ratios.isEmpty ? '—' : '',
        label: label,
        dimension: AppSize.healthCompactRing);
    final legend = Column(children: [
      for (final row in rows)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
            child: Row(children: [
              Container(
                  width: AppSpacing.x8,
                  height: AppSpacing.x8,
                  decoration:
                      BoxDecoration(color: row.$3, shape: BoxShape.circle)),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                  child: Text(row.$1,
                      style: Theme.of(context).textTheme.bodySmall)),
              const SizedBox(width: AppSpacing.x8),
              Flexible(
                  child: Text(row.$2,
                      style: Theme.of(context).textTheme.labelLarge,
                      textAlign: TextAlign.end)),
            ]))
    ]);
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(
            children: [ring, const SizedBox(height: AppSpacing.x12), legend]);
      }
      return Row(children: [
        ring,
        const SizedBox(width: AppSpacing.x20),
        Expanded(child: legend)
      ]);
    });
  }
}

class _PeriodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _PeriodSelector({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
            color: AppColors.surfaceSunken,
            borderRadius: AppRadius.controlRadius),
        child: Row(children: [
          for (final period in [('day', '日'), ('week', '周'), ('month', '月')])
            Expanded(
                child: TextButton(
                    onPressed: () => onChanged(period.$1),
                    style: TextButton.styleFrom(
                        backgroundColor: selected == period.$1
                            ? AppColors.brandPrimary
                            : null,
                        foregroundColor: selected == period.$1
                            ? AppColors.textOnBrand
                            : AppColors.textSecondary,
                        shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.controlRadius)),
                    child: Text(period.$2))),
        ]),
      );
}

BehaviorDetail? _selected(BehaviorAnalysis? data, String? code) {
  final items = data?.behaviors ?? <BehaviorDetail>[];
  return items.isEmpty
      ? null
      : items.firstWhere((b) => b.behavior == code, orElse: () => items.first);
}

class _Behavior extends StatelessWidget {
  final BehaviorAnalysis? data;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _Behavior({this.data, this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final item = _selected(data, selected);
    final valid = data != null && data!.totalReportCount > 0 && item != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (data != null) _Caption(healthRangeLabel(data!.range)),
      const SizedBox(height: AppSpacing.x12),
      Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
        for (final b in data?.behaviors ?? <BehaviorDetail>[])
          ChoiceChip(
              label: Text(b.name),
              selected: b.behavior == item?.behavior,
              showCheckmark: false,
              onSelected: (_) => onSelect(b.behavior))
      ]),
      const SizedBox(height: AppSpacing.x16),
      Row(children: [
        Expanded(
            child: _Metric('上报条数', item == null ? '—' : '${item.reportCount}',
                unit: '条', color: AppColors.brandPrimary)),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
            child: _Metric('估算识别时长',
                item == null ? '—' : healthDuration(item.durationSeconds)))
      ]),
      const SizedBox(height: AppSpacing.x16),
      HealthRatioBar(
          label: '行为占比',
          ratio: valid ? item.ratio : null,
          color: AppColors.brandPrimary),
      const _Caption('上报条数不是发生次数；时长按每条 2 秒估算。'),
      const SizedBox(height: AppSpacing.x24),
      Text('项圈数据基准', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.x12),
      _Baseline(data: data, selected: selected),
    ]);
  }
}

class _Baseline extends StatelessWidget {
  final BehaviorAnalysis? data;
  final String? selected;
  const _Baseline({this.data, this.selected});
  @override
  Widget build(BuildContext context) {
    final baseline = data?.baseline;
    final item = _selected(data, selected);
    final ratio = baseline?.unlocked == true
        ? item?.baselineRatio ?? baseline?.behaviors[item?.behavior]?.ratio
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const _Caption('有效采集日'),
        Text('${baseline?.days ?? 0} / ${baseline?.requiredDays ?? 7} 天',
            style: Theme.of(context).textTheme.titleSmall)
      ]),
      const SizedBox(height: AppSpacing.x12),
      ClipRRect(
          borderRadius: AppRadius.pillRadius,
          child: LinearProgressIndicator(
              value: baseline != null && baseline.requiredDays > 0
                  ? healthRatio(baseline.days / baseline.requiredDays)
                  : 0,
              minHeight: AppSpacing.x8,
              color: AppColors.statusWarning,
              backgroundColor: AppColors.surfaceSunken)),
      const SizedBox(height: AppSpacing.x24),
      HealthRatioBar(
          label: '${item?.name ?? '行为'}当前占比',
          ratio:
              data != null && data!.totalReportCount > 0 ? item?.ratio : null,
          color: AppColors.brandPrimary),
      HealthRatioBar(
          label: '历史基准', ratio: ratio, color: AppColors.statusNeutral),
      if (baseline?.unlocked != true) const _Caption('采集完成后解锁基准'),
      const SizedBox(height: AppSpacing.x20),
      Text('基准期每日估算时长', style: Theme.of(context).textTheme.bodySmall),
      if (baseline?.start != null)
        _Caption(healthRangeLabel(
            TimeRange(start: baseline!.start!, end: baseline.end))),
      HealthTimelineChart(
          points: healthBaselinePoints(data, item?.behavior),
          color: AppColors.brandPrimary,
          unit: '估算分钟'),
    ]);
  }
}

class _Exercise extends StatelessWidget {
  final ExerciseData? data;
  final String period;
  const _Exercise({this.data, required this.period});
  @override
  Widget build(BuildContext context) {
    final valid = data != null && data!.dataQuality.validReportCount > 0;
    final summary = data?.summary;
    final actualPeriod = data?.period ?? period;
    final points = healthWalkingPoints(data, actualPeriod);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (data != null) _Caption(healthRangeLabel(data!.range)),
      const SizedBox(height: AppSpacing.x12),
      Row(children: [
        Expanded(
            child: _Metric(
                '走路上报', summary == null ? '—' : '${summary.walkingReportCount}',
                unit: '条', color: AppColors.statusOnline)),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
            child: _Metric(
                '运动占比', valid ? healthPercent(summary!.exerciseRatio) : '—'))
      ]),
      const SizedBox(height: AppSpacing.x20),
      Text('走路上报曲线', style: Theme.of(context).textTheme.titleSmall),
      HealthTimelineChart(
          points: points,
          color: AppColors.statusOnline,
          unit: '条',
          hourly: actualPeriod == 'day'),
      if (data?.unavailableMetrics.isNotEmpty == true)
        Align(
            alignment: Alignment.centerRight,
            child: Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                message: data!.unavailableMetrics.join('\n'),
                child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.x12),
                    child: Icon(Icons.info_outline_rounded,
                        size: AppIconSize.card,
                        color: AppColors.textTertiary)))),
    ]);
  }
}

class _HealthStatus extends StatelessWidget {
  final HealthStatusInfo? data;
  const _HealthStatus({this.data});
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final entry in [
          ('躺卧占比变化', data?.restStatus),
          ('进食占比变化', data?.feedingRegularity)
        ])
          Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(entry.$1,
                              style: Theme.of(context).textTheme.bodyMedium)),
                      if (entry.$2?.status == null ||
                          entry.$2!.status == HealthStatus.unknown)
                        const _Caption('—'),
                      if (entry.$2?.reason.isNotEmpty == true)
                        Tooltip(
                            message: entry.$2!.reason,
                            triggerMode: TooltipTriggerMode.tap,
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.x8),
                                child: Icon(Icons.info_outline_rounded,
                                    size: AppIconSize.card,
                                    color: AppColors.textTertiary))),
                    ]),
                    const SizedBox(height: AppSpacing.x12),
                    Row(children: [
                      for (final status in [
                        (HealthStatus.stable, '平稳', AppColors.statusOnline),
                        (HealthStatus.changed, '变化', AppColors.statusWarning),
                        (
                          HealthStatus.significantChange,
                          '明显变化',
                          AppColors.statusAlert
                        )
                      ])
                        Expanded(
                            child: Padding(
                                padding:
                                    const EdgeInsets.only(right: AppSpacing.x8),
                                child: Column(children: [
                                  Container(
                                      height: AppSpacing.x8,
                                      decoration: BoxDecoration(
                                          color: entry.$2?.status == status.$1
                                              ? status.$3
                                              : AppColors.surfaceSunken,
                                          borderRadius: AppRadius.pillRadius)),
                                  const SizedBox(height: AppSpacing.x8),
                                  Text(status.$2,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: entry.$2?.status ==
                                                      status.$1
                                                  ? status.$3
                                                  : AppColors.textTertiary)),
                                ]))),
                    ]),
                  ])),
      ]);
}

class _Caption extends StatelessWidget {
  final String text;
  const _Caption(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: AppColors.textTertiary, height: 1.5));
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
