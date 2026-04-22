import 'package:flutter/material.dart';

/// PetPogo "The Curated Companion" 品牌色彩系统
/// 设计规范参见 PROJECT_REFERENCE.md §15 / design/Image 9.markdown
///
/// 色调架构：Warm-Cool Tension
///   — 主色橙棕 (primary) × 副色青绿 (secondary)
///   — Surface 从暖白到粉红的色调层次，全程无边框分割
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════
  // Primary — 棕红品牌色
  // ═══════════════════════════════════════════════════════
  static const Color primary            = Color(0xFFa83206); // 主按钮、Logo、强调
  static const Color primaryDim         = Color(0xFF952800); // Hover 状态
  static const Color primaryContainer   = Color(0xFFff784e); // 渐变终点 / 容器
  static const Color primaryFixed       = Color(0xFFff784e);
  static const Color primaryFixedDim    = Color(0xFFf3683b);
  static const Color onPrimary          = Color(0xFFffefeb); // 主色上的文字
  static const Color onPrimaryContainer = Color(0xFF470e00);
  static const Color onPrimaryFixed     = Color(0xFF000000);
  static const Color inversePrimary     = Color(0xFFfe6f42);

  // ═══════════════════════════════════════════════════════
  // Secondary — 青绿副色（信任 / 支撑）
  // ═══════════════════════════════════════════════════════
  static const Color secondary              = Color(0xFF006760); // 输入框焦点线 / 支撑操作
  static const Color secondaryDim          = Color(0xFF005a54);
  static const Color secondaryContainer    = Color(0xFF7fe6db); // 次要按钮背景
  static const Color secondaryFixed        = Color(0xFF7fe6db); // 正向 Badge
  static const Color secondaryFixedDim     = Color(0xFF71d7cd);
  static const Color onSecondary           = Color(0xFFbffff7);
  static const Color onSecondaryContainer  = Color(0xFF00534d);
  static const Color onSecondaryFixed      = Color(0xFF003e39);

  // ═══════════════════════════════════════════════════════
  // Tertiary — 金黄（星级 / 标签）
  // ═══════════════════════════════════════════════════════
  static const Color tertiary           = Color(0xFF705900);
  static const Color tertiaryDim        = Color(0xFF624d00);
  static const Color tertiaryContainer  = Color(0xFFfdd34d);
  static const Color tertiaryFixed      = Color(0xFFfdd34d);
  static const Color tertiaryFixedDim   = Color(0xFFeec540);
  static const Color onTertiary         = Color(0xFFfff2d4);
  static const Color onTertiaryFixed    = Color(0xFF463600);
  static const Color onTertiaryContainer= Color(0xFF5c4900);

  // ═══════════════════════════════════════════════════════
  // Surface 层次系统（无边框，靠色调深度分层）
  // ═══════════════════════════════════════════════════════
  /// 最底层画布
  static const Color surface              = Color(0xFFfff4f3);
  /// 大块结构分组背景
  static const Color surfaceContainerLow  = Color(0xFFffedeb);
  /// 输入框背景
  static const Color surfaceContainer     = Color(0xFFffe1df);
  /// 中等容器
  static const Color surfaceContainerHigh = Color(0xFFffdad7);
  /// 最顶层浮动卡片
  static const Color surfaceContainerHighest = Color(0xFFffd2cf);
  /// 用于卡片内最亮的嵌套
  static const Color surfaceContainerLowest  = Color(0xFFffffff);
  static const Color surfaceDim           = Color(0xFFffc7c3);
  static const Color surfaceBright        = Color(0xFFfff4f3);
  static const Color surfaceVariant       = Color(0xFFffd2cf);
  static const Color surfaceTint          = Color(0xFFa83206);

  // ═══════════════════════════════════════════════════════
  // On-Surface 文字色（禁止使用纯黑 #000）
  // ═══════════════════════════════════════════════════════
  /// 所有正文文字
  static const Color onSurface        = Color(0xFF4e2120);
  /// 次要文字 / 副标题
  static const Color onSurfaceVariant = Color(0xFF834c4a);
  static const Color background       = Color(0xFFfff4f3);
  static const Color onBackground     = Color(0xFF4e2120);
  static const Color inverseSurface   = Color(0xFF240304);
  static const Color inverseOnSurface = Color(0xFFce8c88);

  // ═══════════════════════════════════════════════════════
  // Outline（Ghost Border，仅在必须时 15% 透明度使用）
  // ═══════════════════════════════════════════════════════
  static const Color outline        = Color(0xFFa36764);
  static const Color outlineVariant = Color(0xFFe09c98); // 用时加 0.15 透明

  // ═══════════════════════════════════════════════════════
  // Error / 状态
  // ═══════════════════════════════════════════════════════
  static const Color error          = Color(0xFFb31b25);
  static const Color errorDim       = Color(0xFF9f0519);
  static const Color errorContainer = Color(0xFFfb5151); // 警告 Badge
  static const Color onError        = Color(0xFFffefee);
  static const Color onErrorContainer = Color(0xFF570008);

  // ═══════════════════════════════════════════════════════
  // 品牌阴影（带棕红色调，禁止使用灰色阴影）
  // ═══════════════════════════════════════════════════════
  /// 环境阴影：on-surface @6% — 用于 FAB / Modal
  static const Color ambientShadow  = Color(0x0F4e2120); // 6% opacity
  /// 卡片阴影：on-surface @10%
  static const Color cardShadow     = Color(0x194e2120); // 10% opacity
  /// 主色光晕：primary @20%
  static const Color primaryGlow    = Color(0x33a83206); // 20% opacity

  // ═══════════════════════════════════════════════════════
  // 渐变（Hero CTA 用：primary → primaryContainer）
  // ═══════════════════════════════════════════════════════
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFa83206), Color(0xFFff784e)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFFa83206), Color(0x00a83206)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ═══════════════════════════════════════════════════════
  // 便捷别名（向下兼容旧代码）
  // ═══════════════════════════════════════════════════════
  static const Color star       = Color(0xFFfdd34d); // 评分星
  static const Color success    = Color(0xFF4CAF50); // 成功绿
  static const Color online     = Color(0xFF4CAF50); // 在线状态点
}
