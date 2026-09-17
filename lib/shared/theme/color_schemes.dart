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

  // ── 语义 Token（见 docs/design-tokens.md）─────────────
  // Brand：全 App 唯一品牌色 / 主操作 / 底栏激活
  final Color brandPrimary;
  final Color brandPrimaryStrong;
  final Color brandPrimarySoft;

  // Status：每种语义一个值，且必须配文字或图标
  final Color statusOnline;
  final Color statusOnlineStrong;
  final Color statusOnlineSoft;
  final Color statusAlert;
  final Color statusAlertSoft;
  final Color statusWarning;
  final Color statusWarningSoft;
  final Color statusNeutral;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnBrand;

  // Surface
  final Color surfacePage;
  final Color surfaceCard;
  final Color surfaceSunken;
  final Color borderSubtle;

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
    required this.brandPrimary,
    required this.brandPrimaryStrong,
    required this.brandPrimarySoft,
    required this.statusOnline,
    required this.statusOnlineStrong,
    required this.statusOnlineSoft,
    required this.statusAlert,
    required this.statusAlertSoft,
    required this.statusWarning,
    required this.statusWarningSoft,
    required this.statusNeutral,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnBrand,
    required this.surfacePage,
    required this.surfaceCard,
    required this.surfaceSunken,
    required this.borderSubtle,
  });
}

