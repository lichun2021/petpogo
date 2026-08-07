import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/pet_avatar.dart';
import '../../../shared/widgets/pet_toast.dart';
import '../../auth/controller/auth_controller.dart';
import '../../device/data/models/device_model.dart';
import '../../device/data/repository/device_repository.dart';
import '../../device/device_detail_page.dart';
import '../../device/robot_device_page.dart';
import '../../pet/controller/pet_controller.dart';
import '../../pet/data/models/pet_model.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

/// 首页"我的宠物"区块
/// - 头像横滑 + 纯文字状态（在线/离线，围栏/低电等 PeerApi 接口就绪后接入）
/// - 末尾"添加"卡片 → 绑定设备页
/// - 点击宠物卡 → 该宠物设备详情页（优先项圈）
class PetMoodSection extends ConsumerStatefulWidget {
  const PetMoodSection({super.key});

  @override
  ConsumerState<PetMoodSection> createState() => _PetMoodSectionState();
}

class _PetMoodSectionState extends ConsumerState<PetMoodSection> {
  int _page = 0;
  late final PageController _ctrl;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authControllerProvider).isLoggedIn;
    final petState = ref.watch(petControllerProvider);
    final deviceState = ref.watch(deviceListProvider);

    if (isLoggedIn && !_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(petControllerProvider.notifier).loadPets();
      });
    }

    if (!isLoggedIn) return const SizedBox.shrink();

    if (petState.isLoading) {
      return SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final pets = petState.pets;
    // 即使无宠物也渲染区块（只显示添加卡，引导用户添加）

    // 按 pet.linkedDeviceId 查设备
    DeviceModel? deviceForPet(PetModel pet) {
      final id = pet.linkedDeviceId;
      if (id.isEmpty) return null;
      try {
        return deviceState.devices.firstWhere((d) => d.deviceId == id);
      } catch (_) {
        return null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 标题行：我的宠物 + 健康数据 › ──────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('我的宠物',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                    height: 1.15)),
            GestureDetector(
              onTap: () => PetToast.show(context, '健康报告即将上线'),
              child: Text('健康数据 ›',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ],
        ),
        SizedBox(height: 12),

        // ── 横滑宠物卡 + 添加卡 ────────────────────────
        SizedBox(
          height: 96,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: pets.length + 1, // 末尾 +1 为添加卡
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              if (i == pets.length) {
                return _AddPetCard(
                  onTap: () => context.push(AppRoutes.bindDevice),
                );
              }
              final pet = pets[i];
              final device = deviceForPet(pet);
              return _HomePetCard(
                pet: pet,
                device: device,
                onTap: () {
                  if (device == null) {
                    PetToast.show(context, '该宠物未绑定设备');
                    return;
                  }
                  HapticFeedback.selectionClick();
                  final isRobot = device.productKey.contains('robot');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => isRobot
                          ? RobotDevicePage(
                              mac: device.mac, name: device.displayName)
                          : DeviceDetailPage(
                              mac: device.mac, name: device.displayName),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // ── 圆点指示（多宠物时显示）─────────────────────
        if (pets.length + 1 > 1) ...[
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                pets.length + 1,
                (i) => AnimatedContainer(
                      duration: Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    )),
          ),
        ],
      ],
    );
  }
}

// ── 首页宠物卡（纯文字状态）──────────────────────────────
class _HomePetCard extends StatelessWidget {
  final PetModel pet;
  final DeviceModel? device;
  final VoidCallback onTap;
  const _HomePetCard({required this.pet, this.device, required this.onTap});

  String get _statusText {
    if (device == null) return '未绑定设备';
    // 在线/离线（DeviceModel.connect）；围栏/低电等 PeerApi 接口就绪后接入，暂显"-"占位
    final online = device!.connect ? '在线' : '离线';
    return '$online · 围栏- · 电量-';
  }

  Color get _statusColor =>
      device == null
          ? AppColors.onSurfaceVariant
          : (device!.connect ? Color(0xFF34C759) : AppColors.onSurfaceVariant);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              PetAvatar(imageUrl: pet.avatar, size: 44, fallbackEmoji: pet.emoji),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface)),
                    SizedBox(height: 3),
                    Text(_statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor)),
                  ],
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── 添加宠物卡 ────────────────────────────────────────────
class _AddPetCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPetCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 24, color: AppColors.primary),
            SizedBox(height: 4),
            Text('添加',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
