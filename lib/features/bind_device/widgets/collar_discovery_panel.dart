import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import 'collar_ui.dart';

/// 三步进度：寻找项圈 → 设置 WiFi → 确认结果。
class CollarSetupSteps extends StatelessWidget {
  final int current;
  final String finalLabel;

  /// 全部完成时，最后一步也显示为已完成。
  final bool completed;
  const CollarSetupSteps(
      {super.key,
      required this.current,
      this.finalLabel = '完成绑定',
      this.completed = false});

  @override
  Widget build(BuildContext context) {
    final labels = ['寻找项圈', '设置 WiFi', finalLabel];
    return Semantics(
      container: true,
      label: '配网步骤，共 3 步，当前第 ${current + 1} 步：${labels[current]}',
      child: ExcludeSemantics(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < 3; i++)
            Expanded(
                child: _StepCell(
                    index: i,
                    label: labels[i],
                    current: current,
                    completed: completed)),
        ]),
      ),
    );
  }
}

class _StepCell extends StatelessWidget {
  final int index, current;
  final String label;
  final bool completed;
  const _StepCell(
      {required this.index,
      required this.label,
      required this.current,
      required this.completed});

  @override
  Widget build(BuildContext context) {
    final done = index < current || (completed && index == current);
    final active = index == current && !done;
    return Column(children: [
      Row(children: [
        Expanded(
            child: index == 0
                ? const SizedBox()
                : _StepLine(filled: index <= current)),
        _StepDot(number: index + 1, done: done, active: active),
        Expanded(
            child: index == 2
                ? const SizedBox()
                : _StepLine(filled: index < current)),
      ]),
      const SizedBox(height: AppSpacing.x8),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: active
                      ? FontWeight.w700
                      : done
                          ? FontWeight.w600
                          : FontWeight.w400,
                  color: active || done
                      ? AppColors.textPrimary
                      : AppColors.textSecondary))),
    ]);
  }
}

class _StepDot extends StatelessWidget {
  final int number;
  final bool done, active;
  const _StepDot(
      {required this.number, required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    final filled = done || active;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.brandPrimary : AppColors.surfaceSunken,
        border: Border.all(
            color: filled ? AppColors.brandPrimary : AppColors.borderSubtle),
        boxShadow: active
            ? [BoxShadow(color: AppColors.brandPrimarySoft, spreadRadius: 4)]
            : null,
      ),
      child: Center(
        child: done
            ? Icon(Icons.check_rounded, size: 16, color: AppColors.textOnBrand)
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$number',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? AppColors.textOnBrand
                              : AppColors.textSecondary)),
                ),
              ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool filled;
  const _StepLine({required this.filled});

  @override
  Widget build(BuildContext context) => Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
      decoration: BoxDecoration(
          color: filled ? AppColors.brandPrimary : AppColors.borderSubtle,
          borderRadius: BorderRadius.circular(2)));
}

class CollarDiscoveryPanel extends StatelessWidget {
  final bool scanning;
  final int foundCount;
  final VoidCallback? onSearch;

  /// 搜索失败或未发现项圈时的提示。
  final String? error;
  const CollarDiscoveryPanel(
      {super.key,
      required this.scanning,
      required this.foundCount,
      required this.onSearch,
      this.error});

  @override
  Widget build(BuildContext context) {
    final found = foundCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.x20),
        if (!found) ...[
          Center(
              child: CollarHeroBadge(
                  icon: Icons.bluetooth_rounded,
                  busy: scanning,
                  pulse: scanning,
                  halo: true)),
          const SizedBox(height: AppSpacing.x8),
        ],
        Text(
            found
                ? '发现附近的项圈'
                : scanning
                    ? '正在寻找项圈'
                    : '连接你的项圈',
            textAlign: TextAlign.center,
            style: CollarText.title),
        const SizedBox(height: AppSpacing.x8),
        Text(
            found
                ? '选择下方设备，继续设置 WiFi'
                : scanning
                    ? '请保持项圈在手机旁，约需 15 秒'
                    : '请将项圈靠近手机，确认蓝灯每秒闪烁',
            textAlign: TextAlign.center,
            style: CollarText.body),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.x16),
          CollarNoticeCard(tone: CollarNoticeTone.warning, message: error!),
        ],
        const SizedBox(height: AppSpacing.x16),
        if (!found)
          CollarPrimaryButton(
              label: scanning
                  ? '搜索中…'
                  : error != null
                      ? '重新搜索'
                      : '开始寻找项圈',
              icon: Icons.bluetooth_searching_rounded,
              onPressed: scanning ? null : onSearch)
        else
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: scanning ? null : onSearch,
                  child: Text(scanning ? '搜索中…' : '重新搜索'))),
        if (!found)
          TextButton(
              onPressed: () => showCollarPairingGuide(context),
              child: const Text('蓝灯没有闪烁？')),
      ],
    );
  }
}

Future<void> showCollarPairingGuide(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('让项圈进入配网模式'),
          content: const CollarGuideList(items: [
            CollarGuideItem(
                Icons.power_settings_new_rounded, '首次使用：开启项圈，等待蓝灯每秒闪烁。'),
            CollarGuideItem(
                Icons.restart_alt_rounded, '重新配网：连续按复位键 3 次，等待蓝灯每秒闪烁。'),
            CollarGuideItem(
                Icons.looks_one_rounded, '一次只让一台项圈进入配网模式，避免同名项圈无法区分。'),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('知道了'))
          ],
        ));
