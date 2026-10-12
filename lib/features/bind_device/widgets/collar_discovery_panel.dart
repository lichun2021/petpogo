import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';

class CollarSetupSteps extends StatelessWidget {
  final int current;
  final String finalLabel;
  const CollarSetupSteps(
      {super.key, required this.current, this.finalLabel = '完成绑定'});
  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(
            3,
            (index) => Expanded(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(children: [
                    Container(
                        height: 4,
                        decoration: BoxDecoration(
                            color: index <= current
                                ? AppColors.brandPrimary
                                : AppColors.outlineVariant,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 10),
                    Text(['寻找项圈', '设置 WiFi', finalLabel][index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: index == current
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: index == current
                                ? AppColors.onSurface
                                : AppColors.onSurfaceVariant)),
                  ]),
                ))),
      );
}

class CollarDiscoveryPanel extends StatelessWidget {
  final bool scanning;
  final int foundCount;
  final VoidCallback? onSearch;
  const CollarDiscoveryPanel(
      {super.key,
      required this.scanning,
      required this.foundCount,
      required this.onSearch});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          if (foundCount == 0) ...[
            Center(
                child: SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(alignment: Alignment.center, children: [
                      Container(
                          decoration: BoxDecoration(
                              color: AppColors.brandPrimarySoft,
                              shape: BoxShape.circle)),
                      Icon(Icons.bluetooth_rounded,
                          size: 44, color: AppColors.brandPrimary),
                      if (scanning)
                        Positioned.fill(
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.brandPrimary)),
                    ]))),
            const SizedBox(height: 16),
          ],
          Text(
              foundCount > 0
                  ? '发现附近的项圈'
                  : scanning
                      ? '正在寻找项圈'
                      : '连接你的项圈',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          const SizedBox(height: 8),
          Text(
              foundCount > 0
                  ? '选择下方设备，继续设置 WiFi'
                  : scanning
                      ? '请保持项圈在手机旁，约需 15 秒'
                      : '请将项圈靠近手机，确认蓝灯每秒闪烁',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (foundCount == 0)
            FilledButton.icon(
                onPressed: scanning ? null : onSearch,
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(scanning ? '搜索中…' : '开始寻找项圈'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48))),
          if (foundCount > 0)
            Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: scanning ? null : onSearch,
                    child: const Text('重新搜索'))),
          if (foundCount == 0)
            TextButton(
                onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                            title: const Text('让项圈进入配网模式'),
                            content: const Text(
                                '首次使用请开启项圈。重新配网时，连续按复位键 3 次，等待蓝灯每秒闪烁。\n\n一次只让一台项圈进入配网模式。'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('知道了'))
                            ])),
                child: const Text('蓝灯没有闪烁？')),
        ],
      );
}
