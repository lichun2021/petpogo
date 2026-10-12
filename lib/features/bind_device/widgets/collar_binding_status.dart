import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';

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
      const SizedBox(height: 24),
      Center(
          child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: AppColors.brandPrimarySoft, shape: BoxShape.circle),
              child: Icon(
                  bound
                      ? Icons.check_rounded
                      : waiting
                          ? Icons.wifi_rounded
                          : Icons.info_outline_rounded,
                  size: 34,
                  color: AppColors.brandPrimary))),
      const SizedBox(height: 16),
      Text(title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(description,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, height: 1.5, color: AppColors.onSurfaceVariant)),
      const SizedBox(height: 24),
      if (!bound)
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outlineVariant)),
            child: Column(children: [
              _row(
                  saved
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  saved ? 'WiFi 配置已保存' : 'WiFi 配置已发送',
                  saved ? '等待项圈重启并联网' : '蓝牙已断开，保存结果待确认'),
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: AppColors.outlineVariant)),
              _row(
                  bound
                      ? Icons.check_circle_outline_rounded
                      : Icons.cloud_outlined,
                  reconfiguring ? '确认目标项圈上线' : '确认账号绑定',
                  queryFailed
                      ? '暂时无法查询，正在重试'
                      : waiting
                          ? '联网后自动确认，无需重复操作'
                          : '尚未获得确认结果'),
              if (waiting) ...[
                const SizedBox(height: 18),
                ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        minHeight: 3,
                        color: AppColors.brandPrimary,
                        backgroundColor: AppColors.brandPrimarySoft)),
                const SizedBox(height: 10),
                Text('预计最多等待 ${(60 - seconds).clamp(0, 60)} 秒',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ])),
      if (error != null && !bound) ...[
        const SizedBox(height: 8),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: const Text('查看原因与处理方法', style: TextStyle(fontSize: 13)),
            children: [
              Text(error!,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: AppColors.onSurfaceVariant))
            ]),
      ],
      if (waiting) ...[
        const SizedBox(height: 16),
        Text('请保持手机联网，确认结果会在此自动更新',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
      ],
    ]);
  }

  Widget _row(IconData icon, String title, String subtitle) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: AppColors.brandPrimary),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.onSurfaceVariant)),
        ])),
      ]);
}
