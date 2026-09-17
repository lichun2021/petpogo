import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_tokens.dart';
import '../../shared/theme/app_fonts.dart';
import 'controller/health_data_controller.dart';

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
      padding: EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.cardRadius,
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
          SizedBox(height: AppSpacing.x12),
          if (sectionState.isLoading && sectionState.data == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
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
          Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 32),
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
    return Row(
      children: _periods.map((p) {
        final isSelected = p.$1 == selected;
        return Padding(
          padding: EdgeInsets.only(right: AppSpacing.x8),
          child: ChoiceChip(
            label: Text(p.$2),
            selected: isSelected,
            onSelected: (_) => onChanged(p.$1),
          ),
        );
      }).toList(),
    );
  }
}

// ── 概览内容 ──────────────────────────────────────────────
class _OverviewContent extends StatelessWidget {
  final dynamic data;
  const _OverviewContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final behaviors = data.behaviorAnalysis.behaviors as List;
    if (data.dataQuality.level.toString().contains('none') ||
        behaviors.isEmpty) {
      return Text(
        '暂无数据',
        style: TextStyle(
            fontFamily: AppFonts.primary, color: AppColors.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in behaviors)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${b.name}：${(b.ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontFamily: AppFonts.primary),
            ),
          ),
        SizedBox(height: AppSpacing.x8),
        Text(
          data.disclaimer,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── AI 报告内容 ────────────────────────────────────────────
class _ReportContent extends StatelessWidget {
  final dynamic data;
  const _ReportContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.dataOverview.summary,
          style: TextStyle(fontFamily: AppFonts.primary),
        ),
        SizedBox(height: AppSpacing.x8),
        SizedBox(height: AppSpacing.x8),
        Text(
          data.disclaimer,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── 行为分析内容 ──────────────────────────────────────────
class _BehaviorContent extends StatelessWidget {
  final dynamic data;
  final String? selectedBehavior;
  final ValueChanged<String> onSelectBehavior;

  const _BehaviorContent({
    required this.data,
    required this.selectedBehavior,
    required this.onSelectBehavior,
  });

  @override
  Widget build(BuildContext context) {
    final behaviors = data.behaviors as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.x8,
          children: [
            for (final b in behaviors)
              ChoiceChip(
                label: Text(b.name),
                selected: b.behavior == (selectedBehavior ?? behaviors.first.behavior),
                onSelected: (_) => onSelectBehavior(b.behavior),
              ),
          ],
        ),
        SizedBox(height: AppSpacing.x8),
        if (!(data.baseline.unlocked as bool))
          Text(
            '数据基准尚未解锁（需累计 7 个有效采集日）',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        SizedBox(height: AppSpacing.x8),
        Text(
          data.disclaimer,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── 运动数据内容 ──────────────────────────────────────────
class _ExerciseContent extends StatelessWidget {
  final dynamic data;
  const _ExerciseContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '运动占比：${(data.summary.exerciseRatio * 100).toStringAsFixed(0)}%',
          style: TextStyle(fontFamily: AppFonts.primary),
        ),
        for (final m in (data.unavailableMetrics as List))
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              m,
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        SizedBox(height: AppSpacing.x8),
        Text(
          data.disclaimer,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
