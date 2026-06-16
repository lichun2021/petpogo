import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pressable.dart';
import 'scan_qr_page.dart';
import 'robot_wifi_setup_page.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

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
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('绑定设备',
            style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择设备类型',
                style: TextStyle(fontFamily: AppFonts.primary, fontSize: 26,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.onSurface)),
            SizedBox(height: 6),
            Text('选择要添加的智能设备，不同设备配网方式不同',
                style: TextStyle(fontFamily: AppFonts.primary, fontSize: 14,
                    color: AppColors.onSurfaceVariant)),
            SizedBox(height: 28),

            // ── 智能项圈（4G，扫设备背面二维码）─────────────────
            _DeviceCard(
              emoji: '🐾',
              iconWidget: Stack(alignment: Alignment.center, children: [
                Icon(Icons.circle_outlined, color: AppColors.secondary.withOpacity(0.5), size: 32),
                Icon(Icons.pets_rounded, color: AppColors.secondary, size: 16),
              ]),
              iconBg: AppColors.secondaryContainer.withOpacity(0.35),
              name: '智能项圈',
              desc: '给宠物佩戴，实时 GPS 定位 + 健康监测',
              features: ['实时定位', '走失预警', '活动轨迹', '健康监测'],
              tag: '扫码绑定',
              tagColor: AppColors.secondary,
              gradient: LinearGradient(
                colors: [AppColors.secondaryContainer.withOpacity(0.4), AppColors.surfaceContainerLowest],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ScanQrPage(deviceType: '智能项圈'),
                ));
              },
            ).animate().fadeIn().slideY(begin: 0.1),

            SizedBox(height: 16),

            // ── 智能宠物机器人（WiFi，手机生成二维码让机器人扫）────
            _DeviceCard(
              emoji: '🤖',
              iconWidget: Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 30),
              iconBg: AppColors.primaryContainer.withOpacity(0.3),
              name: '智能宠物机器人',
              desc: '放置家中，互动陪伴 + 远程监控',
              features: ['远程互动', 'AI 陪伴', '视频监控', '定位'],
              tag: 'WiFi 配网',
              tagColor: AppColors.primary,
              gradient: LinearGradient(
                colors: [AppColors.primaryContainer.withOpacity(0.25), AppColors.surfaceContainerLowest],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const RobotWifiSetupPage(),
                ));
              },
            ).animate().fadeIn().slideY(begin: 0.1, delay: 80.ms),

            Spacer(),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(child: Text(
                    '项圈：扫设备背面二维码绑定\n机器人：填写 WiFi 后让机器人扫码配网',
                    style: TextStyle(fontFamily: AppFonts.primary, fontSize: 13,
                        color: AppColors.onSurfaceVariant, height: 1.6))),
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
  final String? tag;
  final Color? tagColor;

  const _DeviceCard({
    required this.emoji, required this.iconWidget, required this.iconBg,
    required this.name, required this.desc, required this.features,
    required this.gradient, required this.onTap,
    this.tag, this.tagColor,
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
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // 图标
            Container(width: 56, height: 56,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
                child: Center(child: iconWidget)),
            const SizedBox(width: 14),
            // 名称 + 描述
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 名字行：emoji + 名字（Flexible）+ 标签（固定宽）
              Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: AppFonts.primary, fontSize: 17,
                        fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                ),
                if (tag != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (tagColor ?? AppColors.primary).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: (tagColor ?? AppColors.primary).withValues(alpha: 0.3)),
                    ),
                    child: Text(tag!,
                      softWrap: false,
                      maxLines: 1,
                      style: TextStyle(fontFamily: AppFonts.primary, fontSize: 10,
                          fontWeight: FontWeight.w700, color: tagColor ?? AppColors.primary)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              // 描述独占整行，不夹标签
              Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppFonts.primary, fontSize: 12,
                      color: AppColors.onSurfaceVariant, height: 1.4)),
            ])),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.onSurfaceVariant),
          ]),
          SizedBox(height: 14),
          Wrap(spacing: 5, runSpacing: 5, children: features.map((f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(f, style: TextStyle(fontFamily: AppFonts.primary, fontSize: 11,
                fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          )).toList()),
        ]),
      ),
    );
  }
}
