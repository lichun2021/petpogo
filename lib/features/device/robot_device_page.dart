import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import '../device/data/models/device_model.dart';
import '../device/data/repository/device_repository.dart';
import 'device_detail_page.dart';
import '../bind_device/select_device_page.dart';

// ── 机器人设备详情页 ─────────────────────────────────────
class RobotDevicePage extends ConsumerStatefulWidget {
  final String mac;
  final String name;

  const RobotDevicePage({super.key, required this.mac, required this.name});

  @override
  ConsumerState<RobotDevicePage> createState() => _RobotDevicePageState();
}

class _RobotDevicePageState extends ConsumerState<RobotDevicePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0;

  double _moveSpeed = 50; // 10~100
  bool _cameraOn = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── 电机控制（PeerApiSpeed 接口）──────────────────────
  void _sendMotorControl(int m0Dir, int m0Speed, int m1Dir, int m1Speed) {
    final base = _moveSpeed.toInt();
    final scaledM0 = (m0Speed * base ~/ 100).clamp(0, 100);
    final scaledM1 = (m1Speed * base ~/ 100).clamp(0, 100);

    // 可读日志
    final m0DirStr = m0Dir == 1 ? '正转↑' : '反转↓';
    final m1DirStr = m1Dir == 1 ? '正转↑' : '反转↓';
    debugPrint('[遥控] 左轮(motor_0): $m0DirStr speed=$scaledM0 | '
        '右轮(motor_1): $m1DirStr speed=$scaledM1 | base=$base%');

    ref.read(deviceRepositoryProvider).motorControl(
      mac: widget.mac,
      motor0Direction: m0Dir,
      motor0Speed: scaledM0,
      motor1Direction: m1Dir,
      motor1Speed: scaledM1,
    );
  }

  // ── 设备切换 ──────────────────────────────────────────
  void _showDeviceSwitcher(BuildContext context) {
    final devices = ref.read(deviceListProvider).devices;
    if (devices.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
    final key  = d.productKey.toLowerCase();
    final name = d.displayName.toLowerCase();
    return key.contains('robot') || name.contains('机器人') ||
        name.contains('robot') || key.contains('bot') || name.contains('bot');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(children: [
        _buildTopBar(context),
        _buildCameraView(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildRemoteControl(),
              _buildPetPlay(),
              _buildPhotography(),
              _buildIntercom(),
            ],
          ),
        ),
      ]),
    );
  }

  // ── 顶部栏（红橙渐变，与 device_detail 风格一致）────────
  Widget _buildTopBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            // 返回
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  size: 20, color: AppColors.onPrimary),
            ),
            const SizedBox(width: 8),
            // 设备名 + 下拉
            GestureDetector(
              onTap: () => _showDeviceSwitcher(context),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.name,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onPrimary,
                      letterSpacing: -0.3,
                    )),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.onPrimary, size: 22),
              ]),
            ),
            const Spacer(),
            // + 添加设备
            _TopBarIcon(
              icon: Icons.add_circle_outline_rounded,
              badge: 0,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SelectDevicePage())),
            ),
            const SizedBox(width: 8),
            // 消息
            _TopBarIcon(
              icon: Icons.notifications_outlined,
              badge: 0,
              onTap: () => PetToast.warning(context, '消息功能即将上线'),
            ),
          ]),
        ),
      ),
    );
  }

  // ── 摄像头区域 ────────────────────────────────────────
  Widget _buildCameraView() {
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryContainer, AppColors.surfaceContainerLow],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.onPrimaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(fit: StackFit.expand, children: [
            // 摄像头占位
            Container(
              color: AppColors.inverseSurface,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_rounded,
                      size: 48,
                      color: AppColors.onPrimary.withOpacity(0.35)),
                  const SizedBox(height: 8),
                  Text('摄像头预览',
                      style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          color: AppColors.onPrimary.withOpacity(0.45))),
                ],
              ),
            ),
            // 速率标签
            Positioned(
              top: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('0.0\nKB/s',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 9, color: Colors.white, height: 1.3)),
              ),
            ),
            // 摄像头开关
            Positioned(
              bottom: 10, left: 10,
              child: GestureDetector(
                onTap: () => setState(() => _cameraOn = !_cameraOn),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 44, height: 24,
                  decoration: BoxDecoration(
                    color: _cameraOn ? AppColors.primary : Colors.white30,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      left: _cameraOn ? 22 : 2, top: 2,
                      child: Container(
                        width: 20, height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── 功能标签栏 ────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      (Icons.sports_esports_rounded, '遥控'),
      (Icons.favorite_rounded, '逗宠'),
      (Icons.camera_alt_rounded, '摄影'),
      (Icons.mic_rounded, '对讲'),
    ];

    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (i) {
          final active = _activeTab == i;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _tabController.animateTo(i);
              setState(() => _activeTab = i);
            },
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                  boxShadow: active
                      ? [BoxShadow(
                          color: AppColors.primaryGlow,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )]
                      : [],
                ),
                child: Icon(tabs[i].$1,
                    size: 26,
                    color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(tabs[i].$2,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.primary : AppColors.onSurfaceVariant,
                  )),
            ]),
          );
        }),
      ),
    );
  }

  // ── 遥控标签：可滑动摇杆 ──────────────────────────────
  Widget _buildRemoteControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(children: [

        // 摇杆卡片
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 16, offset: const Offset(0, 4),
              )],
            ),
            child: Column(children: [
              // 标题行
              Row(children: [
                const Text('摇杆控制',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
                const SizedBox(width: 6),
                Text('速度 ${_moveSpeed.toInt()}%',
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
                const Spacer(),
                // ⚙️ 速度设置
                GestureDetector(
                  onTap: () => _showSpeedSheet(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded,
                        size: 18, color: AppColors.primary),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              const Text('拖动方向盘控制机器人移动，松手自动停止',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: _JoystickPad(
                    onControl: _sendMotorControl,
                    padRadius: 115,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // 速度设置弹窗
  void _showSpeedSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) => Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                )),
            const SizedBox(height: 20),
            Row(children: [
              const Icon(Icons.speed_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              const Text('移动速度',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: AppColors.onSurface)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_moveSpeed.toInt()}%',
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ),
            ]),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(ctx2).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.surfaceContainerHigh,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primaryGlow,
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
              ),
              child: Slider(
                value: _moveSpeed, min: 10, max: 100,
                divisions: 9,
                onChanged: (v) {
                  setLocal(() {});
                  setState(() => _moveSpeed = v);
                },
              ),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('慢速 10%', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12, color: AppColors.onSurfaceVariant)),
                Text('快速 100%', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── 逗宠标签 ──────────────────────────────────────────
  Widget _buildPetPlay() {
    final actions = [
      ('前进', AppColors.secondary,     AppColors.secondaryFixed,  Icons.arrow_upward_rounded),
      ('圆环', AppColors.tertiary,      AppColors.tertiaryFixed,   Icons.loop_rounded),
      ('摇摆', AppColors.primary,       AppColors.primaryContainer,Icons.waves_rounded),
      ('后退', AppColors.primaryDim,    AppColors.primaryContainer,Icons.arrow_downward_rounded),
      ('左转', AppColors.secondaryDim,  AppColors.secondaryFixed,  Icons.turn_left_rounded),
      ('右转', AppColors.secondary,     AppColors.secondaryFixed,  Icons.turn_right_rounded),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('机器人动作',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 16, fontWeight: FontWeight.w800,
                color: AppColors.onSurface)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16)],
          ),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            children: actions.map((a) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  PetToast.warning(context, '执行动作：${a.$1}');
                },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [a.$2, a.$3],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                        color: a.$2.withOpacity(0.35),
                        blurRadius: 10, offset: const Offset(0, 4),
                      )],
                    ),
                    child: Icon(a.$4, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(a.$1,
                      style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.onSurface)),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ── 摄影标签 ──────────────────────────────────────────
  Widget _buildPhotography() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _PhotoAction(
            icon: Icons.photo_camera_rounded,
            label: '拍照',
            color: AppColors.primary,
            onTap: () {
              HapticFeedback.mediumImpact();
              PetToast.warning(context, '拍照功能即将上线');
            },
          )),
          const SizedBox(width: 16),
          Expanded(child: _PhotoAction(
            icon: Icons.videocam_rounded,
            label: '录像',
            color: AppColors.primaryDim,
            onTap: () {
              HapticFeedback.mediumImpact();
              PetToast.warning(context, '录像功能即将上线');
            },
          )),
        ]),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            PetToast.warning(context, '媒体文件功能即将上线');
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(
                color: AppColors.primaryGlow,
                blurRadius: 12, offset: const Offset(0, 4),
              )],
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.perm_media_rounded,
                    color: AppColors.onPrimary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('媒体文件',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 15, fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary)),
                Text('查看拍照和录像',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: AppColors.onPrimary.withOpacity(0.8))),
              ])),
              const Icon(Icons.arrow_forward_rounded,
                  color: AppColors.onPrimary, size: 20),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── 对讲标签 ──────────────────────────────────────────
  Widget _buildIntercom() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: AppColors.primaryGlow,
              blurRadius: 30, spreadRadius: 0,
            )],
          ),
          child: const Icon(Icons.mic_rounded, size: 52, color: AppColors.onPrimary),
        ),
        const SizedBox(height: 20),
        const Text('按住说话',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
        const SizedBox(height: 8),
        const Text('松开停止',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 14, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 32),
        GestureDetector(
          onTapDown: (_) {
            HapticFeedback.heavyImpact();
            PetToast.warning(context, '对讲中...');
          },
          onTapUp: (_) => PetToast.warning(context, '对讲结束'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(
                color: AppColors.primaryGlow,
                blurRadius: 16, offset: const Offset(0, 6),
              )],
            ),
            child: const Text('按住对讲',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: AppColors.onPrimary)),
          ),
        ),
      ]),
    );
  }
}

