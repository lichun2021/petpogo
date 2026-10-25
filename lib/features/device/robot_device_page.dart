import 'package:petpogo_app/core/logging/app_log.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../shell/main_shell.dart' show hideBottomNavProvider;
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import '../../shared/utils/oss_uploader.dart';
import '../device/data/models/device_model.dart';
import '../device/data/repository/device_repository.dart';
import '../device/data/models/media_model.dart';
import '../device/data/repository/media_repository.dart';
import '../device/media_gallery_page.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import 'device_detail_page.dart';
import '../../core/providers/account_session_provider.dart';
import 'stream/device_stream_session.dart';
import 'stream/http_motor_controller.dart';
import 'stream/jpeg_stream_view.dart';
import '../bind_device/device_wifi_setup_entry.dart';

import 'package:petpogo_app/shared/theme/app_fonts.dart';
import 'robot_ai_home_page.dart';
import '../../shared/utils/error_presenter.dart';

// ── 机器人设备详情页 ─────────────────────────────────────
class RobotDevicePage extends ConsumerStatefulWidget {
  final String mac;
  final String name;

  const RobotDevicePage({super.key, required this.mac, required this.name});

  @override
  ConsumerState<RobotDevicePage> createState() => _RobotDevicePageState();
}

class _RobotDevicePageState extends ConsumerState<RobotDevicePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  int _activeTab = 0;

  double _moveSpeed = 50; // 10~100
  double _deviceVolume = 100; // 设备音量 0~100

  late final DeviceStreamSession _stream;
  late final HttpMotorController _motors;
  late final ProviderSubscription<int> _accountSubscription;
  bool _sessionRevoked = false;
  bool _backgroundPaused = false;
  bool _fullscreenOpen = false;
  bool _startingRecording = false;
  bool get _streamConnected => _stream.connected;
  bool get _streamLoading => _stream.loading;
  bool get _micOn => _stream.talking;
  String? get _streamError => _stream.error ?? _stream.audioError;
  double get _kbps => _stream.kbps;
  bool get _videoFrozen => _stream.frozen;
  String get _connStatusText => _stream.status;

  bool _takingPhoto = false;
  bool _recording = false;
  bool _savingRecording = false;
  bool _uploadingMedia = false;
  int _recordSeconds = 0;
  static const _maxRecordSec = 30;
  Timer? _recordTimer;
  Timer? _batteryRefreshTimer;
  List<MediaItem> _recentMedia = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stream = ref.read(deviceStreamFactoryProvider)(widget.mac);
    _stream.addListener(_onStreamChanged);
    _batteryRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          !_sessionRevoked &&
          !_backgroundPaused &&
          (_fullscreenOpen || ModalRoute.of(context)?.isCurrent == true)) {
        ref.invalidate(deviceBatteryProvider(widget.mac));
      }
    });
    final deviceRepo = ref.read(deviceRepositoryProvider);
    _motors = HttpMotorController((ld, ls, rd, rs) async {
      if (_sessionRevoked) return;
      await deviceRepo.motorControl(
          mac: widget.mac,
          motor0Direction: ld,
          motor0Speed: ls,
          motor1Direction: rd,
          motor1Speed: rs);
    }, onError: (_) {
      if (mounted) PetToast.warning(context, '遥控指令发送失败，请检查网络');
    });
    _accountSubscription = ref.listenManual(accountSessionProvider, (_, __) {
      _sessionRevoked = true;
      unawaited(_pauseStream());
    });
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging)
        setState(() => _activeTab = _tabController.index);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startStream();
      _loadRecentMedia();
    });
  }

  void _onStreamChanged() {
    if (!mounted) return;
    setState(() {});
    if (_recording && !_stream.connected) unawaited(_stopRecording());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _stream.diagnostics.log('page.lifecycle', '页面生命周期', '系统生命周期状态改变', fields: {
      'reason': state.name,
      'view': _fullscreenOpen ? 'fullscreen' : 'inline',
    });
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgroundPaused = true;
      unawaited(_pauseStream());
    } else if (state == AppLifecycleState.resumed && _backgroundPaused) {
      _backgroundPaused = false;
      if (_fullscreenOpen || ModalRoute.of(context)?.isCurrent == true)
        unawaited(_startStream());
    }
  }

  Future<void> _startStream() async {
    if (!_sessionRevoked && mounted) await _stream.start();
  }

  Future<void> _pauseStream() async {
    if (_recording) unawaited(_stopRecording());
    await Future.wait([_motors.stop(), _stream.stop()]);
  }

  Future<void> _resumeStream() => _startStream();
  Future<void> _toggleMic() => _stream.toggleTalk();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accountSubscription.close();
    _stream.removeListener(_onStreamChanged);
    _recordTimer?.cancel();
    _batteryRefreshTimer?.cancel();
    _tabController.dispose();
    unawaited(_motors.close());
    unawaited(_stream.release().catchError((_) {}));
    super.dispose();
  }

  // ── 摄影：截图 ─────────────────────────────────────────

  Future<Uint8List?> _captureFrame() async => _stream.latestJpeg.value;

  /// 拍照：截帧 → 保存相册 → 上传 OSS → 入库
  Future<void> _takePhoto() async {
    if (_takingPhoto || !_streamConnected) return;
    setState(() => _takingPhoto = true);
    try {
      // 1. 请求相册权限
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      // 2. 截帧
      final bytes = await _captureFrame();
      if (bytes == null) {
        if (mounted) PetToast.warning(context, '截图失败，请重试');
        return;
      }
      // 3. 写临时文件
      final tmp = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${tmp.path}/photo_$ts.jpg';
      await File(path).writeAsBytes(bytes);
      // 4. 保存到系统相册
      await Gal.putImage(path);
      if (mounted) PetToast.success(context, '📸 已保存到相册');
      // 5. 后台上传 OSS（不阻塞 UI）
      _uploadMedia(localPath: path, bytes: bytes, type: 1, duration: null);
    } catch (e) {
      AppLog.debug('[摄影] 拍照失败: $e');
      if (mounted) PetToast.error(context, '拍照失败');
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  // ── 摄影：手机本地录像 ─────────────────────────────────
  Future<void> _startRecording() async {
    final frame = _stream.latestJpeg.value;
    if (_recording ||
        _startingRecording ||
        _savingRecording ||
        frame == null ||
        !_stream.connected) return;
    setState(() => _startingRecording = true);
    try {
      if (!await Gal.hasAccess(toAlbum: true))
        await Gal.requestAccess(toAlbum: true);
      if (!mounted || !_stream.connected) return;
      await _stream.recorder.start(frame);
      if (!mounted) {
        await _stream.recorder.cancel();
        return;
      }
      setState(() {
        _recording = true;
        _recordSeconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _recordSeconds++);
        if (_recordSeconds >= _maxRecordSec) {
          timer.cancel();
          unawaited(_stopRecording());
        }
      });
    } catch (error) {
      if (mounted)
        PetToast.error(
            context, ErrorPresenter.message(error, fallback: '录像启动失败'));
    } finally {
      if (mounted) setState(() => _startingRecording = false);
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording || _savingRecording) return;
    _recordTimer?.cancel();
    final seconds = _recordSeconds;
    setState(() {
      _recording = false;
      _savingRecording = true;
    });
    try {
      final path = await _stream.recorder.finish();
      await Gal.putVideo(path, album: '宠联芯');
      if (mounted) {
        PetToast.success(context, '录像已保存到相册');
        unawaited(_uploadMedia(localPath: path, type: 2, duration: seconds));
      }
    } catch (error) {
      if (mounted)
        PetToast.error(
            context, ErrorPresenter.message(error, fallback: '录像保存失败，已保留本地素材'));
    } finally {
      if (mounted)
        setState(() {
          _savingRecording = false;
          _recordSeconds = 0;
        });
    }
  }

  // ── OSS 上传 + 入库 ────────────────────────────────────

  Future<void> _uploadMedia({
    required String localPath,
    List<int>? bytes,
    required int type, // 1图片 2视频
    required int? duration,
  }) async {
    if (!mounted || _uploadingMedia) return; // 防并发
    final accountEpoch = ref.read(accountSessionProvider);
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final uploader = ref.read(ossUploaderProvider);
    setState(() => _uploadingMedia = true);
    try {
      final sign = await uploader.getSign(
        folder: 'devices-media',
        mimeType: type == 1 ? 'image/jpeg' : 'video/mp4',
      );
      if (!mounted || ref.read(accountSessionProvider) != accountEpoch) return;
      final file = File(localPath);
      await uploader.uploadFile(uploadUrl: sign.uploadUrl, file: file);
      final fileSize = await file.length();
      if (!mounted || ref.read(accountSessionProvider) != accountEpoch) return;
      // 通知后端入库
      await mediaRepo.saveRecord(
        type: type,
        url: sign.cdnUrl,
        ossKey: sign.key,
        fileSize: fileSize,
        duration: duration,
        deviceId: widget.mac, // 设备 MAC 地址
      );
      // 刷新预览
      if (mounted) _loadRecentMedia();
      if (mounted) PetToast.success(context, '☁️ 上传成功');
    } catch (e) {
      AppLog.debug('[OSS] 上传失败: $e');
      if (mounted) PetToast.error(context, '上传失败，文件已保存本地相册');
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  /// 加载最近 6 条媒体（摄影标签预览）
  Future<void> _loadRecentMedia() async {
    try {
      final result = await ref.read(mediaRepositoryProvider).fetchList(
            deviceId: widget.mac,
            page: 1,
            pageSize: 6,
          );
      if (mounted) setState(() => _recentMedia = result.list);
    } catch (_) {}
  }

  // ── 电机控制：所有场景统一使用原 HTTP 设备影子接口 ────────
  void _sendMotorControl(
      int leftDirection, int leftSpeed, int rightDirection, int rightSpeed) {
    final base = _moveSpeed.toInt();
    _motors.update(leftDirection, (leftSpeed * base ~/ 100).clamp(0, 100),
        rightDirection, (rightSpeed * base ~/ 100).clamp(0, 100));
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

  @override
  Widget build(BuildContext context) {
    // 横屏时（进入全屏）返回纯黑，防止底层页面跟着旋转报 OVERFLOW
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.landscape) {
      return Scaffold(backgroundColor: Colors.black);
    }
    final screenH = MediaQuery.of(context).size.height;
    return PopScope(
        canPop: !_recording && !_savingRecording,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || _savingRecording) return;
          await _stopRecording();
          if (context.mounted) Navigator.pop(context);
        },
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: Column(children: [
            _buildTopBar(context),
            _buildCameraView(screenH),
            _buildTabBar(screenH),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildRemoteControl(),
                  _buildPetPlay(),
                  _buildPhotography(),
                  _buildIntercom(),
                ],
              ),
            ),
          ]),
        ));
  }

  // ── 顶部栏（红橙渐变，与 device_detail 风格一致）────────
  Widget _buildTopBar(BuildContext context) {
    final battery = ref.watch(deviceBatteryProvider(widget.mac)).valueOrNull;
    return Container(
      decoration: BoxDecoration(
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
              child: Icon(Icons.arrow_back_ios_rounded,
                  size: 20, color: AppColors.onPrimary),
            ),
            SizedBox(width: 8),
            // 设备名 + 下拉（Expanded 确保小屏幕全部显示）
            Expanded(
              child: GestureDetector(
                onTap: () => _showDeviceSwitcher(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: Text(
                          widget.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.onPrimary, size: 22),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.battery_std_rounded,
                          size: 12, color: AppColors.onPrimary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          battery?.known == true
                              ? '电量 ${battery!.battery}%'
                              : '电量 -',
                          style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 11,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            if (ref.watch(deviceListProvider).devices.any((device) =>
                device.mac.toUpperCase() == widget.mac.toUpperCase() &&
                device.isOwner &&
                !device.isShared))
              IconButton(
                  icon: Icon(Icons.wifi_rounded, color: AppColors.onPrimary),
                  tooltip: '更换 WiFi / 重新配网',
                  onPressed: () async {
                    final device = ref
                        .read(deviceListProvider)
                        .devices
                        .firstWhere((device) =>
                            device.mac.toUpperCase() ==
                            widget.mac.toUpperCase());
                    await _pauseStream();
                    if (!mounted) return;
                    await openRobotWifiSetup(context,
                        productKey: device.productKey,
                        existingMac: widget.mac,
                        deviceName: widget.name);
                    if (mounted) {
                      _resumeStream();
                      ref.read(deviceListProvider.notifier).load();
                    }
                  }),
            // AI 荧光按钮
            _AiGlowButton(
              onTap: () async {
                // 进入 AI 页前先暂停推流
                await _pauseStream();
                if (!mounted) return;
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RobotAiHomePage(
                        mac: widget.mac,
                        deviceName: widget.name,
                      ),
                    ));
                // 返回后重新连接
                if (mounted) _resumeStream();
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ── 摄像头区域（WebSocket JPEG）────────────────────────────
  Widget _buildCameraView(double screenH) {
    final cameraH = (screenH * 0.27).clamp(160.0, 220.0);
    return Container(
      height: cameraH,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryContainer, AppColors.surfaceContainerLow],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.inverseSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(fit: StackFit.expand, children: [
            // ── JPEG 画面：Android 和 iOS 共用同一渲染路径 ──
            if (_stream.hasVideo)
              JpegStreamView(
                  frames: _stream.latestJpeg,
                  diagnostics: _stream.diagnostics,
                  view: 'inline')
            else
              Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_streamLoading || _streamConnected)
                  const CircularProgressIndicator(strokeWidth: 2)
                else
                  const Icon(Icons.videocam_off_rounded,
                      size: 40, color: Colors.white54),
                const SizedBox(height: 12),
                Text(_streamError ?? _connStatusText,
                    style: const TextStyle(color: Colors.white70)),
                if (!_streamLoading && !_streamConnected)
                  TextButton(
                      onPressed: _startStream, child: const Text('点击重试')),
                if (_stream.waitingTooLong)
                  TextButton(
                      onPressed: () async {
                        await _pauseStream();
                        await _resumeStream();
                      },
                      child: const Text('重新连接')),
              ])),

            // 视频冻结提示层（网络拥塑时）
            if (_videoFrozen && _stream.hasVideo)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: Colors.white70)),
                        SizedBox(width: 8),
                        Text('网络恢复中...',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),

            // 速率标签
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_kbps.toStringAsFixed(0)}\nKB/s',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 9,
                      color: Colors.white,
                      height: 1.3),
                ),
              ),
            ),

            // 连接状态标签（右上）
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _stream.hasVideo
                      ? Colors.green.withOpacity(0.8)
                      : Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _stream.hasVideo
                          ? Colors.greenAccent
                          : Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    _connStatusText,
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 9,
                        color: Colors.white),
                  ),
                ]),
              ),
            ),

            // 全屏按鈕（右下）
            Positioned(
              bottom: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  if (!_stream.hasVideo) return;
                  // 全屏前隐藏底部导航栏
                  ref.read(hideBottomNavProvider.notifier).state = true;
                  _fullscreenOpen = true;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _FullscreenVideoPage(
                        session: _stream,
                        onControl: _sendMotorControl,
                      ),
                    ),
                  ).then((_) {
                    // 退出全屏后恢复底部导航栏
                    _fullscreenOpen = false;
                    if (mounted)
                      ref.read(hideBottomNavProvider.notifier).state = false;
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.fullscreen_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── 功能标签栏（响应式，防止小屏幕 BOTTOM OVERFLOW）──
  Widget _buildTabBar(double screenH) {
    // 小屏幕时图标缩小：screenH * 0.075 = 48(640屏) ~ 60(800屏)
    final iconSize = (screenH * 0.075).clamp(44.0, 60.0);
    final iconPad = screenH < 700 ? 8.0 : 12.0;
    final tabs = [
      (Icons.sports_esports_rounded, '遥控'),
      (Icons.favorite_rounded, '逗宠'),
      (Icons.camera_alt_rounded, '摄影'),
      (Icons.mic_rounded, '对讲'),
    ];

    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: EdgeInsets.symmetric(vertical: iconPad),
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
                duration: Duration(milliseconds: 200),
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.primaryGlow,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Icon(tabs[i].$1,
                    size: iconSize * 0.43,
                    color: active
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant),
              ),
              SizedBox(height: 4),
              Text(tabs[i].$2,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: screenH < 700 ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color:
                        active ? AppColors.primary : AppColors.onSurfaceVariant,
                  )),
            ]),
          );
        }),
      ),
    );
  }

  // ── 遥控标签：可滑动摇杆 ────────────────────────────────
  Widget _buildRemoteControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: LayoutBuilder(
        builder: (ctx, outer) {
          // 摇杆半径：基于整个卡片尺寸（非剩余空间），让摇杆真正居中
          final innerW = outer.maxWidth - 48; // 内边距 24×2
          final innerH = outer.maxHeight - 80; // 顶部行 ~46 + 底部留白 ~34
          final padR = (innerW.clamp(0, innerH) / 2).clamp(70.0, 130.0);

          return Container(
            width: outer.maxWidth,
            height: outer.maxHeight,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Stack(
              children: [
                // ① 摇杆真正居中于整个卡片
                Center(
                  child: _JoystickPad(
                    onControl: _sendMotorControl,
                    padRadius: padR,
                  ),
                ),
                // ② 顶部栏：提示文字（左）+ 设置按钮（右）
                Positioned(
                  top: 14,
                  left: 20,
                  right: 14,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showSpeedSheet(context),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.tune_rounded,
                              size: 17, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                )),
            SizedBox(height: 20),
            Row(children: [
              Icon(Icons.speed_rounded, size: 20, color: AppColors.primary),
              SizedBox(width: 10),
              Text('移动速度',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface)),
              Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_moveSpeed.toInt()}%',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ),
            ]),
            SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(ctx2).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.surfaceContainerHigh,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primaryGlow,
                trackHeight: 5,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 11),
              ),
              child: Slider(
                value: _moveSpeed,
                min: 10,
                max: 100,
                divisions: 9,
                onChanged: (v) {
                  setLocal(() {});
                  setState(() => _moveSpeed = v);
                },
              ),
            ),
            SizedBox(height: 8),

            // ── 设备音量 ────────────────────────────────
            Divider(height: 28),
            Row(children: [
              Icon(Icons.volume_up_rounded, size: 20, color: AppColors.primary),
              SizedBox(width: 10),
              Text('设备音量',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface)),
              Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_deviceVolume.toInt()}%',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ),
            ]),
            SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(ctx2).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.surfaceContainerHigh,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primaryGlow,
                trackHeight: 5,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 11),
              ),
              child: Slider(
                value: _deviceVolume,
                min: 0,
                max: 100,
                divisions: 10,
                onChanged: (v) {
                  setLocal(() {});
                  setState(() => _deviceVolume = v);
                  unawaited(_stream.setVolume(v / 100));
                },
              ),
            ),
            SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── 逗宠标签 ──────────────────────────────────────────
  Widget _buildPetPlay() {
    final actions = [
      (
        '前进',
        AppColors.secondary,
        AppColors.secondaryFixed,
        Icons.arrow_upward_rounded
      ),
      ('圆环', AppColors.tertiary, AppColors.tertiaryFixed, Icons.loop_rounded),
      (
        '摇摆',
        AppColors.primary,
        AppColors.primaryContainer,
        Icons.waves_rounded
      ),
      (
        '后退',
        AppColors.primaryDim,
        AppColors.primaryContainer,
        Icons.arrow_downward_rounded
      ),
      (
        '左转',
        AppColors.secondaryDim,
        AppColors.secondaryFixed,
        Icons.turn_left_rounded
      ),
      (
        '右转',
        AppColors.secondary,
        AppColors.secondaryFixed,
        Icons.turn_right_rounded
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // ── 精确计算 GridView 列宽 ──────────────────────────
        // SingleChildScrollView padding 20, Container padding 16 → 水平内缩 72
        // crossAxisSpacing = 12，三列两间距 = 24
        const crossSpacing = 12.0;
        final gridW = constraints.maxWidth - 72; // 可用网格总宽
        final colW = (gridW - crossSpacing * 2) / 3; // 实际每列宽
        // 按钮大小跟随列宽，上限 88（大屏更充实）
        final btnSize = colW.clamp(48.0, 88.0);
        final iconSize = btnSize * 0.44;
        // 每格内容高 = 按钮 + 文字 + 间距，childAspectRatio 基于实际列宽
        final contentH = btnSize + 6 + 18.0; // 6=SizedBox, 18=text
        final ratio = colW / contentH; // 用列宽除以内容高
        final spacing = constraints.maxHeight < 380 ? 8.0 : 12.0;

        return SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('机器人动作',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface)),
            SizedBox(height: spacing),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppColors.cardShadow, blurRadius: 16)
                ],
              ),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                mainAxisSpacing: spacing,
                crossAxisSpacing: crossSpacing,
                childAspectRatio: ratio, // ← 基于实际列宽，大屏不再出现巨大间距
                children: actions.map((a) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      PetToast.warning(context, '执行动作：${a.$1}');
                    },
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: btnSize,
                            height: btnSize,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [a.$2, a.$3],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius:
                                  BorderRadius.circular(btnSize * 0.28),
                              boxShadow: [
                                BoxShadow(
                                  color: a.$2.withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                )
                              ],
                            ),
                            child:
                                Icon(a.$4, color: Colors.white, size: iconSize),
                          ),
                          SizedBox(height: 6),
                          Text(a.$1,
                              style: TextStyle(
                                  fontFamily: AppFonts.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface)),
                        ]),
                  );
                }).toList(),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── 摄影标签 ──────────────────────────────────────────
  Widget _buildPhotography() {
    final recSec = _maxRecordSec - _recordSeconds;
    final mm = (recSec ~/ 60).toString().padLeft(2, '0');
    final ss = (recSec % 60).toString().padLeft(2, '0');

    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── 操作按钮行 ─────────────────────────────────
        Row(children: [
          Expanded(
              child: _buildCameraBtn(
            icon: _takingPhoto
                ? Icons.hourglass_top_rounded
                : Icons.photo_camera_rounded,
            label: _takingPhoto ? '处理中...' : '拍照',
            sublabel: _stream.hasVideo ? '截取当前画面' : '等待视频连接',
            color: AppColors.primary,
            enabled: _stream.hasVideo &&
                !_takingPhoto &&
                !_recording &&
                !_savingRecording,
            recording: false,
            onTap: () {
              HapticFeedback.mediumImpact();
              _takePhoto();
            },
          )),
          SizedBox(width: 12),
          Expanded(
              child: _buildCameraBtn(
            icon: _recording ? Icons.stop_rounded : Icons.videocam_rounded,
            label: _recording ? '停止 $mm:$ss' : '录像',
            sublabel: _recording ? '点击提前停止' : '最长 30 秒',
            color: _recording ? Colors.redAccent : AppColors.primaryDim,
            enabled: !_startingRecording &&
                (_recording || _stream.hasVideo) &&
                !_takingPhoto &&
                !_savingRecording,
            recording: _recording,
            onTap: () {
              HapticFeedback.mediumImpact();
              _recording ? _stopRecording() : _startRecording();
            },
          )),
        ]),

        // 上传进度
        if (_uploadingMedia)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.primary)),
              SizedBox(width: 8),
              Text('正在上传到云端...',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant)),
            ]),
          ),

        SizedBox(height: 16),

        // ── 最近媒体预览 ───────────────────────────────
        Row(children: [
          Text('最近媒体',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          Spacer(),
          if (_recentMedia.isNotEmpty)
            GestureDetector(
              onTap: () => _openGallery(),
              child: Text('查看全部 →',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 12,
                      color: AppColors.primary)),
            ),
        ]),
        SizedBox(height: 8),

        if (_recentMedia.isEmpty)
          Container(
            height: 80,
            alignment: Alignment.center,
            child: Text('还没有照片或视频，去拍一张吧 📷',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant)),
          )
        else
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recentMedia.length,
              separatorBuilder: (_, __) => SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = _recentMedia[i];
                return GestureDetector(
                  onTap: _openGallery,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(fit: StackFit.expand, children: [
                        Image.network(
                          item.thumbUrl.isNotEmpty ? item.thumbUrl : item.url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surfaceContainerLow,
                              child: Icon(Icons.broken_image_outlined,
                                  color: AppColors.onSurfaceVariant)),
                        ),
                        if (item.isVideo)
                          Center(
                              child: Icon(Icons.play_circle_rounded,
                                  color: Colors.white70, size: 28)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),

        SizedBox(height: 16),

        // ── 媒体库入口 ──────────────────────────────────
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _openGallery();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.perm_media_rounded,
                    color: AppColors.onPrimary, size: 26),
              ),
              SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('媒体库',
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onPrimary)),
                    Text('查看所有拍照和录像（支持设备共享）',
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 11,
                            color: AppColors.onPrimary.withOpacity(0.8))),
                  ])),
              Icon(Icons.arrow_forward_rounded,
                  color: AppColors.onPrimary, size: 20),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _openGallery() async {
    await _pauseStream();
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaGalleryPage(
            deviceId: widget.mac,
            deviceName: widget.name,
          ),
        ));

    // 媒体库返回后恢复观看
    if (mounted) {
      _loadRecentMedia();
      _resumeStream();
    }
  }

  // ── 摄影按钮组件 ──────────────────────────────────────
  Widget _buildCameraBtn({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required bool enabled,
    required bool recording,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: enabled
              ? (recording
                  ? Colors.redAccent.withOpacity(0.08)
                  : AppColors.surfaceContainerLowest)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: enabled
                ? (recording ? Colors.redAccent : color.withOpacity(0.3))
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 30,
              color: enabled
                  ? (recording ? Colors.redAccent : color)
                  : AppColors.onSurfaceVariant),
          SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: enabled
                      ? (recording ? Colors.redAccent : AppColors.onSurface)
                      : AppColors.onSurfaceVariant)),
          SizedBox(height: 2),
          Text(sublabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 10,
                  color: AppColors.onSurfaceVariant)),
        ]),
      ),
    );
  }

  // ── 对讲标签（PCM 麦克风采集）────────────────────────────
  Widget _buildIntercom() {
    final isReady = _streamConnected && !_stream.talkBusy;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final micSize = h < 350 ? 88.0 : 120.0;
        final gap1 = h < 350 ? 10.0 : 20.0;
        final gap2 = h < 350 ? 16.0 : 32.0;
        return SingleChildScrollView(
          physics: ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: h),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 麦克风图标（麦开时变绿）
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: micSize,
                    height: micSize,
                    decoration: BoxDecoration(
                      gradient: _micOn
                          ? LinearGradient(
                              colors: [
                                  AppColors.statusOnlineStrong,
                                  AppColors.statusOnline
                                ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight)
                          : AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _micOn
                              ? Colors.green.withOpacity(0.4)
                              : AppColors.primaryGlow,
                          blurRadius: _micOn ? 40 : 30,
                          spreadRadius: 0,
                        )
                      ],
                    ),
                    child: Icon(
                      _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                      size: micSize * 0.43,
                      color: AppColors.onPrimary,
                    ),
                  ),
                  SizedBox(height: gap1),
                  Text(
                    isReady ? (_micOn ? '对讲中...' : '连接已建立') : '连接设备中...',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface),
                  ),
                  SizedBox(height: 8),
                  Text(
                    isReady ? '点击按钮开启/关闭对讲' : '请稍候...',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant),
                  ),
                  SizedBox(height: gap2),
                  // 对讲按钮
                  GestureDetector(
                    onTap: isReady ? _toggleMic : null,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: isReady
                            ? (_micOn
                                ? LinearGradient(colors: [
                                    AppColors.statusOnlineStrong,
                                    AppColors.statusOnline
                                  ])
                                : AppColors.primaryGradient)
                            : null,
                        color: isReady ? null : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: isReady
                            ? [
                                BoxShadow(
                                  color: _micOn
                                      ? Colors.green.withOpacity(0.4)
                                      : AppColors.primaryGlow,
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        isReady ? (_micOn ? '关闭对讲' : '开启对讲') : '连接中...',
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isReady
                              ? AppColors.onPrimary
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  // 错误信息
                  if (_streamError != null) ...[
                    SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(_streamError!,
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 11,
                              color: Colors.redAccent),
                          textAlign: TextAlign.center),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(2))),
        SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('切换设备',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface)),
        ),
        SizedBox(height: 16),
        ...devices.map((d) {
          final isSelected = d.mac == currentMac;
          final isRobot = d.isRobot;
          return GestureDetector(
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 180),
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
                  width: 44,
                  height: 44,
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
                    color: AppColors.onPrimary,
                    size: 22,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(d.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.onSurface)),
                      SizedBox(height: 2),
                      Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
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
                                      ? AppColors.success
                                      : AppColors.onSurfaceVariant,
                                  shape: BoxShape.circle,
                                )),
                            SizedBox(width: 4),
                            Text(d.isOnline ? '在线' : '离线',
                                style: TextStyle(
                                    fontFamily: AppFonts.primary,
                                    fontSize: 11,
                                    color: d.isOnline
                                        ? AppColors.secondary
                                        : AppColors.onSurfaceVariant)),
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

