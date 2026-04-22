import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_colors.dart';

/// 无设备引导横幅 — "The Curated Companion" 风格
/// 背景：primary → primaryContainer 渐变，无边框卡片
class NoDeviceBanner extends StatelessWidget {
  const NoDeviceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow,
            blurRadius: 32,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.pets_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '欢迎来到 PetPogo',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: AppColors.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '绑定设备，随时掌握宠物状态',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: AppColors.onPrimary.withOpacity(0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _DeviceTypeCard(
                  icon: Icons.key_rounded,
                  name: 'KeyTracker',
                  desc: '智能追踪器',
                  onTap: () => context.push('/bind-device'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DeviceTypeCard(
                  icon: Icons.smartphone_rounded,
                  name: 'PetPhone',
                  desc: '宠物智能手机',
                  onTap: () => context.push('/bind-device'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/bind-device'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(48),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('添加我的第一台设备'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTypeCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String desc;
  final VoidCallback onTap;

  const _DeviceTypeCard({
    required this.icon,
    required this.name,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
          // 仅允许 Ghost Border（15% 透明度）
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 10),
            Text(
              name,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Text(
              desc,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: AppColors.onPrimary.withOpacity(0.72),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
