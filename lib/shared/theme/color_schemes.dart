import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════
//  PetColorScheme — 全局配色数据类
//  ✅ 新增配色：在文件末尾新建 PetColorScheme 实例
// ═══════════════════════════════════════════════════

class PetColorScheme {
  final String key;
  final String name;
  final String emoji;

  // Primary
  final Color primary;
  final Color primaryDim;
  final Color primaryContainer;
  final Color primaryFixed;
  final Color primaryFixedDim;
  final Color onPrimary;
  final Color onPrimaryContainer;
  final Color inversePrimary;

  // Secondary
  final Color secondary;
  final Color secondaryContainer;
  final Color onSecondary;
  final Color onSecondaryContainer;

  // Tertiary
  final Color tertiary;
  final Color tertiaryContainer;
  final Color onTertiary;
  final Color onTertiaryContainer;

  // Surface
  final Color surface;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color surfaceContainerLowest;
  final Color surfaceDim;
  final Color surfaceVariant;

  // On-Surface
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color background;
  final Color inverseSurface;

  // Outline
  final Color outline;
  final Color outlineVariant;

  // Error
  final Color error;
  final Color errorContainer;
  final Color onError;

  // Shadow
  final Color ambientShadow;
  final Color cardShadow;
  final Color primaryGlow;

  // Gradient
  final LinearGradient primaryGradient;
  final LinearGradient heroGradient;

  const PetColorScheme({
    required this.key,
    required this.name,
    required this.emoji,
    required this.primary,
    required this.primaryDim,
    required this.primaryContainer,
    required this.primaryFixed,
    required this.primaryFixedDim,
    required this.onPrimary,
    required this.onPrimaryContainer,
    required this.inversePrimary,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondary,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.onTertiary,
    required this.onTertiaryContainer,
    required this.surface,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.surfaceContainerLowest,
    required this.surfaceDim,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.background,
    required this.inverseSurface,
    required this.outline,
    required this.outlineVariant,
    required this.error,
    required this.errorContainer,
    required this.onError,
    required this.ambientShadow,
    required this.cardShadow,
    required this.primaryGlow,
    required this.primaryGradient,
    required this.heroGradient,
  });
}

