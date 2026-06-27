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
import '../pet/pet_track_page.dart';
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
  bool _ringing = false; // 响铃进行中
  bool _ledOn = false; // LED 当前状态（本地 toggle，无法从设备读回）
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
                      // 互动 & 安全设置
                      _buildControls(context),
                      SizedBox(height: 20),
                      _buildSafetySettings(context),
                      SizedBox(height: 20),
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
          final isRobot = _isRobotDevice(device);
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

  bool _isRobotDevice(DeviceModel d) {
    final key = d.productKey.toLowerCase();
    final name = d.displayName.toLowerCase();
    return key.contains('robot') ||
        name.contains('机器人') ||
        name.contains('robot') ||
        key.contains('bot') ||
        name.contains('bot');
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
                // MAC 地址 chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Text(widget.mac,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 0.5)),
                ),
              ])),
          // 右侧最后在线时间
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.access_time_rounded,
                      size: 10, color: Colors.white60),
                  SizedBox(width: 4),
                  Text(
                    _detail?.lastOnlineDisplay ?? '-',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 10,
                        color: Colors.white70),
                  ),
                ])),
          ]),
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
            onPressed: () {},
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
          // 状态横幅
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFFFFF1F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle),
                child: Icon(Icons.bolt_rounded,
                    size: 16, color: AppColors.primary),
              ),
              SizedBox(width: 10),
              Text('宠物行为活跃，安心守护中',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ]),
          ),
          SizedBox(height: 14),
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
          SizedBox(height: 14),
          // 实时动态入口
          GestureDetector(
            onTap: () => PetToast.warning(context, '实时动态即将上线'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(
                    child: Text('实时动态',
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700))),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.onSurfaceVariant),
              ]),
            ),
          ),
          SizedBox(height: 8),
          Row(children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: Color(0xFF4ADE80), shape: BoxShape.circle)),
            SizedBox(width: 8),
            Expanded(
                child: Text('在安全区域内',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface))),
            Text(
              () {
                final n = DateTime.now();
                return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
              }(),
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant),
            ),
          ]),
          SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text('宠物当前在围栏内，安心活动',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant)),
          ),
        ]),
      ),
    ]);
  }

  // ── 安全场景 ─────────────────────────────────────────────
  Widget _buildSafetyScenes(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('安全场景',
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      SizedBox(height: 12),
      _SceneCard(
        color: Color(0xFFFFF3E0),
        iconBg: Color(0xFFFF9800),
        icon: Icons.home_rounded,
        title: '居家场景',
        subtitle: '室内监控安全区域，低功耗定位模式',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SafetyScenePage(
                  deviceMac: widget.mac,
                  deviceName: widget.name,
                  petName: _petInfo?.petName ?? '',
                  initialTab: 0),
            )),
      ),
      SizedBox(height: 10),
      _SceneCard(
        color: Color(0xFFE8F5E9),
        iconBg: Color(0xFF4CAF50),
        icon: Icons.park_rounded,
        title: '外出场景',
        subtitle: '户外活动区域，开启虚拟围栏告警',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SafetyScenePage(
                  deviceMac: widget.mac,
                  deviceName: widget.name,
                  petName: _petInfo?.petName ?? '',
                  initialTab: 1),
            )),
      ),
      // SizedBox(height: 10),
      // _SceneCard(
      //   color: Color(0xFFEDE7F6),
      //   iconBg: Color(0xFF7C4DFF),
      //   icon: Icons.local_hospital_rounded,
      //   title: '服务中心',
      //   subtitle: '专业护理医疗环境，自动关联健康检测数据',
      //   onTap: () => PetToast.warning(context, '服务中心即将上线'),
      // ),
    ]);
  }

  // ── 互动（设备功能，重新设计为网格）──────────────────────
  Widget _buildControls(BuildContext context) {
    final hasPet = _petInfo != null && _petInfo!.petName.isNotEmpty;
    final isOnline = _isOnline;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('互动',
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.4,
        children: [
          _InteractTile(
            icon: Icons.lightbulb_rounded,
            iconColor: _ledOn ? Color(0xFFFFD60A) : AppColors.primary,
            label: _ledOn ? '关闭亮灯' : '亮灯',
            enabled: isOnline,
            active: _ledOn,
            onTap: isOnline
                ? _toggleLed
                : () => PetToast.warning(context, '设备离线，无法操作'),
          ),
          _InteractTile(
            icon: Icons.notifications_active_rounded,
            iconColor: _ringing ? Color(0xFFFF6B35) : AppColors.primary,
            label: _ringing ? '停止响铃' : '响铃',
            enabled: isOnline,
            active: _ringing,
            onTap: isOnline
                ? _toggleRing
                : () => PetToast.warning(context, '设备离线，无法操作'),
          ),
          _InteractTile(
            icon: Icons.location_on_rounded,
            iconColor: AppColors.primary,
            label: '查看位置',
            enabled: hasPet,
            onTap: hasPet
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PetLocationPage(
                            petName: _petInfo!.petName,
                            deviceMac: widget.mac,
                            petAvatar: _petInfo!.avatar)))
                : () => PetToast.warning(context, '请先绑定宠物'),
          ),
          _InteractTile(
            icon: Icons.route_rounded,
            iconColor: AppColors.primary,
            label: '即时轨迹',
            enabled: hasPet,
            onTap: hasPet
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PetTrackPage(
                            petName: _petInfo!.petName, deviceMac: widget.mac)))
                : () => PetToast.warning(context, '请先绑定宠物'),
          ),
        ],
      ),
    ]);
  }

  // ── 安全设置 ─────────────────────────────────────────────
  Widget _buildSafetySettings(BuildContext context) {
    final hasPet = _petInfo != null && _petInfo!.petName.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('安全设置',
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.4,
        children: [
          _InteractTile(
            icon: Icons.route_rounded,
            iconColor: AppColors.secondary,
            label: '历史轨迹',
            enabled: hasPet,
            onTap: hasPet
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PetTrackPage(
                            petName: _petInfo!.petName, deviceMac: widget.mac)))
                : () => PetToast.warning(context, '请先绑定宠物'),
          ),
          _InteractTile(
            icon: Icons.search_rounded,
            iconColor: AppColors.primary,
            label: '立即寻找',
            enabled: _isOnline,
            onTap: _isOnline
                ? _toggleRing
                : () => PetToast.warning(context, '设备离线，无法操作'),
          ),
        ],
      ),
    ]);
  }

  Future<void> _toggleRing() async {
    final next = !_ringing;
    setState(() => _ringing = next);
    try {
      await ref.read(deviceRepositoryProvider).shadowUpdate(
        mac: widget.mac,
        data: {'ring_tone': next ? '1' : '0'},
      );
    } catch (e) {
      if (mounted) {
        setState(() => _ringing = !next);
        PetToast.error(
            context, '响铃失败：${e.toString().replaceAll("Exception: ", "")}');
      }
    }
  }

  Future<void> _toggleLed() async {
    final next = !_ledOn;
    setState(() => _ledOn = next);
    try {
      await ref.read(deviceRepositoryProvider).shadowUpdate(
        mac: widget.mac,
        data: {
          'led_r': next ? 'true' : 'false',
          'led_g': next ? 'true' : 'false',
          'led_b': next ? 'true' : 'false',
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _ledOn = !next);
        PetToast.error(
            context, 'LED 控制失败：${e.toString().replaceAll("Exception: ", "")}');
      }
    }
  }

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
                      await ref
                          .read(deviceRepositoryProvider)
                          .unbindDevice(widget.mac);
                      ref
                          .read(deviceListProvider.notifier)
                          .removeDevice(widget.mac);
                      if (mounted)
                        Navigator.pop(context); // 退出设备详情页（用页面 context）
                    } catch (e) {
                      debugPrint('[DeviceDetail] 解绑失败: $e');
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

// ── 互动 / 安全设置格子 ─────────────────────────────────────
class _InteractTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;

  const _InteractTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = !enabled;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? iconColor.withOpacity(0.10)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? iconColor.withOpacity(0.4)
                : AppColors.surfaceContainerHigh,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: dimmed
                  ? Colors.grey.withOpacity(0.12)
                  : iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(icon, size: 18, color: dimmed ? Colors.grey : iconColor),
          ),
          SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: dimmed ? Colors.grey : AppColors.onSurface))),
        ]),
      ),
    );
  }
}

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

  bool _isRobot(DeviceModel d) {
    final key = d.productKey.toLowerCase();
    final name = d.displayName.toLowerCase();
    return key.contains('robot') ||
        name.contains('机器人') ||
        name.contains('robot') ||
        key.contains('bot') ||
        name.contains('bot');
  }

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
          final isRobot = _isRobot(d);
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
