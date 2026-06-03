import 'package:flutter/material.dart';
import '../../shared/theme/app_colors.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

/// 宠物轨迹页（占位，后续接入轨迹接口）
class PetTrackPage extends StatelessWidget {
  final String petName;
  final String deviceMac;
  const PetTrackPage({super.key, required this.petName, required this.deviceMac});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('$petName 的轨迹',
            style: const TextStyle(fontFamily: AppFonts.primary,
                fontSize: 15, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.route_rounded, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text('轨迹功能即将上线', style: TextStyle(
            fontFamily: AppFonts.primary, fontSize: 18,
            fontWeight: FontWeight.w700, color: AppColors.onSurface,
          )),
          const SizedBox(height: 8),
          const Text('将记录宠物的历史活动路径\n帮助你了解它的日常行踪',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppFonts.primary, fontSize: 13,
                  color: AppColors.onSurfaceVariant, height: 1.6)),
          const SizedBox(height: 4),
          Text('设备：$deviceMac', style: const TextStyle(
              fontFamily: AppFonts.primary, fontSize: 11,
              color: AppColors.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