// ═══════════════════════════════════════════════════
//  暖棕粉红（原版配色）
// ═══════════════════════════════════════════════════
const warmPinkScheme = PetColorScheme(
  key: 'warm_pink',
  name: '暖棕粉红',
  emoji: '🌸',
  primary:            Color(0xFFa83206),
  primaryDim:         Color(0xFF952800),
  primaryContainer:   Color(0xFFff784e),
  primaryFixed:       Color(0xFFff784e),
  primaryFixedDim:    Color(0xFFf3683b),
  onPrimary:          Color(0xFFffefeb),
  onPrimaryContainer: Color(0xFF470e00),
  inversePrimary:     Color(0xFFfe6f42),
  secondary:          Color(0xFF006760),
  secondaryContainer: Color(0xFF7fe6db),
  onSecondary:        Color(0xFFbffff7),
  onSecondaryContainer: Color(0xFF00534d),
  tertiary:           Color(0xFF705900),
  tertiaryContainer:  Color(0xFFfdd34d),
  onTertiary:         Color(0xFFfff2d4),
  onTertiaryContainer: Color(0xFF5c4900),
  surface:            Color(0xFFfff4f3),
  surfaceContainerLow:  Color(0xFFffedeb),
  surfaceContainer:     Color(0xFFffe1df),
  surfaceContainerHigh: Color(0xFFffdad7),
  surfaceContainerHighest: Color(0xFFffd2cf),
  surfaceContainerLowest:  Color(0xFFffffff),
  surfaceDim:         Color(0xFFffc7c3),
  surfaceVariant:     Color(0xFFffd2cf),
  onSurface:          Color(0xFF4e2120),
  onSurfaceVariant:   Color(0xFF834c4a),
  background:         Color(0xFFfff4f3),
  inverseSurface:     Color(0xFF240304),
  outline:            Color(0xFFa36764),
  outlineVariant:     Color(0xFFe09c98),
  error:              Color(0xFFb31b25),
  errorContainer:     Color(0xFFfb5151),
  onError:            Color(0xFFffefee),
  ambientShadow:      Color(0x0F4e2120),
  cardShadow:         Color(0x194e2120),
  primaryGlow:        Color(0x33a83206),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFa83206), Color(0xFFff784e)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
  heroGradient: LinearGradient(
    colors: [Color(0xFFa83206), Color(0x00a83206)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
);

// ═══════════════════════════════════════════════════
//  晴空蓝白（蓝白色系）
// ═══════════════════════════════════════════════════
const blueWhiteScheme = PetColorScheme(
  key: 'blue_white',
  name: '晴空蓝白',
  emoji: '🩵',
  primary:            Color(0xFF1A6BB5),
  primaryDim:         Color(0xFF135498),
  primaryContainer:   Color(0xFF4FA3E0),
  primaryFixed:       Color(0xFF4FA3E0),
  primaryFixedDim:    Color(0xFF2E8FD6),
  onPrimary:          Color(0xFFE8F4FF),
  onPrimaryContainer: Color(0xFF052A5A),
  inversePrimary:     Color(0xFF5BADEC),
  secondary:          Color(0xFF0077B6),
  secondaryContainer: Color(0xFF90E0EF),
  onSecondary:        Color(0xFFCDF3FF),
  onSecondaryContainer: Color(0xFF005A8E),
  tertiary:           Color(0xFF006494),
  tertiaryContainer:  Color(0xFF48CAE4),
  onTertiary:         Color(0xFFD0F4FF),
  onTertiaryContainer: Color(0xFF003F5C),
  surface:            Color(0xFFF2F8FF),
  surfaceContainerLow:  Color(0xFFE8F2FF),
  surfaceContainer:     Color(0xFFDAEBFF),
  surfaceContainerHigh: Color(0xFFCCE4FF),
  surfaceContainerHighest: Color(0xFFBDD9FF),
  surfaceContainerLowest:  Color(0xFFFFFFFF),
  surfaceDim:         Color(0xFFB8D4F0),
  surfaceVariant:     Color(0xFFCEE4FF),
  onSurface:          Color(0xFF102040),
  onSurfaceVariant:   Color(0xFF3D6080),
  background:         Color(0xFFF2F8FF),
  inverseSurface:     Color(0xFF051525),
  outline:            Color(0xFF5C8AAA),
  outlineVariant:     Color(0xFFAACDE8),
  error:              Color(0xFFb31b25),
  errorContainer:     Color(0xFFfb5151),
  onError:            Color(0xFFffefee),
  ambientShadow:      Color(0x0F102040),
  cardShadow:         Color(0x19102040),
  primaryGlow:        Color(0x331A6BB5),
  primaryGradient: LinearGradient(
    colors: [Color(0xFF1A6BB5), Color(0xFF4FA3E0)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
  heroGradient: LinearGradient(
    colors: [Color(0xFF1A6BB5), Color(0x001A6BB5)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
);

/// 所有可选配色方案列表（只保留2套：原版 + 用户自定义5色）
const kColorSchemes = [warmPinkScheme, forestDuskScheme, nebulaVioletScheme];

// ═══════════════════════════════════════════════════
//  星云紫蓝（用户提供5色蓝紫渐变）
//
//  #4154CF → 深靛蓝   primary
//  #6871F1 → 中靛紫   primaryContainer
//  #8C8FFF → 柔蓝紫   secondary
//  #AFAEFF → 淡薰衣草  secondaryContainer / outlineVariant
//  #D2CEFF → 极浅薰衣草 surface 来源
// ═══════════════════════════════════════════════════
const nebulaVioletScheme = PetColorScheme(
  key: 'nebula_violet',
  name: '星云紫蓝',
  emoji: '💜',

  // ── Primary — 深靛蓝 #4154CF ──────────────────
  primary:            Color(0xFF4154CF),
  primaryDim:         Color(0xFF3346B8),
  primaryContainer:   Color(0xFF6871F1),
  primaryFixed:       Color(0xFF6871F1),
  primaryFixedDim:    Color(0xFF5562E3),
  onPrimary:          Color(0xFFEEEFFF),
  onPrimaryContainer: Color(0xFF0E1660),
  inversePrimary:     Color(0xFF8C8FFF),

  // ── Secondary — 柔蓝紫 #8C8FFF ───────────────
  secondary:          Color(0xFF8C8FFF),
  secondaryContainer: Color(0xFFAFAEFF),
  onSecondary:        Color(0xFFF5F4FF),
  onSecondaryContainer: Color(0xFF22206A),

  // ── Tertiary — 由 #6871F1 派生 ───────────────
  tertiary:           Color(0xFF5060B8),
  tertiaryContainer:  Color(0xFFD2CEFF),
  onTertiary:         Color(0xFFF0EEFF),
  onTertiaryContainer: Color(0xFF1A1860),

  // ── Surface — 基于 #D2CEFF 白化 ─────────────
  surface:            Color(0xFFF5F4FF),
  surfaceContainerLow:  Color(0xFFECEBFF),
  surfaceContainer:     Color(0xFFE2E0FF),
  surfaceContainerHigh: Color(0xFFD8D6FF),
  surfaceContainerHighest: Color(0xFFD2CEFF),
  surfaceContainerLowest:  Color(0xFFFFFFFF),
  surfaceDim:         Color(0xFFC8C5F5),
  surfaceVariant:     Color(0xFFDDDBFF),

  // ── On-Surface — 深靛文字 ─────────────────────
  onSurface:          Color(0xFF1E1C5C),
  onSurfaceVariant:   Color(0xFF4A4A80),
  background:         Color(0xFFF5F4FF),
  inverseSurface:     Color(0xFF0A0830),

  // ── Outline ─────────────────────────────────
  outline:            Color(0xFF8C8FFF),
  outlineVariant:     Color(0xFFCFCEFF),

  // ── Error ────────────────────────────────────
  error:              Color(0xFFb31b25),
  errorContainer:     Color(0xFFfb5151),
  onError:            Color(0xFFffefee),

  // ── Shadow ───────────────────────────────────
  ambientShadow:      Color(0x0F1E1C5C),
  cardShadow:         Color(0x194154CF),
  primaryGlow:        Color(0x334154CF),

  // ── Gradient: 深靛 → 柔蓝紫 ──────────────────
  primaryGradient: LinearGradient(
    colors: [Color(0xFF4154CF), Color(0xFF8C8FFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
  heroGradient: LinearGradient(
    colors: [Color(0xFF4154CF), Color(0x004154CF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
);

// ═══════════════════════════════════════════════════
//  暮色森林（用户自定义5色）
//
//  #C03221 → 深红主色 (primary)
//  #3F826D → 墨绿副色 (secondary)
//  #F2D0A4 → 杏色暖调 (tertiaryContainer / accent)
//  #F7F7FF → 月白底色 (surface)
//  #545E75 → 蓝灰文字 (onSurface)
// ═══════════════════════════════════════════════════
const forestDuskScheme = PetColorScheme(
  key: 'forest_dusk',
  name: '暮色森林',
  emoji: '🌲',

  // ── Primary — 深红 #C03221 ──────────────────────
  primary:            Color(0xFFC03221),
  primaryDim:         Color(0xFFA82A1C),
  primaryContainer:   Color(0xFFE05540),
  primaryFixed:       Color(0xFFE05540),
  primaryFixedDim:    Color(0xFFD04030),
  onPrimary:          Color(0xFFFFF0EE),
  onPrimaryContainer: Color(0xFF3E0A07),
  inversePrimary:     Color(0xFFE8705F),

  // ── Secondary — 墨绿 #3F826D ───────────────────
  secondary:          Color(0xFF3F826D),
  secondaryContainer: Color(0xFFA8D4C6),
  onSecondary:        Color(0xFFE8F5F1),
  onSecondaryContainer: Color(0xFF1A4035),

  // ── Tertiary — 杏色 #F2D0A4 ───────────────────
  tertiary:           Color(0xFF8B6030),
  tertiaryContainer:  Color(0xFFF2D0A4),
  onTertiary:         Color(0xFFFAF0E6),
  onTertiaryContainer: Color(0xFF5A3A12),

  // ── Surface — 月白 #F7F7FF ─────────────────────
  surface:            Color(0xFFF7F7FF),
  surfaceContainerLow:  Color(0xFFEFEFF9),
  surfaceContainer:     Color(0xFFE6E6F2),
  surfaceContainerHigh: Color(0xFFDDDDEC),
  surfaceContainerHighest: Color(0xFFD4D4E4),
  surfaceContainerLowest:  Color(0xFFFFFFFF),
  surfaceDim:         Color(0xFFCACADB),
  surfaceVariant:     Color(0xFFE0E0EE),

  // ── On-Surface — 蓝灰 #545E75 ─────────────────
  onSurface:          Color(0xFF545E75),
  onSurfaceVariant:   Color(0xFF7A849A),
  background:         Color(0xFFF7F7FF),
  inverseSurface:     Color(0xFF1C2030),

  // ── Outline ────────────────────────────────────
  outline:            Color(0xFF8890A6),
  outlineVariant:     Color(0xFFBFC5D2),

  // ── Error ──────────────────────────────────────
  error:              Color(0xFFb31b25),
  errorContainer:     Color(0xFFfb5151),
  onError:            Color(0xFFffefee),

  // ── Shadow ─────────────────────────────────────
  ambientShadow:      Color(0x0F545E75),
  cardShadow:         Color(0x19545E75),
  primaryGlow:        Color(0x33C03221),

  // ── Gradient: 深红 → 杏色 ─────────────────────
  primaryGradient: LinearGradient(
    colors: [Color(0xFFC03221), Color(0xFFF2D0A4)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
  heroGradient: LinearGradient(
    colors: [Color(0xFFC03221), Color(0x00C03221)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
);
