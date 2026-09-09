import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/pet_toast.dart';
import '../device/data/repository/device_repository.dart';
import '../device/data/models/device_model.dart';
import '../device/data/models/device_product_model.dart';
import '../device/device_detail_page.dart';
import '../device/device_members_page.dart';
import '../device/robot_device_page.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import '../pet/bind_pet_sheet.dart';
import '../pet_circle/controller/pet_circle_pet_controller.dart';
import '../bind_device/select_device_page.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';
import '../../shared/theme/app_tokens.dart';

// ── 设备列表页 ────────────────────────────────────────────
class DeviceListPage extends ConsumerWidget {
  const DeviceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceListProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('我的设备',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          // 右上角刷新（加载中显示 loading）
          if (state.isLoading)
            Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)))
          else
            IconButton(
              icon: Icon(Icons.refresh_rounded),
              color: AppColors.onSurfaceVariant,
              onPressed: () => ref.read(deviceListProvider.notifier).load(),
            ),
          // ➕ 绑定新设备 — 先选类型
          IconButton(
            icon: Icon(Icons.add_rounded, size: 26),
            color: AppColors.primary,
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SelectDevicePage(),
                  ));
              ref.read(deviceListProvider.notifier).load();
            },
          ),
        ],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, DeviceListState state) {
    if (state.isLoading && state.devices.isEmpty) {
      return Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5));
    }
    if (state.errorMessage != null && state.devices.isEmpty) {
      return _buildError(context, ref, state.errorMessage!);
    }
    if (state.devices.isEmpty) {
      return _buildEmpty(context, ref);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(deviceListProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        itemCount: state.devices.length,
        separatorBuilder: (_, __) => SizedBox(height: 14),
        itemBuilder: (_, i) => _DeviceCard(device: state.devices[i]),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.devices_other_rounded,
          size: 80, color: AppColors.onSurfaceVariant.withOpacity(0.3)),
      SizedBox(height: 20),
      Text('还没有绑定设备',
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface)),
      SizedBox(height: 8),
      Text('选择类型，扫码绑定智能项圈或宠物机器人',
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 13,
              color: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center),
      SizedBox(height: 32),
      FilledButton.icon(
        onPressed: () async {
          HapticFeedback.mediumImpact();
          await Navigator.push(
              context, MaterialPageRoute(builder: (_) => SelectDevicePage()));
          ref.read(deviceListProvider.notifier).load();
        },
        icon: Icon(Icons.add_rounded),
        label: Text('添加设备',
            style: TextStyle(
                fontFamily: AppFonts.primary, fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape:
              const RoundedRectangleBorder(borderRadius: AppRadius.controlRadius),
        ),
      ),
    ]));
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String msg) {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded,
            size: 64, color: AppColors.onSurfaceVariant),
        SizedBox(height: 16),
        Text(msg,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 14,
                color: AppColors.onSurfaceVariant)),
        SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => ref.read(deviceListProvider.notifier).load(),
          child: Text('重试'),
        ),
      ]),
    ));
  }
}

