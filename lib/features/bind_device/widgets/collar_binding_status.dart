import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import 'collar_ui.dart';

/// 只展示已确认的事实，不把蓝牙写入成功当成账号绑定成功。
class CollarBindingStatus extends StatelessWidget {
  final bool bound, waiting, saved, reconfiguring, queryFailed;
  final int seconds;
  final String? deviceName, error;
  const CollarBindingStatus(
      {super.key,
      required this.bound,
      required this.waiting,
      required this.saved,
      required this.reconfiguring,
      required this.seconds,
      required this.queryFailed,
      this.deviceName,
      this.error});

  static const _maxWait = 60;

  @override
  Widget build(BuildContext context) {
    final title = bound
        ? (reconfiguring ? '项圈已重新上线' : '项圈绑定成功')
        : waiting
            ? '等待项圈联网'
            : '暂未确认连接结果';
    final description = bound
        ? (reconfiguring
            ? '${deviceName ?? '项圈'}已恢复连接，账号绑定不变'
            : '${deviceName ?? '项圈'}已添加到你的设备')
        : waiting
            ? '项圈将重启并连接 WiFi，请稍候'
            : '可能仍在连接，请先查询结果，避免重复配网';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: AppSpacing.x16),
      Center(child: _hero()),
      const SizedBox(height: AppSpacing.x16),
      Text(title, textAlign: TextAlign.center, style: CollarText.title),
      const SizedBox(height: AppSpacing.x8),
      Text(description, textAlign: TextAlign.center, style: CollarText.body),
      const SizedBox(height: AppSpacing.x24),
      if (!bound) _progressCard(),
      if (error != null && !bound) ...[
        const SizedBox(height: AppSpacing.x8),
        _reason(),
      ],
      if (waiting) ...[
        const SizedBox(height: AppSpacing.x16),
        Text('请保持手机联网，确认结果会在此自动更新',
            textAlign: TextAlign.center, style: CollarText.caption),
      ],
    ]);
  }

  Widget _hero() {
    if (bound) {
      return CollarHeroBadge(
          icon: Icons.check_rounded,
          size: 64,
          iconColor: AppColors.statusOnlineStrong,
          backgroundColor: AppColors.statusOnlineSoft);
    }
    if (waiting) {
      return const CollarHeroBadge(
          icon: Icons.wifi_rounded, size: 64, busy: true);
    }
    return CollarHeroBadge(
        icon: Icons.info_outline_rounded,
        size: 64,
        iconColor: AppColors.statusAlert,
        backgroundColor: AppColors.statusAlertSoft);
  }

  Widget _progressCard() => Container(
        padding: const EdgeInsets.all(AppSpacing.x16),
        decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.borderSubtle)),
        child: Column(children: [
          _row(
              saved
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              saved ? AppColors.statusOnlineStrong : AppColors.statusNeutral,
              saved ? 'WiFi 配置已保存' : 'WiFi 配置已发送',
              saved ? '等待项圈重启并联网' : '蓝牙已断开，保存结果待确认'),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x12),
              child: Divider(height: 1, color: AppColors.borderSubtle)),
          _row(
              queryFailed ? Icons.cloud_off_outlined : Icons.cloud_outlined,
              queryFailed ? AppColors.statusWarning : AppColors.brandPrimary,
              reconfiguring ? '确认目标项圈上线' : '确认账号绑定',
              queryFailed
                  ? '暂时无法查询，正在重试'
                  : waiting
                      ? '联网后自动确认，无需重复操作'
                      : '尚未获得确认结果'),
          if (waiting) ...[
            const SizedBox(height: AppSpacing.x16),
            ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    minHeight: 4,
                    semanticsLabel: '等待项圈联网进度',
                    value: (seconds / _maxWait).clamp(0.0, 1.0).toDouble(),
                    color: AppColors.brandPrimary,
                    backgroundColor: AppColors.brandPrimarySoft)),
            const SizedBox(height: AppSpacing.x8),
            Text('预计最多等待 ${(_maxWait - seconds).clamp(0, _maxWait)} 秒',
                style: CollarText.caption),
          ],
        ]),
      );

  Widget _row(IconData icon, Color color, String title, String subtitle) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.x4),
          Text(subtitle, style: CollarText.caption),
        ])),
      ]);

  Widget _reason() => ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.x12),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      iconColor: AppColors.textSecondary,
      collapsedIconColor: AppColors.textSecondary,
      title: Text('查看原因与处理方法',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      children: [Text(error!, style: CollarText.body.copyWith(height: 1.6))]);
}

/// 蓝牙写入阶段：显示实时进度与已用时间。
class CollarSendingView extends StatelessWidget {
  final String progress;
  final int seconds;
  final VoidCallback onDetails;
  const CollarSendingView(
      {super.key,
      required this.progress,
      required this.seconds,
      required this.onDetails});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: AppSpacing.x24),
        const Center(
            child: CollarHeroBadge(
                icon: Icons.bluetooth_connected_rounded, busy: true)),
        const SizedBox(height: AppSpacing.x20),
        Text('正在为项圈配网', textAlign: TextAlign.center, style: CollarText.title),
        const SizedBox(height: AppSpacing.x8),
        Semantics(
            liveRegion: true,
            child: Text(progress,
                textAlign: TextAlign.center, style: CollarText.body)),
        const SizedBox(height: AppSpacing.x16),
        Center(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: AppColors.surfaceSunken,
                    borderRadius: AppRadius.pillRadius),
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x16, vertical: AppSpacing.x8),
                    child: Text('已用时 $seconds 秒',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary))))),
        const SizedBox(height: AppSpacing.x24),
        const CollarNoticeCard(message: '请将项圈保持在手机附近。配置保存后，将自动检测账号绑定结果。'),
        TextButton(onPressed: onDetails, child: const Text('查看详细进度')),
      ]);
}
