import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════
///  布局 Token — 间距 / 尺寸 / 圆角 / 图标
///
///  不随配色方案变化，故为 const。色值见 [AppColors]。
///  完整规范：docs/design-tokens.md
///  规则：新页面只能用这里的值，禁止随意的边距 / 圆角。
/// ═══════════════════════════════════════════════════

/// 4dp 栅格间距
abstract final class AppSpacing {
  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x20 = 20;
  static const double x24 = 24;
  static const double x32 = 32;
  static const double x40 = 40;
  static const double x48 = 48;

  /// 页面左右边距
  static const double screenHorizontal = 20;

  /// 区块之间
  static const double sectionGap = 24;

  /// 卡片 / 行内模块之间
  static const double contentGap = 12;

  /// 图标与文字
  static const double iconGap = 8;

  static const EdgeInsets screen =
      EdgeInsets.symmetric(horizontal: screenHorizontal);
}

/// 固定尺寸
abstract final class AppSize {
  /// 所有可点击目标最小尺寸
  static const double touchMin = 44;

  /// 健康报表：环图、柱状绘图区与单列宽度。
  static const double healthRing = 160;
  static const double healthLegendWidth = 144;
  static const double healthPlotHeight = 112;
  static const double healthColumnWidth = 64;
  static const double healthTimelineHeight = 176;
  static const double healthAxisWidth = 28;
  static const double healthCompactRing = 104;

  /// 底栏高度（不含安全区）
  static const double tabBarHeight = 64;
}

/// 圆角
abstract final class AppRadius {
  /// 常规信息卡
  static const double card = 18;

  /// 按钮、输入框
  static const double control = 12;

  /// 标签、小状态、胶囊按钮
  static const double pill = 999;

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius controlRadius =
      BorderRadius.all(Radius.circular(control));
  static const BorderRadius pillRadius =
      BorderRadius.all(Radius.circular(pill));
}

/// 图标尺寸
abstract final class AppIconSize {
  /// 底栏
  static const double tabBar = 19;

  /// 顶部栏（规范 15–17，取 16）
  static const double topBar = 16;

  /// 卡片内
  static const double card = 16;
}

/// 图标线宽（Material Icons 不可调线宽，此处仅作规范记录，
/// 供未来自绘 / SVG 图标集使用）
abstract final class AppIconStroke {
  static const double regular = 1.7;
  static const double alert = 1.9;
  static const double smallNode = 2.0;
}
