import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'core/config/app_config.dart';
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

  runApp(const ProviderScope(child: PetPogoApp()));
}
