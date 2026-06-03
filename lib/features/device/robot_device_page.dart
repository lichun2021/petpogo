import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../shell/main_shell.dart' show hideBottomNavProvider;
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import '../auth/controller/auth_controller.dart';
import '../device/data/models/device_model.dart';
import '../device/data/repository/device_repository.dart';
import 'device_detail_page.dart';
import '../bind_device/select_device_page.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

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
  double _deviceVolume = 100; // 设备音量 0~100
  bool _cameraOn = true;

  // ── Agora 视频推流状态 ──────────────────────────────────
  RtcEngine? _engine;
  AgoraTokenInfo? _agoraInfo;
  int?   _remoteUid;     // ESP32 的 uid（通常 10002）
  bool   _agoraLoading  = false;
  bool   _agoraJoined   = false;
  bool   _micOn         = false;
  String? _agoraError;
  double _kbps         = 0;
  bool   _videoFrozen  = false; // 视频网络拥塑冻结状态
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
    // 页面打开后自动启动视频
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAgora());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _statsTimer?.cancel();
    // 取出引擎引用后立即置 null（dispose 不能 await，用 fire-and-forget）
    final engine = _engine;
    _engine = null;
    _agoraJoined = false;
    _remoteUid = null;
    if (engine != null) {
      // 先禁用音量回调（interval=0），再离开频道、释放引擎
      engine
          .enableAudioVolumeIndication(interval: 0, smooth: 3, reportVad: false)
          .then((_) => engine.leaveChannel())
          .then((_) => engine.release())
          .catchError((e) {
        debugPrint('[Agora] dispose 清理异常（可忽略）: $e');
      });
    }
    super.dispose();
  }

  // ── Agora 工具方法 ──────────────────────────────────────

  /// 初始化引擎 + 加入频道
  Future<void> _startAgora() async {
    if (_agoraLoading || _agoraJoined) return;
    setState(() { _agoraLoading = true; _agoraError = null; });
    try {
      // 1. 请求权限
      final statuses = await [Permission.microphone, Permission.camera].request();
      debugPrint('[🔊音频] 权限状态: mic=${statuses[Permission.microphone]} cam=${statuses[Permission.camera]}');

      // 2. 获取 Token（下发 ESP32 参数）
      final auth  = ref.read(authControllerProvider);
      final userId = auth.user?.id ?? '0';
      final info = await ref.read(deviceRepositoryProvider)
          .getAgoraToken(mac: widget.mac, customerId: userId);
      _agoraInfo = info;
      debugPrint('[Agora] Token 获取成功 channel=${info.channelName} uid=${info.userId}');

      // 3. 创建引擎
      _engine = createAgoraRtcEngine();
      debugPrint('[Agora] 开始 initialize, appId=${info.appId}');
      await _engine!.initialize(RtcEngineContext(
        appId: info.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      debugPrint('[Agora] initialize 成功');

      // 4. ⭐ 关键: 设置 JPEG 解码（仅 Android 有效）+ 低延迟优化
      if (Platform.isAndroid) {
        try {
          await _engine!.setParameters('{"engine.video.codec_type": "20"}');
          await _engine!.setParameters('{"rtc.video.playout_delay_min": 0}');
          await _engine!.setParameters('{"rtc.video.playout_delay_max": 300}');
          debugPrint('[Agora] setParameters JPEG 成功');
        } catch (e) {
          debugPrint('[Agora] setParameters JPEG 失败（可忽略）: $e');
        }
      }

      // 5. 启用音视频 + IoT 音频模式
      debugPrint('[🔊音频] enableVideo...');
      await _engine!.enableVideo();
      debugPrint('[🔊音频] enableAudio...');
      await _engine!.enableAudio();
      debugPrint('[🔊音频] setAudioProfile: Default + Chatroom...');
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );
      debugPrint('[🔊音频] setAudioProfile 完成');
      debugPrint('[🔊音频] enableLocalVideo(false)...');
      await _engine!.enableLocalVideo(false);  // APP 不发送本地摄像头

      // 开启音量提示（每秒回调一次，用于调试音频是否有数据流入）
      await _engine!.enableAudioVolumeIndication(
        interval: 1000, smooth: 3, reportVad: false,
      );
      debugPrint('[🔊音频] enableAudioVolumeIndication 已开启（1s 间隔）');

      // 6. 注册事件
      debugPrint('[Agora] registerEventHandler...');
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (_, __) {
          if (mounted) setState(() { _agoraJoined = true; _agoraLoading = false; });
          // 加入频道后再开启扬声器（防止提前调用报 -3）
          _engine?.setEnableSpeakerphone(true);
          debugPrint('[🔊音频] 加入频道成功 → setEnableSpeakerphone(true)');
        },
        onUserJoined: (_, uid, __) {
          if (mounted) setState(() => _remoteUid = uid);
          debugPrint('[🔊音频] 远端用户加入 uid=$uid（ESP32）');
          // 加入后确认没有静音远端
          _engine?.muteRemoteAudioStream(uid: uid, mute: false);
          debugPrint('[🔊音频] muteRemoteAudioStream(uid=$uid, mute=false) ← 确保不静音');
        },
        onUserOffline: (_, uid, __) {
          if (mounted) setState(() => _remoteUid = null);
          debugPrint('[🔊音频] 远端用户离线 uid=$uid');
        },
        onRtcStats: (_, stats) {
          if (!mounted) return;
          setState(() {
            _kbps = stats.rxVideoKBitRate?.toDouble() ?? 0;
          });
          final rxAudio = stats.rxAudioKBitRate ?? 0;
          final txAudio = stats.txAudioKBitRate ?? 0;
          if (rxAudio > 0 || txAudio > 0) {
            debugPrint('[🔊音频] Stats → rxAudio=${rxAudio}kbps txAudio=${txAudio}kbps '
                'rxVideo=${stats.rxVideoKBitRate ?? 0}kbps');
          } else {
            debugPrint('[🔊音频] ⚠️ Stats → rxAudio=0 txAudio=0（未收到音频数据！）');
          }
        },

        // ── 远端音频状态变化（关键诊断事件）──
        onRemoteAudioStateChanged: (_, uid, state, reason, __) {
          debugPrint('[🔊音频] 远端音频状态变化 uid=$uid '
              'state=$state reason=$reason');
          // state: 0=stopped 1=starting 2=decoding 3=frozen 4=failed
          // reason: 0=internal 1=localMuted 2=localUnmuted 3=remoteMuted
          //         4=remoteUnmuted 5=remoteOffline 6=noPacketReceived
          final stateStr = const {0:'stopped',1:'starting',2:'decoding ✅',3:'frozen❄️',4:'failed❌'}[state.value] ?? 'unknown';
          final reasonStr = const {0:'internal',1:'localMuted',2:'localUnmuted',3:'remoteMuted',4:'remoteUnmuted',5:'remoteOffline',6:'noPacketReceived'}[reason.value] ?? 'unknown';
          debugPrint('[🔊音频] → state=$stateStr  reason=$reasonStr');
        },
        // ── 音量回调（有声音时 volume > 0）──
        onAudioVolumeIndication: (_, speakers, __, totalVolume) {
          if (!mounted) return;  // 页面已销毁，不处理
          for (final s in speakers) {
            if ((s.volume ?? 0) > 0) {
              debugPrint('[🔊音频] 音量回调 uid=${s.uid} volume=${s.volume}');
            }
          }
          if (totalVolume == 0 && speakers.isNotEmpty) {
            debugPrint('[🔊音频] ⚠️ totalVolume=0，所有音频静音或无数据');
          }
        },
        // ── 音频路由变化（扬声器/听筒/耳机）──
        onAudioRoutingChanged: (routing) {
          if (!mounted) return;
          // -1=default 0=headset 1=earpiece 2=speakerphone 3=bluetooth 4=usb
          final routeStr = const {-1:'default',0:'headset',1:'earpiece',2:'speakerphone ✅',3:'bluetooth',4:'usb_audio'}[routing] ?? 'unknown($routing)';
          debugPrint('[🔊音频] 音频路由变化 → $routeStr');
        },
        onError: (err, msg) {
          debugPrint('[Agora] 错误 $err: $msg');
          if (mounted) setState(() => _agoraError = 'Agora错误 $err');
        },
        onTokenPrivilegeWillExpire: (_, __) {
          _startAgora();
        },
        onConnectionStateChanged: (_, state, reason) {
          debugPrint('[Agora] 连接状态: $state reason=$reason');
        },
        onRemoteVideoStateChanged: (_, uid, state, reason, __) {
          debugPrint('[Agora] 远端视频状态 uid=$uid state=$state reason=$reason');
          final frozen = state == RemoteVideoState.remoteVideoStateFrozen;
          if (mounted && frozen != _videoFrozen) {
            setState(() => _videoFrozen = frozen);
          }
        },
      ));

      // 7. 加入频道
      debugPrint('[🔊音频] setClientRole → Broadcaster');
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableLocalAudio(true);
      await _engine!.muteLocalAudioStream(true);  // 默认静音本地麦克风
      debugPrint('[🔊音频] enableLocalAudio=true muteLocalAudioStream=true（对讲默认关）');
      debugPrint('[Agora] joinChannel...');
      await _engine!.joinChannel(
        token: info.token,
        channelId: info.channelName,
        uid: info.userId,
        options: const ChannelMediaOptions(
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
          publishCameraTrack: false,
          publishMicrophoneTrack: true,
        ),
      );
      debugPrint('[Agora] joinChannel 调用完成（等待 onJoinChannelSuccess）');
    } catch (e, st) {
      debugPrint('[Agora] 初始化失败: $e\n$st');
      if (mounted) setState(() { _agoraLoading = false; _agoraError = e.toString(); });
    }
  }


  /// 离开频道 + 释放引擎
  Future<void> _stopAgora() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    _agoraJoined = false;
    _remoteUid = null;
  }

  /// 对讲开关（Broadcaster 模式下直接 mute/unmute，无需切换角色）
  Future<void> _toggleMic() async {
    if (_engine == null) return;
    final next = !_micOn;
    if (next) {
      await _engine!.enableLocalAudio(true);
      await _engine!.muteLocalAudioStream(false);
    } else {
      await _engine!.muteLocalAudioStream(true);
      await _engine!.enableLocalAudio(false);
    }
    setState(() => _micOn = next);
  }

  // ── 电机控制（PeerApiSpeed 接口）──────────────────────
  void _sendMotorControl(int m0Dir, int m0Speed, int m1Dir, int m1Speed) {
    final base = _moveSpeed.toInt();
    final scaledM0 = (m0Speed * base ~/ 100).clamp(0, 100);
    final scaledM1 = (m1Speed * base ~/ 100).clamp(0, 100);

    // 可读日志（direction: 1=正转↑, 2=反转↓, 0=停止）
    String dirStr(int d) => d == 1 ? '正转↑' : d == 2 ? '反转↓' : '停止■';
    debugPrint('[遥控] 左轮(motor_0): ${dirStr(m0Dir)} speed=$scaledM0 | '
        '右轮(motor_1): ${dirStr(m1Dir)} speed=$scaledM1 | base=$base%');

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
    // 横屏时（进入全屏）返回纯黑，防止底层页面跟着旋转报 OVERFLOW
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.landscape) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final screenH = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(children: [
        _buildTopBar(context),
        _buildCameraView(screenH),
        _buildTabBar(screenH),
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
            // 设备名 + 下拉（Flexible 防止长名称溢出）
            Flexible(
              child: GestureDetector(
                onTap: () => _showDeviceSwitcher(context),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(
                      widget.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.onPrimary, size: 22),
                ]),
              ),
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

  // ── 摄像头区域（Agora 视频流）────────────────────────────
  Widget _buildCameraView(double screenH) {
    final cameraH = (screenH * 0.27).clamp(160.0, 220.0);
    return Container(
      height: cameraH,
      decoration: const BoxDecoration(
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
            // ── 视频内容区 ──────────────────────────────────
            if (_agoraJoined && _remoteUid != null && _agoraInfo != null && Platform.isAndroid)
              // Android：显示 Agora JPEG 视频流
              AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine!,
                  canvas: VideoCanvas(uid: _remoteUid!),
                  connection: RtcConnection(channelId: _agoraInfo!.channelName),
                ),
              )
            else if (_agoraLoading)
              // 连接中
              Container(
                color: AppColors.inverseSurface,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 36, height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primaryContainer)),
                    const SizedBox(height: 12),
                    Text('连接设备摄像头...',
                        style: TextStyle(fontFamily: AppFonts.primary,
                            fontSize: 13,
                            color: AppColors.onPrimary.withOpacity(0.6))),
                  ],
                ),
              )
            else if (_agoraError != null)
              // 错误状态
              Container(
                color: AppColors.inverseSurface,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 40, color: AppColors.onPrimary.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text('视频连接失败',
                        style: TextStyle(fontFamily: AppFonts.primary,
                            fontSize: 13,
                            color: AppColors.onPrimary.withOpacity(0.6))),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _startAgora,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('点击重试',
                            style: TextStyle(fontFamily: AppFonts.primary,
                                fontSize: 12, color: AppColors.primaryContainer)),
                      ),
                    ),
                  ],
                ),
              )
            else if (Platform.isIOS && _agoraJoined)
              // iOS：仅音频提示
              Container(
                color: AppColors.inverseSurface,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volume_up_rounded,
                        size: 48, color: AppColors.onPrimary.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text('iOS 仅支持音频对讲',
                        style: TextStyle(fontFamily: AppFonts.primary,
                            fontSize: 13,
                            color: AppColors.onPrimary.withOpacity(0.6))),
                    Text('ESP32 H.264 升级后可支持 iOS 视频',
                        style: TextStyle(fontFamily: AppFonts.primary,
                            fontSize: 11,
                            color: AppColors.onPrimary.withOpacity(0.4))),
                  ],
                ),
              )
            else
              // 占位图
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
                            fontFamily: AppFonts.primary,
                            fontSize: 13,
                            color: AppColors.onPrimary.withOpacity(0.45))),
                  ],
                ),
              ),

            // 视频冻结提示层（网络拥塑时）
            if (_videoFrozen && _remoteUid != null)
              Positioned(
                bottom: 8, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white70)),
                        SizedBox(width: 8),
                        Text('网络恢复中...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
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
                child: Text(
                  '${_kbps.toStringAsFixed(0)}\nKB/s',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: AppFonts.primary,
                      fontSize: 9, color: Colors.white, height: 1.3),
                ),
              ),
            ),

            // 摄像头开关（左下）
            Positioned(
              bottom: 10, left: 10,
              child: GestureDetector(
                onTap: () {
                  setState(() => _cameraOn = !_cameraOn);
                  if (_cameraOn) { _startAgora(); } else { _stopAgora(); setState(() {}); }
                },
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

            // 连接状态标签（右上）
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _remoteUid != null
                      ? Colors.green.withOpacity(0.8)
                      : Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: _remoteUid != null ? Colors.greenAccent : Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _remoteUid != null ? '已连接' : '等待设备',
                    style: const TextStyle(fontFamily: AppFonts.primary,
                        fontSize: 9, color: Colors.white),
                  ),
                ]),
              ),
            ),

            // 全屏按鈕（右下）
            Positioned(
              bottom: 10, right: 10,
              child: GestureDetector(
                onTap: () {
                  if (_engine == null || _agoraInfo == null) return;
                  // 全屏前隐藏底部导航栏
                  ref.read(hideBottomNavProvider.notifier).state = true;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) =>
                      _FullscreenVideoPage(
                        engine:      _engine!,
                        channelName: _agoraInfo!.channelName,
                        remoteUid:   _remoteUid,
                        onControl:   _sendMotorControl,
                        micOn:       _micOn,
                        onToggleMic: _toggleMic,
                      ),
                    ),
                  ).then((_) {
                    // 退出全屏后恢复底部导航栏
                    ref.read(hideBottomNavProvider.notifier).state = false;
                  });
                },
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fullscreen_rounded,
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
    final iconPad  = screenH < 700 ? 8.0 : 12.0;
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
                duration: const Duration(milliseconds: 200),
                width: iconSize, height: iconSize,
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
                    size: iconSize * 0.43,
                    color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(tabs[i].$2,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: screenH < 700 ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.primary : AppColors.onSurfaceVariant,
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
          final innerW = outer.maxWidth  - 48; // 内边距 24×2
          final innerH = outer.maxHeight - 80; // 顶部行 ~46 + 底部留白 ~34
          final padR   = (innerW.clamp(0, innerH) / 2).clamp(70.0, 130.0);

          return Container(
            width:  outer.maxWidth,
            height: outer.maxHeight,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 16, offset: const Offset(0, 4),
              )],
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
                  top: 14, left: 20, right: 14,
                  child: Row(
                    children: [
                      // const Text('拖动方向盘控制机器人移动',
                      //     style: TextStyle(fontFamily: AppFonts.primary,
                      //         fontSize: 11,
                      //         color: AppColors.onSurfaceVariant)),
                      // const Spacer(),
                      GestureDetector(
                        onTap: () => _showSpeedSheet(context),
                        child: Container(
                          width: 34, height: 34,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.tune_rounded,
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
                  style: TextStyle(fontFamily: AppFonts.primary,
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
                    style: const TextStyle(fontFamily: AppFonts.primary,
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
            // const Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     Text('慢速 10%', style: TextStyle(fontFamily: AppFonts.primary,
            //         fontSize: 12, color: AppColors.onSurfaceVariant)),
            //     Text('快速 100%', style: TextStyle(fontFamily: AppFonts.primary,
            //         fontSize: 12, color: AppColors.onSurfaceVariant)),
            //   ],
            // ),
            const SizedBox(height: 8),

            // ── 设备音量 ────────────────────────────────
            const Divider(height: 28),
            Row(children: [
              const Icon(Icons.volume_up_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              const Text('设备音量',
                  style: TextStyle(fontFamily: AppFonts.primary,
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: AppColors.onSurface)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_deviceVolume.toInt()}%',
                    style: const TextStyle(fontFamily: AppFonts.primary,
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
                value: _deviceVolume, min: 0, max: 100,
                divisions: 10,
                onChanged: (v) {
                  setLocal(() {});
                  setState(() => _deviceVolume = v);
                  // 调节 Agora 远端播放音量
                  if (_remoteUid != null) {
                    _engine?.adjustUserPlaybackSignalVolume(
                      uid: _remoteUid!,
                      volume: v.toInt(),
                    );
                  }
                },
              ),
            ),
            // const Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     Text('静音 0%', style: TextStyle(fontFamily: AppFonts.primary,
            //         fontSize: 12, color: AppColors.onSurfaceVariant)),
            //     Text('最大 100%', style: TextStyle(fontFamily: AppFonts.primary,
            //         fontSize: 12, color: AppColors.onSurfaceVariant)),
            //   ],
            // ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // ── 精确计算 GridView 列宽 ──────────────────────────
        // SingleChildScrollView padding 20, Container padding 16 → 水平内缩 72
        // crossAxisSpacing = 12，三列两间距 = 24
        const crossSpacing = 12.0;
        final gridW  = constraints.maxWidth - 72;          // 可用网格总宽
        final colW   = (gridW - crossSpacing * 2) / 3;     // 实际每列宽
        // 按钮大小跟随列宽，上限 88（大屏更充实）
        final btnSize  = colW.clamp(48.0, 88.0);
        final iconSize = btnSize * 0.44;
        // 每格内容高 = 按钮 + 文字 + 间距，childAspectRatio 基于实际列宽
        final contentH = btnSize + 6 + 18.0;               // 6=SizedBox, 18=text
        final ratio    = colW / contentH;                  // 用列宽除以内容高
        final spacing  = constraints.maxHeight < 380 ? 8.0 : 12.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('机器人动作',
                style: TextStyle(fontFamily: AppFonts.primary,
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: AppColors.onSurface)),
            SizedBox(height: spacing),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16)],
              ),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: spacing,
                crossAxisSpacing: crossSpacing,
                childAspectRatio: ratio,   // ← 基于实际列宽，大屏不再出现巨大间距
                children: actions.map((a) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      PetToast.warning(context, '执行动作：${a.$1}');
                    },
                    child: Column(mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: btnSize, height: btnSize,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [a.$2, a.$3],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(btnSize * 0.28),
                          boxShadow: [BoxShadow(
                            color: a.$2.withOpacity(0.35),
                            blurRadius: 8, offset: const Offset(0, 3),
                          )],
                        ),
                        child: Icon(a.$4, color: Colors.white, size: iconSize),
                      ),
                      const SizedBox(height: 6),
                      Text(a.$1,
                          style: const TextStyle(fontFamily: AppFonts.primary,
                              fontSize: 12, fontWeight: FontWeight.w600,
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
                    style: TextStyle(fontFamily: AppFonts.primary,
                        fontSize: 15, fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary)),
                Text('查看拍照和录像',
                    style: TextStyle(fontFamily: AppFonts.primary,
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

  // ── 对讲标签（Agora 开麦克对讲）────────────────────────────
  Widget _buildIntercom() {
    final isReady = _agoraJoined;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final micSize = h < 350 ? 88.0 : 120.0;
        final gap1 = h < 350 ? 10.0 : 20.0;
        final gap2 = h < 350 ? 16.0 : 32.0;
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: h),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 麦克风图标（麦开时变绿）
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: micSize, height: micSize,
                    decoration: BoxDecoration(
                      gradient: _micOn
                          ? const LinearGradient(
                              colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight)
                          : AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: _micOn
                            ? Colors.green.withOpacity(0.4)
                            : AppColors.primaryGlow,
                        blurRadius: _micOn ? 40 : 30, spreadRadius: 0,
                      )],
                    ),
                    child: Icon(
                      _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                      size: micSize * 0.43, color: AppColors.onPrimary,
                    ),
                  ),
                  SizedBox(height: gap1),
                  Text(
                    isReady ? (_micOn ? '对讲中...' : '连接已建立') : '连接设备中...',
                    style: const TextStyle(fontFamily: AppFonts.primary,
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isReady ? '点击按钮开启/关闭对讲' : '请稍候...',
                    style: const TextStyle(fontFamily: AppFonts.primary,
                        fontSize: 14, color: AppColors.onSurfaceVariant),
                  ),
                  SizedBox(height: gap2),
                  // 对讲按钮
                  GestureDetector(
                    onTap: isReady ? _toggleMic : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: isReady
                            ? (_micOn
                                ? const LinearGradient(
                                    colors: [Color(0xFF43A047), Color(0xFF66BB6A)])
                                : AppColors.primaryGradient)
                            : null,
                        color: isReady ? null : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: isReady ? [BoxShadow(
                          color: _micOn
                              ? Colors.green.withOpacity(0.4)
                              : AppColors.primaryGlow,
                          blurRadius: 16, offset: const Offset(0, 6),
                        )] : [],
                      ),
                      child: Text(
                        isReady ? (_micOn ? '关闭对讲' : '开启对讲') : '连接中...',
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: isReady ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  // 错误信息
                  if (_agoraError != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(_agoraError!,
                          style: const TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 11, color: Colors.redAccent),
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
              style: TextStyle(fontFamily: AppFonts.primary,
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
                      style: TextStyle(fontFamily: AppFonts.primary,
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.primary : AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(isRobot ? '智能宠物机器人' : '智能项圈',
                        style: const TextStyle(fontFamily: AppFonts.primary,
                            fontSize: 11, color: AppColors.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: d.isOnline ? AppColors.success : AppColors.onSurfaceVariant,
                          shape: BoxShape.circle,
                        )),
                    const SizedBox(width: 4),
                    Text(d.isOnline ? '在线' : '离线',
                        style: TextStyle(fontFamily: AppFonts.primary,
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
    setState(() { _knob = Offset.zero; _active = false; });
    widget.onControl(0, 0, 0, 0);
  }

  void _computeAndSend(Offset knob) {
    final dx =  knob.dx / _maxDist;
    final dy = -knob.dy / _maxDist;
    final left  = (dy + dx).clamp(-1.0, 1.0);
    final right = (dy - dx).clamp(-1.0, 1.0);
    widget.onControl(
      left  >= 0 ? 1 : 2, (left.abs()  * 100).round().clamp(0, 100),
      right >= 0 ? 1 : 2, (right.abs() * 100).round().clamp(0, 100),
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
        _startTimer(); // 只在 Timer 未启动时才启动，不受 move 事件频率影响
      },
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: SizedBox(
        width: diameter, height: diameter,
        child: Stack(alignment: Alignment.center, children: [
          // 外圆背景
          if (widget.transparent)
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: diameter, height: diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // 深色半透明，白/黑背景都清晰
                    color: Colors.black.withOpacity(0.40),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.55), width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 20, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
            width: diameter, height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerLow,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2), width: 2,
              ),
              boxShadow: widget.transparent ? [] : [BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12, offset: const Offset(0, 4),
              )],
            ),
          ),
          // 方向图标
          Positioned(top: 10, child: Icon(Icons.keyboard_arrow_up_rounded,
              size: 22, color: widget.transparent
                  ? Colors.white
                  : AppColors.primary.withOpacity(0.35))),
          Positioned(bottom: 10, child: Icon(Icons.keyboard_arrow_down_rounded,
              size: 22, color: widget.transparent
                  ? Colors.white
                  : AppColors.primary.withOpacity(0.35))),
          Positioned(left: 10, child: Icon(Icons.keyboard_arrow_left_rounded,
              size: 22, color: widget.transparent
                  ? Colors.white
                  : AppColors.primary.withOpacity(0.35))),
          Positioned(right: 10, child: Icon(Icons.keyboard_arrow_right_rounded,
              size: 22, color: widget.transparent
                  ? Colors.white
                  : AppColors.primary.withOpacity(0.35))),
          // 摇杆头（透明模式用玻璃质感）
          Transform.translate(
            offset: _knob,
            child: widget.transparent
                ? ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: AnimatedContainer(
                        duration: _active ? Duration.zero : const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        width: _thumbR * 2, height: _thumbR * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // 深色半透明，白色背景下也清晰
                          color: _active
                              ? Colors.white.withOpacity(0.30)
                              : Colors.black.withOpacity(0.55),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.80), width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(_active ? 0.5 : 0.3),
                              blurRadius: _active ? 22 : 10,
                            ),
                          ],
                        ),
                        child: Icon(Icons.pets_rounded,
                            color: Colors.white,
                            size: _active ? 24 : 20),
                      ),
                    ),
                  )
                : AnimatedContainer(
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
  final RtcEngine engine;
  final String channelName;
  final int? remoteUid;
  final void Function(int, int, int, int) onControl;
  final bool micOn;
  final Future<void> Function() onToggleMic;

  const _FullscreenVideoPage({
    required this.engine,
    required this.channelName,
    required this.remoteUid,
    required this.onControl,
    required this.micOn,
    required this.onToggleMic,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _interactOpen = false;
  bool _micOn = false;
  bool _speakerOn = true;

  static const _interactItems = [
    (Icons.music_note_rounded,    '安抚'),
    (Icons.sports_tennis_rounded, '玩耗'),
    (Icons.stars_rounded,         '逢趣'),
    (Icons.restaurant_rounded,    '喜食'),
  ];

  @override
  void initState() {
    super.initState();
    _micOn = widget.micOn;
    // 全屏时横屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // 退出全屏时恢复竖屏
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _toggleMic() async {
    await widget.onToggleMic();
    setState(() => _micOn = !_micOn);
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
          if (widget.remoteUid != null && Platform.isAndroid)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: widget.engine,
                canvas: VideoCanvas(uid: widget.remoteUid!),
                connection: RtcConnection(channelId: widget.channelName),
              ),
            )
          else
            const Center(child: Icon(Icons.videocam_off_rounded,
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
                const SizedBox(width: 10),
                _GlassBtn(
                  icon: _speakerOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  active: _speakerOn,
                  onTap: () async {
                    setState(() => _speakerOn = !_speakerOn);
                    await widget.engine.setEnableSpeakerphone(_speakerOn);
                  },
                ),
                const SizedBox(width: 10),
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
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: _interactOpen ? safe.top + 60.0 : -140.0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
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
                        const SizedBox(height: 6),
                        Text(item.$2,
                            style: const TextStyle(
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
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: size, height: size,
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
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon,
                size: size * 0.45,
                color: active ? Colors.white : Colors.white),
          ),
        ),
      ),
    );
  }
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
        Text(label, style: TextStyle(fontFamily: AppFonts.primary,
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
          Text(label, style: TextStyle(fontFamily: AppFonts.primary,
              fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}
