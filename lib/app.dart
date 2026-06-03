import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'shared/theme/app_theme.dart';
import 'shared/theme/app_fonts.dart';
import 'shared/theme/app_colors.dart';
import 'shared/theme/color_schemes.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/font_provider.dart';
import 'core/providers/color_scheme_provider.dart';
import 'core/router/app_router.dart';
import 'l10n/app_localizations.dart';

export 'l10n/app_localizations.dart';

/// 全局 NavigatorKey，用于在无 BuildContext 时（如 IM SDK 回调）弹出系统级对话框
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
///   4. 监听 localeProvider / fontFamilyProvider / colorSchemeProvider
///
/// ⚠️ 导航栏相关代码已迁移：
///   - GlassBottomNav / NavButton / NavItem → shared/widgets/glass_bottom_nav.dart
///   - MainShell                           → features/shell/main_shell.dart
class PetPogoApp extends ConsumerWidget {
  const PetPogoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听语言设置
    final locale      = ref.watch(localeProvider);
    // 监听字体设置（变化时全局刷新）
    final fontFamily  = ref.watch(fontFamilyProvider);
    // 监听配色方案（变化时全局刷新）
    final schemeKey   = ref.watch(colorSchemeProvider);

    // ── 双重保障同步：build 里也强制更新静态变量 ─────────────
    // 这样即使 Provider 的异步 _loadSaved 有时序差，AppTheme.light
    // 被调用时 AppColors._scheme 也已经是最新值
    AppFonts.primary = fontFamily;
    AppColors.setScheme(
      kColorSchemes.firstWhere(
        (s) => s.key == schemeKey,
        orElse: () => warmPinkScheme,
      ),
    );

    return MaterialApp.router(
      // 字体 OR 配色变化时，通过 ValueKey 强制重建整个 App
      key: ValueKey('$fontFamily|$schemeKey'),
      title: 'PetPogo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,

      // ── 全局字体配置 ───────────────────────────────────────
      builder: (context, child) => DefaultTextStyle.merge(
        style: TextStyle(fontFamilyFallback: AppFonts.fallback),
        child: child!,
      ),

      // ── 多语言代理 ─────────────────────────────────────────
      localizationsDelegates: [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('zh'),
        Locale('en'),
      ],

      // ── 路由配置 ───────────────────────────────────────────
      routerConfig: appRouter,
    );
  }
}
