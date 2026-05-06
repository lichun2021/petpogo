import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'features/auth/controller/auth_controller.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化腾讯 IM SDK
  // LogLevelEnum.V2TIM_LOG_WARN：只打印警告/错误（生产环境用 NONE）
  await TencentImSDKPlugin.v2TIMManager.initSDK(
    sdkAppID: AppConfig.timSdkAppId,
    loglevel: LogLevelEnum.V2TIM_LOG_WARN,
    listener: V2TimSDKListener(
      onConnecting: ()       => debugPrint('[TIM] 连接中...'),
      onConnectSuccess: ()   => debugPrint('[TIM] ✅ 连接成功'),
      onConnectFailed: (c, e)=> debugPrint('[TIM] ❌ 连接失败: $c $e'),
      onKickedOffline: ()    => debugPrint('[TIM] ⚠️ 账号在其他设备登录，被踢下线'),
      onUserSigExpired: ()   => debugPrint('[TIM] ⚠️ UserSig 已过期，需重新登录'),
    ),
  );
  debugPrint('[TIM] SDK 初始化完成 (SDKAppID: ${AppConfig.timSdkAppId})');

  // ── 创建全局 ProviderContainer，注入给路由守卫 ─────────────
  // GoRouter 是顶层变量（非 Widget），需要通过 ProviderContainer 读取 Riverpod 状态
  final container = ProviderContainer();
  initAppRouter(container);

  // 监听 AuthState 变化 → 通知 GoRouter 重新执行 redirect（刷新守卫）
  container.listen<AuthState>(
    authControllerProvider,
    (previous, next) {
      // restoring → guest 或 loggedIn 时刷新路由
      if (previous?.status != next.status) {
        debugPrint('[Router] Auth 状态变化: ${previous?.status} → ${next.status}，刷新路由守卫');
        appRouter.refresh();
      }
    },
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PetPogoApp(),
    ),
  );
}

