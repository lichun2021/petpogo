import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../device/data/repository/device_repository.dart';
import '../device/data/models/device_model.dart';
import '../device/device_detail_page.dart';
import '../device/robot_device_page.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import '../pet/bind_pet_sheet.dart';
import '../bind_device/select_device_page.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

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
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('我的设备',
            style: TextStyle(fontFamily: AppFonts.primary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          // 右上角刷新（加载中显示 loading）
          if (state.isLoading)
            const Padding(padding: EdgeInsets.only(right: 8),
              child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.onSurfaceVariant,
              onPressed: () => ref.read(deviceListProvider.notifier).load(),
            ),
          // ➕ 绑定新设备 — 先选类型
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 26),
            color: AppColors.primary,
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SelectDevicePage(),
              ));
              ref.read(deviceListProvider.notifier).load();
            },
          ),
        ],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, DeviceListState state) {
    if (state.isLoading && state.devices.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5));
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
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) => _DeviceCard(device: state.devices[i]),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.devices_other_rounded, size: 80, color: AppColors.onSurfaceVariant.withOpacity(0.3)),
      const SizedBox(height: 20),
      const Text('还没有绑定设备', style: TextStyle(fontFamily: AppFonts.primary,
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
      const SizedBox(height: 8),
      Text('选择类型，扫码绑定智能项圈或宠物机器人',
          style: TextStyle(fontFamily: AppFonts.primary, fontSize: 13,
              color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
      const SizedBox(height: 32),
      FilledButton.icon(
        onPressed: () async {
          HapticFeedback.mediumImpact();
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SelectDevicePage()));
          ref.read(deviceListProvider.notifier).load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加设备', style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ]));
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String msg) {
    return Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(msg, textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: AppFonts.primary, fontSize: 14,
                color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => ref.read(deviceListProvider.notifier).load(),
          child: const Text('重试'),
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
    _loadPet();
  }

  Future<void> _loadPet() async {
    try {
      final pet = await ref.read(petPeerRepositoryProvider)
          .fetchPetInfo(mac: widget.device.mac);
      if (mounted) setState(() { _pet = pet; _petLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _pet = null; _petLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final deviceType = _detectType(device);

    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final deviceType = _detectType(device);
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => deviceType == _DeviceType.robot
              ? RobotDevicePage(mac: device.mac, name: device.displayName)
              : DeviceDetailPage(mac: device.mac, name: device.displayName),
        ));
        // 返回后刷新宠物信息
        _loadPet();
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: device.isOnline
                ? [const Color(0xFF1e1e2e), const Color(0xFF2a2440)]
                : [const Color(0xFF1e1e2e), const Color(0xFF252525)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.22),
                blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(children: [
          // ── 主信息行 ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(children: [
              // 设备类型图标
              _DeviceTypeIcon(type: deviceType, isOnline: device.isOnline),
              const SizedBox(width: 14),
              // 设备名称 + 状态
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(device.displayName, style: const TextStyle(fontFamily: AppFonts.primary,
                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Row(children: [
                  Text(deviceType.label, style: TextStyle(fontFamily: AppFonts.primary,
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.45))),
                  const SizedBox(width: 8),
                  Container(width: 4, height: 4, decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('MAC: ${device.mac.length > 14 ? '...${device.mac.substring(device.mac.length - 10)}' : device.mac}',
                      style: TextStyle(fontFamily: AppFonts.primary, fontSize: 10,
                          color: Colors.white.withOpacity(0.35))),
                ]),
              ])),
              // 在线状态标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: device.isOnline
                      ? const Color(0xFF4ADE80).withOpacity(0.15)
                      : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 5, height: 5,
                      decoration: BoxDecoration(
                        color: device.isOnline ? const Color(0xFF4ADE80) : Colors.white38,
                        shape: BoxShape.circle,
                      )),
                  const SizedBox(width: 5),
                  Text(device.isOnline ? '在线' : '离线',
                      style: TextStyle(fontFamily: AppFonts.primary, fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: device.isOnline ? const Color(0xFF4ADE80) : Colors.white38)),
                ]),
              ),
            ]),
          ),

          // ── 分割线 ────────────────────────────────────────
          Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 18),
              color: Colors.white.withOpacity(0.07)),

          // ── 宠物行 ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: _petLoading
                ? Row(children: [
                    Container(width: 32, height: 32,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Container(width: 80, height: 11,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6))),
                  ])
                : _pet != null && _pet!.petName.isNotEmpty
                    ? _buildPetRow(context)
                    : _buildNoPetRow(context),
          ),
        ]),
      ),
    );
  }

  Widget _buildPetRow(BuildContext context) {
    final pet = _pet!;
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final deviceType = _detectType(widget.device);
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => deviceType == _DeviceType.robot
              ? RobotDevicePage(mac: widget.device.mac, name: widget.device.displayName)
              : DeviceDetailPage(mac: widget.device.mac, name: widget.device.displayName),
        ));
        _loadPet();
      },
      child: Row(children: [
        // 宠物头像
        Container(width: 36, height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5)),
          child: ClipOval(
            child: pet.avatar.isNotEmpty
                ? CachedNetworkImage(imageUrl: pet.avatar, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _petEmoji(pet.petName))
                : _petEmoji(pet.petName),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pet.petName, style: const TextStyle(fontFamily: AppFonts.primary,
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(
            [if (pet.breed.isNotEmpty) pet.breed,
             if (pet.age > 0) '${pet.age}岁',
             if (pet.sex.isNotEmpty) pet.sexDisplay].join(' · '),
            style: TextStyle(fontFamily: AppFonts.primary, fontSize: 10,
                color: Colors.white.withOpacity(0.4)),
          ),
        ])),
        const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
      ]),
    );
  }

  Widget _buildNoPetRow(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        final ok = await PetBindHelper.showAdd(context, mac: widget.device.mac);
        if (ok) _loadPet();
      },
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.07),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.12))),
          child: const Icon(Icons.add_rounded, color: Colors.white38, size: 20)),
        const SizedBox(width: 10),
        Text('点击绑定宠物', style: TextStyle(fontFamily: AppFonts.primary,
            fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white38)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text('绑定', style: TextStyle(fontFamily: AppFonts.primary,
              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary.withOpacity(0.8))),
        ),
      ]),
    );
  }

  Widget _petEmoji(String name) {
    // 简单判断常见宠物 emoji
    return Container(color: AppColors.primary.withOpacity(0.2),
        child: Center(child: Text(
          name.contains('猫') || name.toLowerCase().contains('cat') ? '🐱'
              : name.contains('狗') || name.toLowerCase().contains('dog') ? '🐶' : '🐾',
          style: const TextStyle(fontSize: 20),
        )));
  }

  _DeviceType _detectType(DeviceModel d) {
    final key  = d.productKey.toLowerCase();
    final name = d.displayName.toLowerCase();
    // 机器人判断（名称/productKey 含 robot/机器人）
    if (key.contains('robot') || name.contains('机器人') || name.contains('robot') ||
        key.contains('bot') || name.contains('bot')) {
      return _DeviceType.robot;
    }
    // 其余默认为智能项圈
    return _DeviceType.collar;
  }
}