// ── 设备切换底部弹窗 ──────────────────────────────────────
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
    final key  = d.productKey.toLowerCase();
    final name = d.displayName.toLowerCase();
    return key.contains('robot') || name.contains('机器人') ||
        name.contains('robot') || key.contains('bot') || name.contains('bot');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('切换设备',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.onSurface)),
        ),
        const SizedBox(height: 16),
        ...devices.map((d) {
          final isSelected = d.mac == currentMac;
          final isRobot    = _isRobot(d);
          return GestureDetector(
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.08)
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.4)
                      : AppColors.surfaceContainerHigh,
                  width: 1.5,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isRobot
                          ? [AppColors.secondary, AppColors.secondaryDim]
                          : [AppColors.primary, AppColors.primaryDim],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isRobot ? Icons.smart_toy_rounded : Icons.pets_rounded,
                    color: AppColors.onPrimary, size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.displayName,
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.primary : AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(isRobot ? '智能宠物机器人' : '智能项圈',
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                            fontSize: 11, color: AppColors.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: d.isOnline ? AppColors.success : AppColors.onSurfaceVariant,
                          shape: BoxShape.circle,
                        )),
                    const SizedBox(width: 4),
                    Text(d.isOnline ? '在线' : '离线',
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                            fontSize: 11,
                            color: d.isOnline ? AppColors.secondary : AppColors.onSurfaceVariant)),
                  ]),
                ])),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 20),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ── 顶部图标按钮（带徽章）────────────────────────────────
