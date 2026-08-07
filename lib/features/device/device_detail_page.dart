import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/pet_toast.dart';
import '../device/data/repository/device_repository.dart';
import '../device/data/models/device_model.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import '../pet/pet_location_page.dart';
import '../pet/bind_pet_sheet.dart';
import '../pet_circle/controller/pet_circle_pet_controller.dart';
import 'safety_scene_page.dart';
import 'robot_device_page.dart';
import '../bind_device/select_device_page.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

// ── 设备详情页 ────────────────────────────────────────────
class DeviceDetailPage extends ConsumerStatefulWidget {
  final String mac;
  final String name;
  const DeviceDetailPage({super.key, required this.mac, required this.name});

  @override
  ConsumerState<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends ConsumerState<DeviceDetailPage> {
  DeviceDetailModel? _detail;
  PetInfoModel? _petInfo;
  OtaInfoModel? _otaInfo;
  bool _loading = true;
  String? _error;
  bool? _online; // 实时在线态（按 mac 查，优先于 detail.onlineStatus）

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  /// 在线态：优先实时接口结果，回退 detail.onlineStatus
  bool get _isOnline => _online ?? (_detail?.onlineStatus ?? false);

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(deviceRepositoryProvider);
      final petRepo = ref.read(petPeerRepositoryProvider);
      final results = await Future.wait([
        repo.fetchDeviceDetail(widget.mac),
        petRepo.fetchPetInfo(mac: widget.mac).catchError((_) => PetInfoModel()),
        repo.fetchOtaInfo(widget.mac).catchError((_) => OtaInfoModel()),
        repo.fetchOnlineState(widget.mac).catchError((_) => false),
      ]);
      if (mounted) {
        setState(() {
          _detail = results[0] as DeviceDetailModel;
          _petInfo = results[1] as PetInfoModel;
          _otaInfo = results[2] as OtaInfoModel;
          _online = results[3] as bool;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5))
          : _error != null
              ? _buildError()
              : CustomScrollView(slivers: [
                  _buildAppBar(context),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverList(
                        delegate: SliverChildListDelegate([
                      SizedBox(height: 20),
                      _buildStatusHero(),
                      SizedBox(height: 20),
                      // 宠物区块（始终显示：有宠物显示详情，无宠物显示绑定入口）
                      _buildPetSection(context),
                      SizedBox(height: 20),
                      if (_otaInfo != null && _otaInfo!.isUpgrade)
                        _buildOtaBanner(),
                      if (_otaInfo != null && _otaInfo!.isUpgrade)
                        SizedBox(height: 20),
                      // 今日安全概览（有宠物时显示）
                      if (_petInfo != null && _petInfo!.petName.isNotEmpty) ...[
                        _buildSafetyOverview(context),
                        SizedBox(height: 20),
                        _buildSafetyScenes(context),
                        SizedBox(height: 20),
                      ],
                      // 互动模块已删除（声光硬件已砍，查看位置/即时轨迹迁移至地图定位页）
                      // 安全设置模块已删除（立即寻找声光已砍，由地图导航替代；历史轨迹本轮不保留）
                      _buildActions(context),
                    ])),
                  ),
                ]),
    );
  }

  Widget _buildError() {
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline_rounded,
          size: 64, color: AppColors.onSurfaceVariant),
      SizedBox(height: 16),
      Text(_error!,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 14,
              color: AppColors.onSurfaceVariant)),
      SizedBox(height: 16),
      OutlinedButton(onPressed: _loadAll, child: Text('重试')),
    ]));
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, size: 20),
        color: AppColors.onSurface,
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () => _showDeviceSwitcher(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _detail?.displayName ?? widget.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: AppColors.onSurface),
          ],
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.add_circle_outline_rounded),
          color: AppColors.primary,
          tooltip: '添加设备',
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SelectDevicePage(),
                ));
          },
        ),
      ],
    );
  }

  // ── 设备切换弹窗 ──────────────────────────────────────
  void _showDeviceSwitcher(BuildContext context) {
    final devices = ref.read(deviceListProvider).devices;
    if (devices.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DeviceSwitcherSheet(
        devices: devices,
        currentMac: widget.mac,
        onSelect: (device) {
          Navigator.pop(context);
          if (device.mac == widget.mac) return;
          final isRobot = device.isRobot;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => isRobot
                  ? RobotDevicePage(mac: device.mac, name: device.displayName)
                  : DeviceDetailPage(mac: device.mac, name: device.displayName),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusHero() {
    final online = _isOnline;
    final deviceName = _detail?.name ?? widget.name;
    return GestureDetector(
      onTap: () => _showRemarkDialog(context), // 点击卡片任意区域也可编辑
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6b1a01), Color(0xFF9e2f04), Color(0xFFe85d26)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.30),
                blurRadius: 28,
                spreadRadius: -6,
                offset: Offset(0, 10))
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // 左侧图标
          Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Colors.white.withOpacity(0.2), width: 1.5),
              ),
              child: Icon(Icons.router_rounded, color: Colors.white, size: 32)),
          SizedBox(width: 16),
          // 中间信息
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // 设备名称 + 编辑图标
                Row(children: [
                  Flexible(
                    child: Text(deviceName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3)),
                  ),
                  SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child:
                        Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                  ),
                ]),
                SizedBox(height: 5),
                // 在线状态徽章
                Row(children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: online ? Color(0xFF4ADE80) : Colors.white38,
                          shape: BoxShape.circle)),
                  SizedBox(width: 5),
                  Text(online ? '在线' : '离线',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: online ? Color(0xFF4ADE80) : Colors.white60)),
                ]),
                SizedBox(height: 8),
                // 电量 + 设备码（PeerApi 电量接口未就绪，电量先占位）
                Row(children: [
                  Icon(Icons.battery_std_rounded,
                      size: 12, color: Colors.white70),
                  SizedBox(width: 4),
                  Text('电量 -',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70)),
                  SizedBox(width: 12),
                  Text('设备码',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 10,
                          color: Colors.white54)),
                  SizedBox(width: 4),
                  Text(widget.mac,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 0.5)),
                ]),
              ])),
        ]),
      ),
    );
  }

  // ── 宠物区块：有宠物显示详情 + 编辑/删除，无宠物显示绑定入口 ──
  Widget _buildPetSection(BuildContext context) {
    final hasPet = _petInfo != null && _petInfo!.petName.isNotEmpty;

    if (!hasPet) {
      return GestureDetector(
        onTap: () async {
          final ok = await PetBindHelper.showAdd(context, mac: widget.mac);
          if (ok) {
            ref.read(petCirclePetControllerProvider.notifier).load();
            _loadAll();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle),
                child: Icon(Icons.add_rounded,
                    color: AppColors.primary, size: 26)),
            SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('绑定宠物',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  Text('点此添加宠物信息，开始跟踪位置、管理围栏',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant)),
                ])),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.primary, size: 20),
          ]),
        ),
      );
    }

    final pet = _petInfo!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('绑定的宠物',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface)),
        Row(children: [
          _SmallAction(
              icon: Icons.edit_rounded,
              label: '编辑',
              onTap: () async {
                final ok = await PetBindHelper.showEdit(
                  context,
                  mac: widget.mac,
                  pet: pet,
                );
                if (ok) {
                  ref.read(petCirclePetControllerProvider.notifier).load();
                  _loadAll();
                }
              }),
          SizedBox(width: 8),
          _SmallAction(
              icon: Icons.delete_outline_rounded,
              label: '删除',
              color: AppColors.error,
              onTap: () => _confirmDeletePet(context, pet)),
        ]),
      ]),
      SizedBox(height: 12),
      GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PetLocationPage(
                  petName: pet.petName,
                  deviceMac: widget.mac,
                  petAvatar: pet.avatar),
            )),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceContainerHigh)),
          child: Row(children: [
            PetAvatar(imageUrl: pet.avatar, size: 46),
            SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(pet.petName,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  Text(
                    [
                      if (pet.breed.isNotEmpty) pet.breed,
                      if (pet.age > 0) '${pet.age}岁',
                      if (pet.weight.isNotEmpty) '${pet.weight}kg',
                      if (pet.sex.isNotEmpty) pet.sexDisplay
                    ].join(' · '),
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant),
                  ),
                ])),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('查看位置',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary)),
              ),
              SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant, size: 20),
            ]),
          ]),
        ),
      ),
    ]);
  }

  void _confirmDeletePet(BuildContext context, PetInfoModel pet) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('删除宠物',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w700)),
              content: Text('确定要删除「${pet.petName}」吗？删除后数据不可恢复。',
                  style: TextStyle(fontFamily: AppFonts.primary)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx), child: Text('取消')),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx); // 用 dialog 自己的 ctx，避免 null state 崩溃
                    try {
                      await ref.read(petPeerRepositoryProvider).deletePet(
                            petId: pet.petId.isNotEmpty ? pet.petId : null,
                            // 不传 deviceId：避免后端把设备关联一并删除
                          );
                      await _loadAll();
                      if (mounted) PetToast.success(context, '宠物已删除');
                    } catch (e) {
                      if (mounted)
                        PetToast.error(context,
                            e.toString().replaceAll('Exception: ', ''));
                    }
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('删除'),
                ),
              ],
            ));
  }

  Widget _buildOtaBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tertiary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tertiary.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.system_update_rounded, color: AppColors.tertiary, size: 22),
        SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('有新版本可升级',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tertiary)),
          Text(_otaInfo?.msg ?? '',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant)),
        ])),
        TextButton(
            onPressed: () => PetToast.warning(context, '设备升级功能即将上线'),
            child: Text('升级', style: TextStyle(color: AppColors.tertiary))),
      ]),
    );
  }

  // ── 今日安全概览 ────────────────────────────────────────
  Widget _buildSafetyOverview(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text('今日安全概览',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800))),
        GestureDetector(
          onTap: () => PetToast.warning(context, '更多功能即将上线'),
          child: Text('更多',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
        ),
      ]),
      SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: Offset(0, 3))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 统计数字
          Row(children: [
            Expanded(
                child: Column(children: [
              Text('0',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onSurface)),
              Text('预警提醒',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant)),
            ])),
            Container(width: 1, height: 36, color: AppColors.outlineVariant),
            Expanded(
                child: Column(children: [
              Text('0',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onSurface)),
              Text('越界提醒',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant)),
            ])),
          ]),
        ]),
      ),
    ]);
  }

  // ── 安全场景 → 安全设置入口 ─────────────────────────────
  Widget _buildSafetyScenes(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SceneCard(
        color: Color(0xFFE8F5E9),
        iconBg: Color(0xFF4CAF50),
        icon: Icons.shield_rounded,
        title: '安全设置',
        subtitle: '设定安全范围，开启虚拟围栏警告',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SafetyScenePage(
                  deviceMac: widget.mac,
                  deviceName: widget.name,
                  petName: _petInfo?.petName ?? ''),
            )),
      ),
    ]);
  }

  // ── 互动模块已删除（声光硬件已砍，查看位置/即时轨迹迁移至地图定位页）──

  // ── 安全设置模块已删除（立即寻找声光已砍，由地图导航替代；历史轨迹本轮不保留）──

  Widget _buildActions(BuildContext context) {
    final hasPet = _petInfo != null && _petInfo!.petName.isNotEmpty;
    return Column(children: [
      if (!hasPet) ...[
        _ActionButton(
          icon: Icons.pets_rounded,
          label: '绑定宠物',
          color: AppColors.secondary,
          fullWidth: true,
          onTap: () async {
            final ok = await PetBindHelper.showAdd(context, mac: widget.mac);
            if (ok) {
              ref.read(petCirclePetControllerProvider.notifier).load();
              _loadAll();
            }
          },
        ),
      ],
    ]);
  }

  void _showRemarkDialog(BuildContext context) {
    final ctrl = TextEditingController(text: widget.name);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('设备备注',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w700)),
              content: TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                      hintText: '输入备注内容',
                      filled: true,
                      fillColor: AppColors.surfaceContainer,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx), child: Text('取消')),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref
                          .read(deviceRepositoryProvider)
                          .updateDeviceName(widget.mac, ctrl.text);
                      await ref.read(deviceListProvider.notifier).load();
                      await _loadAll();
                    } catch (e) {
                      debugPrint('[DeviceDetail] 备注失败: $e');
                    }
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('保存'),
                ),
              ],
            ));
  }

  void _showUnbindDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('解绑设备',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w700)),
              content: Text('确定要解绑「${widget.name}」吗？解绑后宠物数据将停止同步。',
                  style: TextStyle(fontFamily: AppFonts.primary)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx), child: Text('取消')),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx); // 关 dialog（用 dialog 自己的 ctx）
                    try {
                      // 1. 先解绑宠物（如果有）
                      try {
                        // 先查询宠物信息获取 deviceId
                        final pet = await ref
                            .read(petPeerRepositoryProvider)
                            .fetchPetInfo(mac: widget.mac);
                        if (pet.petId.isNotEmpty) {
                          await ref
                              .read(petPeerRepositoryProvider)
                              .deletePet(petId: pet.petId);
                          debugPrint('[设备解绑] 宠物已解绑: ${pet.petName}');
                        }
                      } catch (e) {
                        // 如果宠物不存在或已解绑，忽略错误继续解绑设备
                        debugPrint('[设备解绑] 宠物解绑跳过: $e');
                      }

                      // 2. 再解绑设备
                      await ref
                          .read(deviceRepositoryProvider)
                          .unbindDevice(widget.mac);
                      // 刷新设备列表（从后端重新拉取，确保一致）
                      await ref.read(deviceListProvider.notifier).load();
                      if (!mounted) return;
                      // 3. 弹"解绑成功"确认
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
                              Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF22C55E), size: 48),
                              const SizedBox(height: 12),
                              Text('设备已解绑',
                                  style: TextStyle(
                                      fontFamily: AppFonts.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.onSurface)),
                              const SizedBox(height: 4),
                              Text('「${widget.name}」已成功解绑',
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
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                child: Text('知道了',
                                    style: TextStyle(
                                        fontFamily: AppFonts.primary,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      );
                      // 4. 确认后退出设备详情页
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      debugPrint('[DeviceDetail] 解绑失败: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('解绑失败，请重试')),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('确认解绑'),
                ),
              ],
            ));
  }
}

