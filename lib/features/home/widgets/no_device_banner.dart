import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_colors.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

class NoDeviceBanner extends StatelessWidget {
  const NoDeviceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/bind-device');
        },
        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
        label: const Text('添加我的第一台设备'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.primary.withOpacity(0.06),
          side: BorderSide(color: AppColors.primary.withOpacity(0.30), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
