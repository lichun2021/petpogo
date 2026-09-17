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
import '../../device/device_detail_page.dart';
import '../../device/robot_device_page.dart';
import '../../pet_circle/controller/pet_circle_pet_controller.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';
import 'pet_picker_sheet.dart';

/// 首页"我的宠物"区块
/// 数据源与萌宠圈一致：petCirclePetControllerProvider
///   - 我的宠物（PeerApi /pet/info/list）
///   - 共享给我的宠物（业务后端 /pet/share/withme）
/// - 头像横滑 + 纯文字状态（在线/离线，围栏/低电等 PeerApi 接口就绪后接入）
/// - 末尾"添加"卡片 → 绑定设备页
/// - 点击宠物卡 → 该宠物设备详情页（优先项圈）
class PetMoodSection extends ConsumerStatefulWidget {
  const PetMoodSection({super.key});

  @override
  ConsumerState<PetMoodSection> createState() => _PetMoodSectionState();
}

class _PetMoodSectionState extends ConsumerState<PetMoodSection> {
  bool _loadTriggered = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authControllerProvider).isLoggedIn;
    final petState = ref.watch(petCirclePetControllerProvider);

    // 登录后触发一次加载（loadIfNeeded 内部有缓存判断）
    if (isLoggedIn && !_loadTriggered) {
      _loadTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(petCirclePetControllerProvider.notifier).loadIfNeeded();
      });
    }

    if (!isLoggedIn) return const SizedBox.shrink();

    final pets = petState.pets;

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
              onTap: () async {
                await PetPickerSheet.show(
                  context,
                  ref: ref,
                  onPicked: (petId) {
                    Future.delayed(const Duration(milliseconds: 60), () {
                      if (context.mounted) {
                        context.push(AppRoutes.healthData, extra: petId);
                      }
                    });
                  },
                );
              },
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

        // ── 加载中 ─────────────────────────────────────
        if (petState.isLoading && pets.isEmpty)
          SizedBox(
            height: 110,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        // ── 横滑圆形头像（与萌宠圈一致）+ 末尾添加卡 ────
        else
          SizedBox(
            height: 110, // 增加高度以容纳状态文字
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: pets.length + 1, // 末尾 +1 为添加卡
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) {
                if (i == pets.length) {
                  return _AddPetAvatar(onTap: () => context.push(AppRoutes.bindDevice));
                }
                final p = pets[i];
                return _PetAvatarTab(
                  petCirclePet: p,
                  onTap: () {
                    final device = p.device;
                    if (device.mac.isEmpty) {
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
      ],
    );
  }
}

// ── 宠物圆形头像 tab（与萌宠圈 _PetAvatarTab 一致）──────────
class _PetAvatarTab extends StatelessWidget {
  final PetCirclePet petCirclePet;
  final VoidCallback onTap;
  const _PetAvatarTab({required this.petCirclePet, required this.onTap});

  /// 构建状态文字：当前显示在线/离线，后续接入围栏状态后显示"围栏内""越界""低电"等
  String _buildStatusText(DeviceModel device) {
    if (device.mac.isEmpty) return '未绑定';
    // TODO: 接入 PeerApi /uclgwapp/pet/fence/status 后，优先显示围栏状态
    // 示例: if (device.fenceStatus == 'out') return '越界';
    //       if (device.fenceStatus == 'in') return '围栏内';
    //       if (device.battery < 20) return '低电量';
    return device.connect ? '在线' : '离线';
  }

  @override
  Widget build(BuildContext context) {
    final p = petCirclePet;
    final device = p.device;
    final online = device.mac.isNotEmpty && device.connect;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // 在线/离线边框色
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: online
                          ? AppColors.statusOnline
                          : device.mac.isEmpty
                              ? Colors.transparent
                              : AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                      width: 2.5,
                    ),
                  ),
                  child: PetAvatar(imageUrl: p.avatar, size: 54),
                ),
                // 共享角标
                if (p.isShared)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.surface, width: 1.2),
                      ),
                      child: const Text('共享',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              p.name.isEmpty ? '宠物' : p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 13,
                height: 1.1,
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            // 状态文字：在线/离线（预留围栏状态：围栏内/越界/低电等）
            Text(
              _buildStatusText(device),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 10,
                height: 1.1,
                color: online
                    ? AppColors.statusOnline
                    : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 添加宠物圆形卡 ────────────────────────────────────────
class _AddPetAvatar extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPetAvatar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3), width: 2.5),
              ),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
                child: Icon(Icons.add_rounded, size: 26, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text('添加',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
