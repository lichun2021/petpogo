import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pressable.dart';
import '../../app.dart' show AppL10nX;

class SelectDevicePage extends StatelessWidget {
  const SelectDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.bindDeviceTitle,
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text('选择设备类型',
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 26,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.onSurface)),
            const SizedBox(height: 6),
            Text('不同设备提供不同功能，按需选择',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                    color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 28),

            // KeyTracker 卡
            _DeviceCard(
              emoji: '🗝️',
              icon: Icons.location_on_rounded,
              iconBg: AppColors.secondaryContainer,
              iconColor: AppColors.secondary,
              name: l10n.bindDeviceKeyTracker,
              desc: l10n.bindDeviceKeyTrackerDesc,
              features: ['实时 GPS 定位', '走失预警', '活动轨迹', '健康监测'],
              gradient: LinearGradient(
                colors: [AppColors.secondaryContainer.withOpacity(0.4), AppColors.surfaceContainerLowest],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              onTap: () { HapticFeedback.mediumImpact(); context.push('/scan-qr/KeyTracker'); },
            ).animate().fadeIn().slideY(begin: 0.1),

            const SizedBox(height: 16),

            // PetPhone 卡
            _DeviceCard(
              emoji: '📱',
              icon: Icons.smartphone_rounded,
              iconBg: AppColors.primaryContainer.withOpacity(0.4),
              iconColor: AppColors.primary,
              name: l10n.bindDevicePetPhone,
              desc: l10n.bindDevicePetPhoneDesc,
              features: ['远程通话', 'AI 声音翻译', '舒缓音乐', '定位'],
              gradient: LinearGradient(
                colors: [AppColors.primaryContainer.withOpacity(0.3), AppColors.surfaceContainerLowest],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              onTap: () { HapticFeedback.mediumImpact(); context.push('/scan-qr/PetPhone'); },
            ).animate().fadeIn().slideY(begin: 0.1, delay: 80.ms),

            const Spacer(),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l10n.bindDeviceScanHint,
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                            color: AppColors.onSurfaceVariant, height: 1.5)),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final String emoji, name, desc;
  final IconData icon;
  final Color iconBg, iconColor;
  final List<String> features;
  final Gradient gradient;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.emoji, required this.icon, required this.iconBg, required this.iconColor,
    required this.name, required this.desc, required this.features,
    required this.gradient, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 20, spreadRadius: -4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 56, height: 56,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28)))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 20,
                    fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                    color: AppColors.onSurfaceVariant)),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.onSurfaceVariant),
            ]),
            const SizedBox(height: 16),
            // 功能标签
            Wrap(spacing: 8, runSpacing: 6, children: features.map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(f, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                  fontWeight: FontWeight.w600, color: AppColors.onSurface)),
            )).toList()),
          ],
        ),
      ),
    );
  }
}
