import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_colors.dart';

class SelectDevicePage extends StatelessWidget {
  const SelectDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(),
        title: const Text('选择你的设备'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '宠物关怀',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _DeviceOption(
              iconWidget: Icon(Icons.key_rounded, color: AppColors.secondary, size: 26),
              iconBg: AppColors.secondaryContainer,
              name: 'KeyTracker',
              desc: '智能追踪器 · 定位 · 健康监测',
              onTap: () => context.push('/scan-qr/KeyTracker'),
            ),
            const SizedBox(height: 8),
            _DeviceOption(
              iconWidget: Icon(Icons.smartphone_rounded, color: AppColors.primary, size: 26),
              iconBg: AppColors.surfaceContainerLow,
              name: 'PetPhone',
              desc: '宠物智能手机 · 通话 · 音乐',
              onTap: () => context.push('/scan-qr/PetPhone'),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '请在设备背面找到二维码标签，点击设备后扫描即可完成绑定',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceOption extends StatelessWidget {
  final Widget iconWidget;
  final Color iconBg;
  final String name;
  final String desc;
  final VoidCallback onTap;

  const _DeviceOption({
    required this.iconWidget, required this.iconBg, required this.name,
    required this.desc, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: iconWidget),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.onSurface,
          ),
        ),
        subtitle: Text(
          desc,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
