import 'package:flutter/material.dart';
import 'color_schemes.dart';

/// PetPogo 全局颜色访问入口
///
/// 通过 [AppColors.setScheme] 切换配色方案，所有 getter 自动返回新值。
/// 切换后需配合 [app.dart] 的 ValueKey 强制全局重建，颜色即生效。
///
/// 用法与原来完全一致：`AppColors.primary`、`AppColors.surface` 等。
class AppColors {
  AppColors._();

  // ─── 当前方案 ───────────────────────────────────────────
  static PetColorScheme _scheme = warmPinkScheme;

  static PetColorScheme get current => _scheme;

  static void setScheme(PetColorScheme scheme) {
    _scheme = scheme;
  }

  // ─── Primary ────────────────────────────────────────────
  static Color get primary            => _scheme.primary;
  static Color get primaryDim         => _scheme.primaryDim;
  static Color get primaryContainer   => _scheme.primaryContainer;
  static Color get primaryFixed       => _scheme.primaryFixed;
  static Color get primaryFixedDim    => _scheme.primaryFixedDim;
  static Color get onPrimary          => _scheme.onPrimary;
  static Color get onPrimaryContainer => _scheme.onPrimaryContainer;
  static Color get onPrimaryFixed     => _scheme.onPrimaryContainer;
  static Color get inversePrimary     => _scheme.inversePrimary;

  // ─── Secondary ──────────────────────────────────────────
  static Color get secondary              => _scheme.secondary;
  static Color get secondaryDim          => _scheme.secondary;
  static Color get secondaryContainer    => _scheme.secondaryContainer;
  static Color get secondaryFixed        => _scheme.secondaryContainer;
  static Color get secondaryFixedDim     => _scheme.secondaryContainer;
  static Color get onSecondary           => _scheme.onSecondary;
  static Color get onSecondaryContainer  => _scheme.onSecondaryContainer;
  static Color get onSecondaryFixed      => _scheme.onSecondaryContainer;

  // ─── Tertiary ───────────────────────────────────────────
  static Color get tertiary            => _scheme.tertiary;
  static Color get tertiaryDim         => _scheme.tertiary;
  static Color get tertiaryContainer   => _scheme.tertiaryContainer;
  static Color get tertiaryFixed       => _scheme.tertiaryContainer;
  static Color get tertiaryFixedDim    => _scheme.tertiaryContainer;
  static Color get onTertiary          => _scheme.onTertiary;
  static Color get onTertiaryFixed     => _scheme.onTertiaryContainer;
  static Color get onTertiaryContainer => _scheme.onTertiaryContainer;

  // ─── Surface ────────────────────────────────────────────
  static Color get surface                 => _scheme.surface;
  static Color get surfaceContainerLow     => _scheme.surfaceContainerLow;
  static Color get surfaceContainer        => _scheme.surfaceContainer;
  static Color get surfaceContainerHigh    => _scheme.surfaceContainerHigh;
  static Color get surfaceContainerHighest => _scheme.surfaceContainerHighest;
  static Color get surfaceContainerLowest  => _scheme.surfaceContainerLowest;
  static Color get surfaceDim              => _scheme.surfaceDim;
  static Color get surfaceBright           => _scheme.surface;
  static Color get surfaceVariant          => _scheme.surfaceVariant;
  static Color get surfaceTint             => _scheme.primary;

  // ─── On-Surface ─────────────────────────────────────────
  static Color get onSurface        => _scheme.onSurface;
  static Color get onSurfaceVariant => _scheme.onSurfaceVariant;
  static Color get background       => _scheme.background;
  static Color get onBackground     => _scheme.onSurface;
  static Color get inverseSurface   => _scheme.inverseSurface;
  static Color get inverseOnSurface => _scheme.onSurfaceVariant;

  // ─── Outline ────────────────────────────────────────────
  static Color get outline        => _scheme.outline;
  static Color get outlineVariant => _scheme.outlineVariant;

  // ─── Error ──────────────────────────────────────────────
  static Color get error              => _scheme.error;
  static Color get errorDim           => _scheme.error;
  static Color get errorContainer     => _scheme.errorContainer;
  static Color get onError            => _scheme.onError;
  static Color get onErrorContainer   => _scheme.onPrimaryContainer;

  // ─── Shadow ─────────────────────────────────────────────
  static Color get ambientShadow => _scheme.ambientShadow;
  static Color get cardShadow    => _scheme.cardShadow;
  static Color get primaryGlow   => _scheme.primaryGlow;

  // ─── Gradient ───────────────────────────────────────────
  static LinearGradient get primaryGradient => _scheme.primaryGradient;
  static LinearGradient get heroGradient    => _scheme.heroGradient;

  // ─── 语义 Token（新页面优先使用，见 docs/design-tokens.md）─
  // Brand
  static Color get brandPrimary       => _scheme.brandPrimary;
  static Color get brandPrimaryStrong => _scheme.brandPrimaryStrong;
  static Color get brandPrimarySoft   => _scheme.brandPrimarySoft;

  // Status
  static Color get statusOnline       => _scheme.statusOnline;
  static Color get statusOnlineStrong => _scheme.statusOnlineStrong;
  static Color get statusOnlineSoft   => _scheme.statusOnlineSoft;
  static Color get statusAlert        => _scheme.statusAlert;
  static Color get statusAlertSoft    => _scheme.statusAlertSoft;
  static Color get statusNeutral      => _scheme.statusNeutral;

  // Text
  static Color get textPrimary   => _scheme.textPrimary;
  static Color get textSecondary => _scheme.textSecondary;
  static Color get textTertiary  => _scheme.textTertiary;
  static Color get textOnBrand   => _scheme.textOnBrand;

  // Surface
  static Color get surfacePage   => _scheme.surfacePage;
  static Color get surfaceCard   => _scheme.surfaceCard;
  static Color get surfaceSunken => _scheme.surfaceSunken;
  static Color get borderSubtle  => _scheme.borderSubtle;

  // ─── 第三方品牌色（不随主题变化，仅用于对应平台的分享入口）─
  static const Color wechat = Color(0xFF07C160);
  static const Color tencentMap = Color(0xFF07C160);
  static const Color amap = Color(0xFF1B9BE0);
  static const Color baiduMap = Color(0xFF3385FF);
  static const Color appleMaps = Color(0xFF34C759);

  // ─── 沉浸式媒体查看器底色（视频 / 大图全屏，不随主题变化）─
  static const Color mediaBackdrop = Color(0xFF0D0D1A);

  // ─── 旧固定色（已废弃，由跟随主题的语义 token 取代）───
  @Deprecated('Use AppColors.brandPrimary')
  static Color get star    => _scheme.brandPrimary;
  @Deprecated('Use AppColors.statusOnline')
  static Color get success => _scheme.statusOnline;
  @Deprecated('Use AppColors.statusOnline')
  static Color get online  => _scheme.statusOnline;
}