// ═══════════════════════════════════════════════════
//  暖棕粉红（主线主题，唯一维护的配色）
//  色值以 docs/design-tokens.md 为准；Material 角色按语义重映射：
//    primary → brand, secondary → status-online, tertiary → status-neutral,
//    error → status-alert, surface* → surface-page/card/sunken
// ═══════════════════════════════════════════════════
const warmPinkScheme = PetColorScheme(
  key: 'warm_pink',
  name: '暖棕粉红',
  emoji: '',
  primary: Color(0xFFC0564B),
  primaryDim: Color(0xFF9E3F36),
  primaryContainer: Color(0xFFF4DAD3),
  primaryFixed: Color(0xFFF4DAD3),
  primaryFixedDim: Color(0xFFE9C3BA),
  onPrimary: Color(0xFFFFFFFF),
  onPrimaryContainer: Color(0xFF9E3F36),
  inversePrimary: Color(0xFFD98A80),
  secondary: Color(0xFF6F9B6A),
  secondaryContainer: Color(0xFFE4EEE2),
  onSecondary: Color(0xFFFFFFFF),
  onSecondaryContainer: Color(0xFF4E7350),
  tertiary: Color(0xFF8A7B6E),
  tertiaryContainer: Color(0xFFF1EAE0),
  onTertiary: Color(0xFFFFFFFF),
  onTertiaryContainer: Color(0xFF3A2E2A),
  surface: Color(0xFFF7F3EE),
  surfaceContainerLow: Color(0xFFFFFDFB),
  surfaceContainer: Color(0xFFF1EAE0),
  surfaceContainerHigh: Color(0xFFEAE1D5),
  surfaceContainerHighest: Color(0xFFE4D9CC),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceDim: Color(0xFFE4D9CC),
  surfaceVariant: Color(0xFFF1EAE0),
  onSurface: Color(0xFF3A2E2A),
  onSurfaceVariant: Color(0xFF7A6A60),
  background: Color(0xFFF7F3EE),
  inverseSurface: Color(0xFF3A2E2A),
  outline: Color(0xFFA79A8D),
  outlineVariant: Color(0xFFE4D9CC),
  error: Color(0xFFC2410C),
  errorContainer: Color(0xFFFBE3D8),
  onError: Color(0xFFFFFFFF),
  ambientShadow: Color(0x0F3A2E2A),
  cardShadow: Color(0x193A2E2A),
  primaryGlow: Color(0x33C0564B),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFC0564B), Color(0xFF9E3F36)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
  heroGradient: LinearGradient(
    colors: [Color(0xFFC0564B), Color(0x00C0564B)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
  brandPrimary: Color(0xFFC0564B),
  brandPrimaryStrong: Color(0xFF9E3F36),
  brandPrimarySoft: Color(0xFFF4DAD3),
  statusOnline: Color(0xFF6F9B6A),
  statusOnlineStrong: Color(0xFF4E7350),
  statusOnlineSoft: Color(0xFFE4EEE2),
  statusAlert: Color(0xFFC2410C),
  statusAlertSoft: Color(0xFFFBE3D8),
  statusWarning: Color(0xFFC98A2E),
  statusWarningSoft: Color(0xFFF5E6C8),
  statusNeutral: Color(0xFF8A7B6E),
  textPrimary: Color(0xFF3A2E2A),
  textSecondary: Color(0xFF7A6A60),
  textTertiary: Color(0xFFA79A8D),
  textOnBrand: Color(0xFFFFFFFF),
  surfacePage: Color(0xFFF7F3EE),
  surfaceCard: Color(0xFFFFFFFF),
  surfaceSunken: Color(0xFFF1EAE0),
  borderSubtle: Color(0xFFE4D9CC),
);

// ═══════════════════════════════════════════════════
//  晴空蓝白（蓝白色系）
// ═══════════════════════════════════════════════════
const blueWhiteScheme = PetColorScheme(
  key: 'blue_white',
  name: '晴空蓝白',
  emoji: '',
  primary: Color(0xFF1A6BB5),
  primaryDim: Color(0xFF135498),
  primaryContainer: Color(0xFF4FA3E0),
  primaryFixed: Color(0xFF4FA3E0),
  primaryFixedDim: Color(0xFF2E8FD6),
  onPrimary: Color(0xFFE8F4FF),
  onPrimaryContainer: Color(0xFF052A5A),
  inversePrimary: Color(0xFF5BADEC),
  secondary: Color(0xFF0077B6),
  secondaryContainer: Color(0xFF90E0EF),
  onSecondary: Color(0xFFCDF3FF),
  onSecondaryContainer: Color(0xFF005A8E),
  tertiary: Color(0xFF006494),
  tertiaryContainer: Color(0xFF48CAE4),
  onTertiary: Color(0xFFD0F4FF),
  onTertiaryContainer: Color(0xFF003F5C),
  surface: Color(0xFFF2F8FF),
  surfaceContainerLow: Color(0xFFE8F2FF),
  surfaceContainer: Color(0xFFDAEBFF),
  surfaceContainerHigh: Color(0xFFCCE4FF),
  surfaceContainerHighest: Color(0xFFBDD9FF),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceDim: Color(0xFFB8D4F0),
  surfaceVariant: Color(0xFFCEE4FF),
  onSurface: Color(0xFF102040),
  onSurfaceVariant: Color(0xFF3D6080),
  background: Color(0xFFF2F8FF),
  inverseSurface: Color(0xFF051525),
  outline: Color(0xFF5C8AAA),
  outlineVariant: Color(0xFFAACDE8),
  error: Color(0xFFb31b25),
  errorContainer: Color(0xFFfb5151),
  onError: Color(0xFFffefee),
  ambientShadow: Color(0x0F102040),
  cardShadow: Color(0x19102040),
  primaryGlow: Color(0x331A6BB5),
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
  brandPrimary: Color(0xFF1A6BB5),
  brandPrimaryStrong: Color(0xFF135498),
  brandPrimarySoft: Color(0xFFDAEBFF),
  statusOnline: Color(0xFF3F826D),
  statusOnlineStrong: Color(0xFF2F6653),
  statusOnlineSoft: Color(0xFFDDEFE8),
  statusAlert: Color(0xFFb31b25),
  statusAlertSoft: Color(0xFFFADADA),
  statusWarning: Color(0xFFC98A2E),
  statusWarningSoft: Color(0xFFF5E6C8),
  statusNeutral: Color(0xFF5C8AAA),
  textPrimary: Color(0xFF102040),
  textSecondary: Color(0xFF3D6080),
  textTertiary: Color(0xFF7A9AB8),
  textOnBrand: Color(0xFFFFFFFF),
  surfacePage: Color(0xFFF2F8FF),
  surfaceCard: Color(0xFFFFFFFF),
  surfaceSunken: Color(0xFFE8F2FF),
  borderSubtle: Color(0xFFCCE4FF),
);

/// 所有可选配色方案列表（只保留2套：原版 + 用户自定义5色）
const kColorSchemes = [warmPinkScheme, forestDuskScheme, blueWhiteScheme];

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
  emoji: '',

  // ── Primary — 深靖蓝 #4154CF ──────────────
  primary: Color(0xFF4154CF),
  primaryDim: Color(0xFF3346B8),
  primaryContainer: Color(0xFF6871F1),
  primaryFixed: Color(0xFF6871F1),
  primaryFixedDim: Color(0xFF5562E3),
  onPrimary: Color(0xFFFFFFFF), // 白字在深蓝上最清晰
  onPrimaryContainer: Color(0xFF0A1250),
  inversePrimary: Color(0xFF8C8FFF),

  // ── Secondary — 柔蓝紫 #8C8FFF ────────────
  secondary: Color(0xFF8C8FFF),
  secondaryContainer: Color(0xFFD2CEFF), // 直接用用户第5色
  onSecondary: Color(0xFF1A1860),
  onSecondaryContainer: Color(0xFF1A1860),

  // ── Tertiary —导测温暂色 ──────────────
  tertiary: Color(0xFF6060C0),
  tertiaryContainer: Color(0xFFE0DEFF),
  onTertiary: Color(0xFFFFFFFF),
  onTertiaryContainer: Color(0xFF1A1860),

  // ── Surface — 纯白底色+薄醜衣草渐进 ────────
  // 卡片背景白中带淡紫，层次渐深，避免灰芒
  surface: Color(0xFFF8F7FF), // 贴近白的淡屐紫
  surfaceContainerLow: Color(0xFFF0EEFF), // 很淡的屐紫
  surfaceContainer: Color(0xFFE5E2FF), // 中等屐紫（卡片背景）
  surfaceContainerHigh: Color(0xFFD8D4FF), // 较深屐紫（选中卡片）
  surfaceContainerHighest: Color(0xFFCDCAFF), // 用户第4色 #AFAEFF 居中
  surfaceContainerLowest: Color(0xFFFFFFFF), // 纯白底层
  surfaceDim: Color(0xFFC0BCEE),
  surfaceVariant: Color(0xFFE0DEFF),

  // ── On-Surface — 深靖文字 ──────────────
  // 深陗蓝字，相比原方案更深、更清晰
  onSurface: Color(0xFF13104A), // 极深饗蓝，在浅屐紫背景上极清晰
  onSurfaceVariant: Color(0xFF4050A0), // 中深蓝紫副标题文字
  background: Color(0xFFF8F7FF),
  inverseSurface: Color(0xFF08062E),

  // ── Outline ──────────────────────────
  outline: Color(0xFF7070C8),
  outlineVariant: Color(0xFFBDB8F0),

  // ── Error ─────────────────────────────
  error: Color(0xFFb31b25),
  errorContainer: Color(0xFFfb5151),
  onError: Color(0xFFffefee),

  // ── Shadow ────────────────────────────
  ambientShadow: Color(0x0F4154CF),
  cardShadow: Color(0x204154CF),
  primaryGlow: Color(0x404154CF),

  // ── Gradient: 深遗 → 薄屐紫 ─────────────
  primaryGradient: LinearGradient(
    colors: [Color(0xFF4154CF), Color(0xFF6871F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  heroGradient: LinearGradient(
    colors: [Color(0xFF4154CF), Color(0x004154CF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
  brandPrimary: Color(0xFF4154CF),
  brandPrimaryStrong: Color(0xFF3346B8),
  brandPrimarySoft: Color(0xFFE5E2FF),
  statusOnline: Color(0xFF3F826D),
  statusOnlineStrong: Color(0xFF2F6653),
  statusOnlineSoft: Color(0xFFDDEFE8),
  statusAlert: Color(0xFFb31b25),
  statusAlertSoft: Color(0xFFFADADA),
  statusWarning: Color(0xFFC98A2E),
  statusWarningSoft: Color(0xFFF5E6C8),
  statusNeutral: Color(0xFF7070C8),
  textPrimary: Color(0xFF13104A),
  textSecondary: Color(0xFF4050A0),
  textTertiary: Color(0xFF8A8CC8),
  textOnBrand: Color(0xFFFFFFFF),
  surfacePage: Color(0xFFF8F7FF),
  surfaceCard: Color(0xFFFFFFFF),
  surfaceSunken: Color(0xFFF0EEFF),
  borderSubtle: Color(0xFFD8D4FF),
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
  emoji: '',

  // ── Primary — 深红 #C03221 ──────────────
  primary: Color(0xFFC03221),
  primaryDim: Color(0xFFA82A1C),
  primaryContainer: Color(0xFFE05540),
  primaryFixed: Color(0xFFE05540),
  primaryFixedDim: Color(0xFFD04030),
  onPrimary: Color(0xFFFFFFFF), // 白字在深红上最清晰
  onPrimaryContainer: Color(0xFF3E0A07),
  inversePrimary: Color(0xFFE8705F),

  // ── Secondary — 墨绿 #3F826D ───────────
  secondary: Color(0xFF3F826D),
  secondaryContainer: Color(0xFFB6DDD4), // 浅薄荷叶绿
  onSecondary: Color(0xFFFFFFFF),
  onSecondaryContainer: Color(0xFF1A4035),

  // ── Tertiary — 杏色 #F2D0A4 ───────────
  tertiary: Color(0xFF8B6030),
  tertiaryContainer: Color(0xFFF2D0A4),
  onTertiary: Color(0xFFFFFFFF),
  onTertiaryContainer: Color(0xFF5A3A12),

  // ── Surface — 温暖象牙色系列 ─────────
  // 主色是红+绿，surface必须是暖象牙，绝对不能带蓝调
  surface: Color(0xFFFAF8F4), // 暖白象牙
  surfaceContainerLow: Color(0xFFF4F0E8), // 麦秆象牙
  surfaceContainer: Color(0xFFEDE7D9), // 卡片背景，温暖鹿皮色
  surfaceContainerHigh: Color(0xFFE4DCC8), // 较深温暖色
  surfaceContainerHighest: Color(0xFFD8D0B8), // 最深的温暖层
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceDim: Color(0xFFCCC4AA),
  surfaceVariant: Color(0xFFEBE3D2),

  // ── On-Surface — 蓝灰 #545E75 ──────────
  // 在象牙色背景上，深蓝灰文字极具层次感
  onSurface: Color(0xFF3A4055), // 比用户的545E75稍深，更高对比
  onSurfaceVariant: Color(0xFF627090), // 副标题文字
  background: Color(0xFFFAF8F4),
  inverseSurface: Color(0xFF1A1C28),

  // ── Outline ──────────────────────────
  outline: Color(0xFF909AAA),
  outlineVariant: Color(0xFFD0C8B8), // 暖象牙色分割线

  // ── Error ─────────────────────────────
  error: Color(0xFFb31b25),
  errorContainer: Color(0xFFfb5151),
  onError: Color(0xFFffefee),

  // ── Shadow ────────────────────────────
  ambientShadow: Color(0x0F3A4055),
  cardShadow: Color(0x15C03221), // 深红阴影
  primaryGlow: Color(0x30C03221),

  // ── Gradient: 深红 → 杏色 ──────────────
  primaryGradient: LinearGradient(
    colors: [Color(0xFFC03221), Color(0xFFE07C50)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  heroGradient: LinearGradient(
    colors: [Color(0xFFC03221), Color(0x00C03221)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
  brandPrimary: Color(0xFFC03221),
  brandPrimaryStrong: Color(0xFFA82A1C),
  brandPrimarySoft: Color(0xFFF5D9D4),
  statusOnline: Color(0xFF3F826D),
  statusOnlineStrong: Color(0xFF2F6653),
  statusOnlineSoft: Color(0xFFB6DDD4),
  statusAlert: Color(0xFFb31b25),
  statusAlertSoft: Color(0xFFFADADA),
  statusWarning: Color(0xFFC98A2E),
  statusWarningSoft: Color(0xFFF5E6C8),
  statusNeutral: Color(0xFF909AAA),
  textPrimary: Color(0xFF3A4055),
  textSecondary: Color(0xFF627090),
  textTertiary: Color(0xFF909AAA),
  textOnBrand: Color(0xFFFFFFFF),
  surfacePage: Color(0xFFFAF8F4),
  surfaceCard: Color(0xFFFFFFFF),
  surfaceSunken: Color(0xFFF4F0E8),
  borderSubtle: Color(0xFFD0C8B8),
);