// ── 小操作按钮（用于宠物区块右上角 编辑/删除）────────────
class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _SmallAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurfaceVariant;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: c.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: c),
          SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c)),
        ]),
      ),
    );
  }
}

// ── 操作大按钮 ─────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool fullWidth;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color,
      this.fullWidth = false});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurface;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: c.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withOpacity(0.18))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: c, size: 20),
          SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c)),
        ]),
      ),
    );
  }
}

// ── 安全场景卡片 ───────────────────────────────────────────
class _SceneCard extends StatelessWidget {
  final Color color, iconBg;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _SceneCard({
    required this.color,
    required this.iconBg,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 11,
                          color: Colors.black.withOpacity(0.5))),
                ])),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.black38),
          ]),
        ),
      );
}

// ── _InteractTile 已删除（互动/安全设置模块移除后无引用）──

// ── 设备切换底部弹窗（项圈详情页使用）────────────────────────
class _DeviceSwitcherSheet extends StatelessWidget {
  final List<DeviceModel> devices;
  final String currentMac;
  final ValueChanged<DeviceModel> onSelect;

  const _DeviceSwitcherSheet({
    required this.devices,
    required this.currentMac,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 拖拽指示条
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('切换设备',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E))),
        ),
        SizedBox(height: 16),
        ...devices.map((d) {
          final isSelected = d.mac == currentMac;
          final isRobot = d.isRobot;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(d);
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.07)
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.4)
                      : AppColors.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: Row(children: [
                // 设备图标
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isRobot
                          ? [Color(0xFF00897B), Color(0xFF006760)]
                          : [Color(0xFFff784e), Color(0xFFa83206)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isRobot ? Icons.smart_toy_rounded : Icons.pets_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(d.displayName,
                          style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.onSurface,
                          )),
                      SizedBox(height: 2),
                      Row(children: [
                        Text(isRobot ? '智能宠物机器人' : '智能项圈',
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant)),
                        SizedBox(width: 8),
                        Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: d.isOnline
                                  ? Color(0xFF4ADE80)
                                  : AppColors.onSurfaceVariant,
                              shape: BoxShape.circle,
                            )),
                        SizedBox(width: 4),
                        Text(d.isOnline ? '在线' : '离线',
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant)),
                      ]),
                    ])),
                if (isSelected)
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 20),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}
