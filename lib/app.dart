import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'shared/theme/app_theme.dart';
import 'shared/theme/app_fonts.dart';
import 'core/providers/locale_provider.dart';
import 'core/router/app_router.dart';
import 'l10n/app_localizations.dart';

export 'l10n/app_localizations.dart';

/// 全局 NavigatorKey，用于在无 BuildContext 时（如 IM SDK 回调）弹出系统级对话框
/// 传入 GoRouter 的 navigatorKey，使 GoRouter 内部使用这个 Navigator
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

/// 便捷扩展：任意 Widget 内用 context.l10n 获取当前语言的识别
extension AppL10nX on BuildContext {
  AppL10n get l10n => AppL10n.of(this)!;
}

/// 应用根 Widget
///
/// 职责：
///   1. 配置全局主题
///   2. 配置多语言（中/英）
///   3. 挂载路由（来自 core/router/app_router.dart）
///   4. 监听 localeProvider，语言切换时自动重建
///
/// ⚠️ 导航栏相关代码已迁移：
///   - GlassBottomNav / NavButton / NavItem → shared/widgets/glass_bottom_nav.dart
///   - MainShell                           → features/shell/main_shell.dart
class PetPogoApp extends ConsumerWidget {
  const PetPogoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听语言设置（设置页切换语言后自动触发重建）
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'PetPogo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,

      // ── 全局字体配置：字体由 AppFonts.primary 统一控制 ──
      // 换字体：改 AppFonts.primary；字号缩放见 app_theme.dart TextTheme
      builder: (context, child) => DefaultTextStyle.merge(
        style: TextStyle(fontFamilyFallback: AppFonts.fallback),
        child: child!,
      ),

      // ── 多语言代理 ─────────────────────────────────────────
      localizationsDelegates: const [
        AppL10n.delegate,                      // 项目自有本地化
        GlobalMaterialLocalizations.delegate,  // Material 组件
        GlobalWidgetsLocalizations.delegate,   // Widget 文字方向
        GlobalCupertinoLocalizations.delegate, // Cupertino 组件
      ],
      supportedLocales: const [
        Locale('zh'), // 中文（默认）
        Locale('en'), // English
      ],

      // ── 路由配置 ───────────────────────────────────────────
      // 所有页面路由、过渡动画、守卫逻辑集中在 app_router.dart
      routerConfig: appRouter,
    );
  }
}