// ── 设备卡片（带宠物信息） ─────────────────────────────────
class _DeviceCard extends ConsumerStatefulWidget {
  final DeviceModel device;
  const _DeviceCard({required this.device});

  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard> {
  PetInfoModel? _pet;
  bool _petLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.device.isCollar) {
      _loadPet();
    } else {
      _petLoading = false;
    }
  }

  Future<void> _loadPet() async {
    try {
      final pet = await ref
          .read(petPeerRepositoryProvider)
          .fetchPetInfo(mac: widget.device.mac);
      if (mounted)
        setState(() {
          _pet = pet;
          _petLoading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _pet = null;
          _petLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final deviceType = device.productType;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final deviceType = device.productType;
        await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => deviceType == DeviceProductType.robot
                  ? RobotDevicePage(mac: device.mac, name: device.displayName)
                  : DeviceDetailPage(mac: device.mac, name: device.displayName),
            ));
        if (deviceType == DeviceProductType.collar) {
          _loadPet();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outlineVariant, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 12,
              spreadRadius: -4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(children: [
          // ── 主信息行 ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(children: [
              // 设备类型图标
              _DeviceTypeIcon(type: deviceType, isOnline: device.isOnline),
              SizedBox(width: 12),
              // 设备名称 + 状态
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(device.displayName,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                            letterSpacing: -0.2)),
                    SizedBox(height: 4),
                    Row(children: [
                      Text(device.productDisplayName,
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant)),
                      SizedBox(width: 8),
                      // ── 角色标签 ──────────────────────────
                      _RoleBadge(device: device),
                      SizedBox(width: 8),
                      Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                              color: AppColors.outlineVariant,
                              shape: BoxShape.circle)),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'MAC: ${device.mac.length > 14 ? '...${device.mac.substring(device.mac.length - 10)}' : device.mac}',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ])),
              // 在线状态标签
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: device.isOnline
                      ? AppColors.statusOnlineSoft
                      : AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: device.isOnline
                            ? AppColors.statusOnline
                            : AppColors.statusNeutral,
                        shape: BoxShape.circle,
                      )),
                  SizedBox(width: 5),
                  Text(device.isOnline ? '在线' : '离线',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: device.isOnline
                              ? AppColors.statusOnlineStrong
                              : AppColors.statusNeutral)),
                ]),
              ),
            ]),
          ),

          if (deviceType == DeviceProductType.collar) ...[
            // ── 分割线 ────────────────────────────────────────
            Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: AppColors.outlineVariant),

            // ── 宠物行（仅项圈需要绑定宠物）───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: _petLoading
                  ? Row(children: [
                      Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest,
                              shape: BoxShape.circle)),
                      SizedBox(width: 10),
                      Container(
                          width: 80,
                          height: 11,
                          decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6))),
                    ])
                  : _pet != null && _pet!.petName.isNotEmpty
                      ? _buildPetRow(context)
                      : _buildNoPetRow(context),
            ),
          ],

          // ── 操作按钮行（仅 OWNER 显示）─────────────────────
          if (device.isOwner) ...[
            Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: AppColors.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                // ── 解绑按钮 ──
                _ActionPill(
                  icon: Icons.link_off_rounded,
                  label: '解绑设备',
                  color: AppColors.error,
                  onTap: () => _confirmUnbind(context, ref),
                ),
                SizedBox(width: 10),
                // ── 管理共享按钮 ──
                _ActionPill(
                  icon: Icons.group_outlined,
                  label: '管理共享',
                  color: AppColors.statusNeutral,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeviceMembersPage(
                            mac: device.mac,
                            deviceId: device.deviceId,
                            deviceName: device.displayName,
                            productKey: device.productKey,
                            productTypeName: device.productDisplayName,
                          ),
                        ));
                  },
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  /// 解绑确认弹窗（白底风格，与宠物删除弹窗一致）
  Future<void> _confirmUnbind(BuildContext context, WidgetRef ref) async {
    final device = widget.device;
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('解绑设备',
            style: TextStyle(
                fontFamily: AppFonts.primary, fontWeight: FontWeight.w800)),
        content: Text(
          '确定要解绑「${device.displayName}」吗？\n解绑后宠物数据将停止同步。',
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 13,
              color: AppColors.onSurfaceVariant),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: AppColors.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('确认解绑',
                style: TextStyle(fontFamily: AppFonts.primary)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      // 1. 先解绑宠物（如果有）
      try {
        await ref
            .read(petPeerRepositoryProvider)
            .deletePet(deviceId: device.deviceId);
      } catch (e) {
        // 如果宠物不存在或已解绑，忽略错误继续解绑设备
        debugPrint('[设备解绑] 宠物解绑跳过: $e');
      }
      // 2. 再解绑设备
      await ref.read(deviceRepositoryProvider).unbindDevice(device.mac);
      if (context.mounted) {
        HapticFeedback.mediumImpact();
        // 刷新列表（重新从后端拉取）
        await ref.read(deviceListProvider.notifier).load();
        // 弹"解绑成功"确认
        if (!context.mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dctx) => AlertDialog(
            backgroundColor: AppColors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: AppColors.statusOnline, size: 48),
                const SizedBox(height: 12),
                Text('设备已解绑',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface)),
                const SizedBox(height: 4),
                Text('「${device.displayName}」已成功解绑',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant)),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dctx),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('知道了',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        PetToast.error(context, '解绑失败，请重试');
      }
    }
  }

  Widget _buildPetRow(BuildContext context) {
    final pet = _pet!;
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final deviceType = widget.device.productType;
        await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => deviceType == DeviceProductType.robot
                  ? RobotDevicePage(
                      mac: widget.device.mac, name: widget.device.displayName)
                  : DeviceDetailPage(
                      mac: widget.device.mac, name: widget.device.displayName),
            ));
        if (deviceType == DeviceProductType.collar) {
          _loadPet();
        }
      },
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outlineVariant, width: 1),
          ),
          child: PetAvatar(imageUrl: pet.avatar, size: 33),
        ),
        SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pet.petName,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          Text(
            [
              if (pet.breed.isNotEmpty) pet.breed,
              if (pet.age > 0) '${pet.age}岁',
              if (pet.sex.isNotEmpty) pet.sexDisplay
            ].join(' · '),
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 10,
                color: AppColors.onSurfaceVariant),
          ),
        ])),
        Icon(Icons.chevron_right_rounded,
            color: AppColors.onSurfaceVariant, size: 18),
      ]),
    );
  }

  Widget _buildNoPetRow(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        final ok = await PetBindHelper.showAdd(context, mac: widget.device.mac);
        if (ok) {
          ref.read(petCirclePetControllerProvider.notifier).load();
          _loadPet();
        }
      },
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.22))),
            child: Icon(Icons.add_rounded, color: AppColors.primary, size: 20)),
        SizedBox(width: 10),
        Text('点击绑定宠物',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant)),
        Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text('绑定',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
      ]),
    );
  }
}

