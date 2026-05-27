/// 宠小伊 AI 问诊 — 首页入口 Banner
///
/// 点击逻辑：
///   - 无设备（已加载）→ 弹 Dialog 引导绑定设备
///   - 有设备（或正在加载）→ 弹出宠物选择 BottomSheet → 选中后跳转 /consultation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_colors.dart';
import '../../device/data/repository/device_repository.dart';
import 'pet_picker_sheet.dart';

class AiConsultationBanner extends ConsumerWidget {
  const AiConsultationBanner({super.key});

  /// 没有绑定设备时弹 Dialog
  void _showNoDeviceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '需要绑定设备',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: const Text(
          '使用 AI 问诊前，请先绑定您的宠物设备并完善宠物档案。',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              '稍后',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(AppRoutes.bindDevice);
            },
            child: Text(
              '去绑定设备',
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(deviceListProvider);

    // 已完成加载且无设备 → 锁定状态
    final isLocked =
        !deviceState.isLoading && deviceState.devices.isEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        HapticFeedback.lightImpact();
        if (isLocked) {
          _showNoDeviceDialog(context);
          return;
        }
        await PetPickerSheet.show(
          context,
          ref: ref,
          onPicked: (petId) {
            Future.delayed(const Duration(milliseconds: 60), () {
              if (context.mounted) {
                context.push(AppRoutes.consultation, extra: petId);
              }
            });
          },
        );
      },
      child: Opacity(
        opacity: isLocked ? 0.65 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.secondary,
                AppColors.secondary.withOpacity(0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // 左侧宠小伊形象
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/images/chongxiaoyi.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // 锁定状态时叠加 🔒
                  if (isLocked)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('🔒', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // 文案
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text(
                        '宠小伊 · AI 问诊',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (!isLocked) const _NewBadge(),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      isLocked
                          ? '请先绑定设备并添加宠物档案'
                          : '描述宠物症状，获得专业 AI 诊断建议',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // 右侧胶囊
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLocked ? '去绑定' : '立即问诊',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      isLocked
                          ? Icons.arrow_forward_rounded
                          : Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppColors.tertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
