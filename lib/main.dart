import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/providers/font_provider.dart';
import 'core/providers/color_scheme_provider.dart';
import 'core/providers/video_quality_provider.dart';
import 'core/push/push_service.dart';
import 'shared/theme/app_fonts.dart';
import 'shared/theme/app_colors.dart';
import 'shared/theme/color_schemes.dart';
import 'features/auth/controller/auth_controller.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // 必须在 ensureInitialized 之后第一时间调用

  // ── 启动时同步加载保存的字体和主题 ────────────────────────────────
  // 必须在 ProviderContainer 创建之前完成，确保 provider 直接以正确值启动
  // （避免异步 _loadSaved 竞态：先以默认值渲染，异步加载后再更新的 bug）
  final prefs = await SharedPreferences.getInstance();

  // 恢复字体
  final savedFont = prefs.getString(kFontKey) ?? AppFonts.primary;
  AppFonts.primary = savedFont;

  // 恢复配色
  final savedThemeKey = prefs.getString(kThemeKey) ?? warmPinkScheme.key;
  final savedScheme = kColorSchemes.firstWhere(
    (s) => s.key == savedThemeKey,
    orElse: () => warmPinkScheme,
  );
  AppColors.setScheme(savedScheme);

  // 恢复录像质量
  final savedVideoQuality = prefs.getString(kVideoQualityKey) ?? 'medium';

  debugPrint('[启动] 恢复字体: $savedFont  配色: $savedThemeKey  录像质量: $savedVideoQuality');

  // 初始化腾讯 IM SDK
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

  // ── 初始化极光推送 ──────────────────────────────────────────────────
  await PushService.init();

  // ── 创建全局 ProviderContainer，通过 overrides 注入已恢复的初始值 ──
  final container = ProviderContainer(
    overrides: [
      // 直接以保存的值为初始状态，避免从默认值闪一下再切换
      fontFamilyProvider.overrideWith(
        (ref) => FontFamilyNotifier(savedFont),
      ),
      colorSchemeProvider.overrideWith(
        (ref) => ColorSchemeNotifier(savedThemeKey),
      ),
      videoQualityProvider.overrideWith(
        (ref) => VideoQualityNotifier(savedVideoQuality),
      ),
    ],
  );

  initAppRouter(container);

  // 监听 AuthState 变化 → 通知 GoRouter 重新执行 redirect
  container.listen<AuthState>(
    authControllerProvider,
    (previous, next) {
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