// ── 顶部图标按钮（带徽章）────────────────────────────────

// ── 可滑动摇杆控制盘 ─────────────────────────────────────
class _JoystickPad extends StatefulWidget {
  final void Function(int m0Dir, int m0Speed, int m1Dir, int m1Speed) onControl;
  final double padRadius;
  final bool transparent; // 全屏透明模式

  const _JoystickPad({
    required this.onControl,
    this.padRadius = 110,
    this.transparent = false,
  });

  @override
  State<_JoystickPad> createState() => _JoystickPadState();
}

class _JoystickPadState extends State<_JoystickPad> {
  Offset _knob = Offset.zero;
  bool _active = false;
  Timer? _periodicTimer;

  static const double _thumbR = 28.0;
  // 发送间隔（按住期间每隔此时间发一次指令）
  static const Duration _sendInterval = Duration(milliseconds: 300);

  double get _maxDist => widget.padRadius - _thumbR;

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_periodicTimer?.isActive == true) return;
    // 立即发送第一帧
    _computeAndSend(_knob);
    // 之后每隔 _sendInterval 发一次
    _periodicTimer = Timer.periodic(_sendInterval, (_) {
      if (!mounted || !_active) {
        _periodicTimer?.cancel();
        return;
      }
      _computeAndSend(_knob);
    });
  }

  void _stop() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    setState(() {
      _knob = Offset.zero;
      _active = false;
    });
    widget.onControl(0, 0, 0, 0);
  }

  void _computeAndSend(Offset knob) {
    final dx = knob.dx / _maxDist;
    final dy = -knob.dy / _maxDist;
    final left = (dy + dx).clamp(-1.0, 1.0);
    final right = (dy - dx).clamp(-1.0, 1.0);
    widget.onControl(
      left >= 0 ? 1 : 2,
      (left.abs() * 100).round().clamp(0, 100),
      right >= 0 ? 1 : 2,
      (right.abs() * 100).round().clamp(0, 100),
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
        setState(() {
          _knob = delta;
          _active = true;
        });
        _startTimer(); // 只在 Timer 未启动时才启动，不受 move 事件频率影响
      },
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(alignment: Alignment.center, children: [
          // 外圆背景
          if (widget.transparent)
            ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // 深色半透明，白/黑背景都清晰
                    color: Colors.black.withOpacity(0.40),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.55),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 20,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceContainerLow,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: widget.transparent
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        )
                      ],
              ),
            ),
          // 方向图标
          Positioned(
              top: 10,
              child: Icon(Icons.keyboard_arrow_up_rounded,
                  size: 22,
                  color: widget.transparent
                      ? Colors.white
                      : AppColors.primary.withOpacity(0.35))),
          Positioned(
              bottom: 10,
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: widget.transparent
                      ? Colors.white
                      : AppColors.primary.withOpacity(0.35))),
          Positioned(
              left: 10,
              child: Icon(Icons.keyboard_arrow_left_rounded,
                  size: 22,
                  color: widget.transparent
                      ? Colors.white
                      : AppColors.primary.withOpacity(0.35))),
          Positioned(
              right: 10,
              child: Icon(Icons.keyboard_arrow_right_rounded,
                  size: 22,
                  color: widget.transparent
                      ? Colors.white
                      : AppColors.primary.withOpacity(0.35))),
          // 摇杆头（透明模式用玻璃质感）
          Transform.translate(
            offset: _knob,
            child: widget.transparent
                ? ClipOval(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: AnimatedContainer(
                        duration: _active
                            ? Duration.zero
                            : Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        width: _thumbR * 2,
                        height: _thumbR * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // 深色半透明，白色背景下也清晰
                          color: _active
                              ? Colors.white.withOpacity(0.30)
                              : Colors.black.withOpacity(0.55),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.80),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(_active ? 0.5 : 0.3),
                              blurRadius: _active ? 22 : 10,
                            ),
                          ],
                        ),
                        child: Icon(Icons.pets_rounded,
                            color: Colors.white, size: _active ? 24 : 20),
                      ),
                    ),
                  )
                : AnimatedContainer(
                    duration:
                        _active ? Duration.zero : Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: _thumbR * 2,
                    height: _thumbR * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _active
                            ? [AppColors.primaryDim, AppColors.primary]
                            : [AppColors.primary, AppColors.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary
                              .withOpacity(_active ? 0.6 : 0.35),
                          blurRadius: _active ? 18 : 10,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: Icon(Icons.pets_rounded,
                        color: AppColors.onPrimary, size: _active ? 24 : 20),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ── 全屏视频页（横屏全屏 + 透明质感覆盖层）────────────────

class _FullscreenVideoPage extends StatefulWidget {
  final DeviceStreamSession session;
  final void Function(int, int, int, int) onControl;

  const _FullscreenVideoPage({
    required this.session,
    required this.onControl,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _interactOpen = false;
  bool _micOn = false;
  bool _speakerOn = true;

  static const _interactItems = [
    (Icons.music_note_rounded, '安抚'),
    (Icons.sports_tennis_rounded, '玩耗'),
    (Icons.stars_rounded, '逢趣'),
    (Icons.restaurant_rounded, '喜食'),
  ];

  @override
  void initState() {
    super.initState();
    _micOn = widget.session.talking;
    widget.session.addListener(_updateSession);
    // 全屏时横屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _updateSession() {
    if (mounted) setState(() => _micOn = widget.session.talking);
  }

  @override
  void dispose() {
    widget.session.removeListener(_updateSession);
    // 退出全屏时恢复竖屏
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _toggleMic() async {
    await widget.session.toggleTalk();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 视频 ───────────────────────────────────────
          if (widget.session.hasVideo)
            JpegStreamView(
                frames: widget.session.latestJpeg,
                diagnostics: widget.session.diagnostics,
                view: 'fullscreen')
          else
            const Center(
                child: Icon(Icons.videocam_off_rounded,
                    size: 64, color: Colors.white24)),

          // ── 右上：麦克风 + 扬声器 + 退出全屏（横排，同等大小）──────
          Positioned(
            top: safe.top + 12,
            right: safe.right + 16,
            child: Row(
              children: [
                _GlassBtn(
                  icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                  active: _micOn,
                  onTap: _toggleMic,
                ),
                SizedBox(width: 10),
                _GlassBtn(
                  icon: _speakerOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  active: _speakerOn,
                  onTap: () async {
                    setState(() => _speakerOn = !_speakerOn);
                    await widget.session.setVolume(_speakerOn ? 1 : 0);
                  },
                ),
                SizedBox(width: 10),
                _GlassBtn(
                  icon: Icons.fullscreen_exit_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ── 右下：互动按钮（单独保留，大按钮）──────────────────────
          Positioned(
            bottom: safe.bottom + 32,
            right: 20,
            child: _GlassBtn(
              icon: Icons.emoji_emotions_rounded,
              active: _interactOpen,
              size: 72,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _interactOpen = !_interactOpen);
              },
            ),
          ),

          // ── 左下：透明摇杆 ──────────────────────────────────────
          Positioned(
            bottom: safe.bottom + 70,
            left: safe.left + 16,
            child: _JoystickPad(
              onControl: widget.onControl,
              padRadius: 80,
              transparent: true,
            ),
          ),

          // ── 互动展开面板（从屏幕顶部中间向下弹出）───────────────────
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: _interactOpen ? safe.top + 60.0 : -140.0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 220),
              opacity: _interactOpen ? 1.0 : 0.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _interactItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GlassBtn(
                          icon: item.$1,
                          size: 56,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            // TODO: 接入互动 API
                          },
                        ),
                        SizedBox(height: 6),
                        Text(item.$2,
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 透明质感按鈕 ─────────────────────────────────────────
class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final double size;

  const _GlassBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 深色半透明底色，白/黑背景都清晰可见
              color: active
                  ? Colors.white.withOpacity(0.30)
                  : Colors.black.withOpacity(0.45),
              border: Border.all(
                color: Colors.white.withOpacity(active ? 0.80 : 0.50),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon,
                size: size * 0.45, color: active ? Colors.white : Colors.white),
          ),
        ),
      ),
    );
  }
}

// ── 快捷操作按钮 ──────────────────────────────────────────

// ── 摄影功能卡片 ──────────────────────────────────────────

// ── AI 按钮（电流扫光 + 主题渐变，无缩放）─────────────────────
class _AiGlowButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AiGlowButton({required this.onTap});

  @override
  State<_AiGlowButton> createState() => _AiGlowButtonState();
}

class _AiGlowButtonState extends State<_AiGlowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          // shimmer 光从 -1.0 扫到 2.0（含进出过渡）
          final sweep = _ctrl.value * 3.0 - 1.0;
          return Container(
            width: 40,
            height: 26,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(children: [
                // 电流扫光层
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ShimmerPainter(position: sweep),
                  ),
                ),
                // AI 文字
                Center(
                  child: Text(
                    'AI',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// 电流扫光 CustomPainter — 一道细白光斜线从左到右扫过
class _ShimmerPainter extends CustomPainter {
  final double position; // -1.0 ~ 2.0

  const _ShimmerPainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final x = position * size.width;
    final w = size.width * 0.55; // 光带宽度
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.38),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(x - w / 2, 0, w, size.height));

    // 斜切光带（倾斜 20°）
    final path = Path()
      ..moveTo(x - w / 2 + size.height * 0.28, 0)
      ..lineTo(x + w / 2 + size.height * 0.28, 0)
      ..lineTo(x + w / 2 - size.height * 0.28, size.height)
      ..lineTo(x - w / 2 - size.height * 0.28, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.position != position;
}
