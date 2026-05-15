import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pressable.dart';
import 'scan_qr_page.dart';

class SelectDevicePage extends StatelessWidget {
  const SelectDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('绑定设备',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择设备类型',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 26,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.onSurface)),
            const SizedBox(height: 6),
            Text('选择要添加的智能设备，按设备底部二维码扫码绑定',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                    color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 28),

            // ── 智能项圈 ──────────────────────────────────────
            _DeviceCard(
              emoji: '🐾',
              iconWidget: Stack(alignment: Alignment.center, children: [
                Icon(Icons.circle_outlined, color: AppColors.secondary.withOpacity(0.5), size: 32),
                const Icon(Icons.pets_rounded, color: AppColors.secondary, size: 16),
              ]),
              iconBg: AppColors.secondaryContainer.withOpacity(0.35),
              name: '智能项圈',
              desc: '给宠物佩戴，实时 GPS 定位 + 健康监测',
              features: const ['实时定位', '走失预警', '活动轨迹', '健康监测'],
              gradient: LinearGradient(
                colors: [AppColors.secondaryContainer.withOpacity(0.4), AppColors.surfaceContainerLowest],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const ScanQrPage(deviceType: '智能项圈'),
                ));
              },
            ).animate().fadeIn().slideY(begin: 0.1),

            const SizedBox(height: 16),

            // ── 智能宠物机器人 ────────────────────────────────
            _DeviceCard(
              emoji: '🤖',
              iconWidget: const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 30),
              iconBg: AppColors.primaryContainer.withOpacity(0.3),
              name: '智能宠物机器人',
              desc: '放置家中，互动陪伴 + 远程监控',
              features: const ['远程互动', 'AI 陪伴', '视频监控', '定位'],
              gradient: LinearGradient(
                colors: [AppColors.primaryContainer.withOpacity(0.25), AppColors.surfaceContainerLowest],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const ScanQrPage(deviceType: '智能宠物机器人'),
                ));
              },
            ).animate().fadeIn().slideY(begin: 0.1, delay: 80.ms),

            const Spacer(),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('扫描设备包装盒或设备背面的二维码完成绑定',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                        color: AppColors.onSurfaceVariant, height: 1.5))),
              ]),
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final String emoji, name, desc;
  final Widget iconWidget;
  final Color iconBg;
  final List<String> features;
  final Gradient gradient;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.emoji, required this.iconWidget, required this.iconBg,
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 56, height: 56,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
                child: Center(child: iconWidget)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(name, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18,
                    fontWeight: FontWeight.w800, color: AppColors.onSurface)),
              ]),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                  color: AppColors.onSurfaceVariant, height: 1.4)),
            ])),
            const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: AppColors.onSurfaceVariant),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 6, children: features.map((f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(f, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          )).toList()),
        ]),
      ),
    );
  }
}