/// 操作药丸按钮（描边圆角，与宠物卡片按钮风格一致）
class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ]),
      ),
    );
  }
}

// ── 角色标签 chip ────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final DeviceModel device;
  const _RoleBadge({required this.device});

  @override
  Widget build(BuildContext context) {
    // 自有设备（主人）不显示额外标签，节省空间
    if (!device.isShared && device.isOwner) return const SizedBox.shrink();

    final Color bg;
    final Color fg;
    final IconData icon;

    if (device.isAdmin) {
      // ADMIN — 品牌浅底
      bg = AppColors.brandPrimarySoft;
      fg = AppColors.brandPrimaryStrong;
      icon = Icons.admin_panel_settings_outlined;
    } else {
      // MEMBER / 共享设备 — 灰色
      bg = AppColors.surfaceSunken;
      fg = AppColors.statusNeutral;
      icon = Icons.share_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: fg),
        const SizedBox(width: 3),
        Text(
          device.roleLabel,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ]),
    );
  }
}

// ── 设备类型枚举 ──────────────────────────────────────────
extension _DeviceProductTypeUiX on DeviceProductType {
  /// 在线状态下的渐变：所有产品统一品牌渐变（未知类型用中性）
  List<Color> get onlineGradient {
    switch (this) {
      case DeviceProductType.collar:
      case DeviceProductType.robot:
        return [AppColors.brandPrimary, AppColors.brandPrimaryStrong];
      case DeviceProductType.unknown:
        return [AppColors.statusNeutral, AppColors.textSecondary];
    }
  }

  Color get glowColor {
    switch (this) {
      case DeviceProductType.collar:
      case DeviceProductType.robot:
        return AppColors.brandPrimary;
      case DeviceProductType.unknown:
        return AppColors.statusNeutral;
    }
  }
}

// ── 设备类型图标 ──────────────────────────────────────────
class _DeviceTypeIcon extends StatelessWidget {
  final DeviceProductType type;
  final bool isOnline;
  const _DeviceTypeIcon({required this.type, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final gradient = isOnline
        ? type.onlineGradient
        : [AppColors.surfaceSunken, AppColors.borderSubtle];
    final iconColor = isOnline ? AppColors.textOnBrand : AppColors.textTertiary;

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: isOnline
            ? [
                BoxShadow(
                    color: type.glowColor.withOpacity(0.45),
                    blurRadius: 14,
                    spreadRadius: -2,
                    offset: Offset(0, 5)),
              ]
            : [],
      ),
      child: Center(
        child: switch (type) {
          DeviceProductType.collar => _CollarIcon(color: iconColor),
          DeviceProductType.robot => _RobotIcon(color: iconColor),
          DeviceProductType.unknown =>
            Icon(Icons.memory_rounded, color: iconColor, size: 28),
        },
      ),
    );
  }
}

// 项圈图标：环形 + 爪印
class _CollarIcon extends StatelessWidget {
  final Color color;
  const _CollarIcon({required this.color});
  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Icon(Icons.circle_outlined, color: color.withOpacity(0.5), size: 38),
      Icon(Icons.pets_rounded, color: color, size: 20),
      // 项圈扣具小装饰
      Positioned(
          bottom: 7,
          child: Container(
              width: 12,
              height: 3,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2)))),
    ]);
  }
}

// 机器人图标
class _RobotIcon extends StatelessWidget {
  final Color color;
  const _RobotIcon({required this.color});
  @override
  Widget build(BuildContext context) {
    return Icon(Icons.smart_toy_rounded, color: color, size: 32);
  }
}