class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;

  const _TopBarIcon({required this.icon, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.onPrimary, size: 20),
        ),
        if (badge > 0)
          Positioned(
            top: -2, right: -2,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(
                color: AppColors.error, shape: BoxShape.circle,
              ),
              child: Center(child: Text(badge.toString(),
                  style: const TextStyle(fontSize: 9, color: Colors.white,
                      fontWeight: FontWeight.w800))),
            ),
          ),
      ]),
    );
  }
}

// ── 可滑动摇杆控制盘 ─────────────────────────────────────
class _JoystickPad extends StatefulWidget {
  final void Function(int m0Dir, int m0Speed, int m1Dir, int m1Speed) onControl;
  final double padRadius;

  const _JoystickPad({required this.onControl, this.padRadius = 110});

  @override
  State<_JoystickPad> createState() => _JoystickPadState();
}

class _JoystickPadState extends State<_JoystickPad> {
  Offset _knob = Offset.zero;
  bool _active = false;
  Timer? _throttle;

  static const double _thumbR = 28.0;

  double get _maxDist => widget.padRadius - _thumbR;

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }

  void _stop() {
    _throttle?.cancel();
    setState(() { _knob = Offset.zero; _active = false; });
    widget.onControl(0, 0, 0, 0);
  }

  void _triggerControl() {
    if (_throttle?.isActive == true) return;
    _throttle = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted || !_active) return;
      _computeAndSend(_knob);
    });
  }

  void _computeAndSend(Offset knob) {
    final dx =  knob.dx / _maxDist;
    final dy = -knob.dy / _maxDist;
    final left  = (dy + dx).clamp(-1.0, 1.0);
    final right = (dy - dx).clamp(-1.0, 1.0);
    widget.onControl(
      left  >= 0 ? 1 : 0, (left.abs()  * 100).round().clamp(0, 100),
      right >= 0 ? 1 : 0, (right.abs() * 100).round().clamp(0, 100),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.padRadius;
    final diameter = r * 2;

    return Listener(
      onPointerDown: (_) {},
      onPointerMove: (e) {
        final center = Offset(widget.padRadius, widget.padRadius);
        var delta = e.localPosition - center;
        final dist = delta.distance;
        if (dist > _maxDist) delta = delta / dist * _maxDist;
        setState(() { _knob = delta; _active = true; });
        _triggerControl();
      },
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: SizedBox(
        width: diameter, height: diameter,
        child: Stack(alignment: Alignment.center, children: [
          // 外圆背景
          Container(
            width: diameter, height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerLow,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2), width: 2,
              ),
              boxShadow: [BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12, offset: const Offset(0, 4),
              )],
            ),
          ),
          // 十字引导线
          CustomPaint(size: Size(diameter, diameter), painter: _CrosshairPainter()),
          // 方向图标
          Positioned(top: 10, child: Icon(Icons.keyboard_arrow_up_rounded,
              size: 22, color: AppColors.primary.withOpacity(0.35))),
          Positioned(bottom: 10, child: Icon(Icons.keyboard_arrow_down_rounded,
              size: 22, color: AppColors.primary.withOpacity(0.35))),
          Positioned(left: 10, child: Icon(Icons.keyboard_arrow_left_rounded,
              size: 22, color: AppColors.primary.withOpacity(0.35))),
          Positioned(right: 10, child: Icon(Icons.keyboard_arrow_right_rounded,
              size: 22, color: AppColors.primary.withOpacity(0.35))),
          // 摇杆头
          Transform.translate(
            offset: _knob,
            child: AnimatedContainer(
              duration: _active ? Duration.zero : const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: _thumbR * 2, height: _thumbR * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _active
                      ? [AppColors.primaryDim, AppColors.primary]
                      : [AppColors.primary, AppColors.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(
                  color: AppColors.primary.withOpacity(_active ? 0.6 : 0.35),
                  blurRadius: _active ? 18 : 10,
                  offset: const Offset(0, 4),
                )],
              ),
              child: Icon(Icons.gamepad_rounded,
                  color: AppColors.onPrimary, size: _active ? 26 : 22),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 摇杆十字参考线 ────────────────────────────────────────
class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.outlineVariant
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), paint);
  }

  @override
  bool shouldRepaint(_CrosshairPainter _) => false;
}

// ── 快捷操作按钮 ──────────────────────────────────────────
class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.25), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ── 摄影功能卡片 ──────────────────────────────────────────
class _PhotoAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PhotoAction({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.cardShadow,
              blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}