// ── 设备类型枚举 ──────────────────────────────────────────
enum _DeviceType { collar, robot }

extension _DeviceTypeX on _DeviceType {
  String get label {
    switch (this) {
      case _DeviceType.collar: return '智能项圈';
      case _DeviceType.robot:  return '智能宠物机器人';
    }
  }

  /// 在线状态下的渐变色：项圈=橙色系，机器人=青色系
  List<Color> get onlineGradient {
    switch (this) {
      case _DeviceType.collar:
        return [const Color(0xFFff784e), const Color(0xFFa83206)];
      case _DeviceType.robot:
        return [const Color(0xFF00897B), const Color(0xFF006760)];
    }
  }

  Color get glowColor {
    switch (this) {
      case _DeviceType.collar: return const Color(0xFFff784e);
      case _DeviceType.robot:  return const Color(0xFF7fe6db);
    }
  }
}

// ── 设备类型图标 ──────────────────────────────────────────
class _DeviceTypeIcon extends StatelessWidget {
  final _DeviceType type;
  final bool isOnline;
  const _DeviceTypeIcon({required this.type, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final gradient = isOnline
        ? type.onlineGradient
        : [const Color(0xFF2c2c3e), const Color(0xFF1e1e2a)];
    final iconColor = isOnline ? Colors.white : Colors.white24;

    return Container(
      width: 58, height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: isOnline ? [
          BoxShadow(color: type.glowColor.withOpacity(0.45),
              blurRadius: 14, spreadRadius: -2, offset: const Offset(0, 5)),
        ] : [],
      ),
      child: Center(
        child: type == _DeviceType.collar
            ? _CollarIcon(color: iconColor)
            : _RobotIcon(color: iconColor),
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
      Positioned(bottom: 7,
        child: Container(width: 12, height: 3,
          decoration: BoxDecoration(color: color.withOpacity(0.6),
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
