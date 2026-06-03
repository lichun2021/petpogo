/// ═══════════════════════════════════════════════════
///  全局字体配置 — AppFonts
///
///  ✅ 切换中文字体：只需修改 [primary] 一行
///  ✅ 调整全局字号：只需修改 [scale] 一行
///  ✅ 无需触碰其他任何文件，重新打包即可生效
///
///  已打包的字体（assets/fonts/）：
///    AZhuBubble   — 阿朱泡泡体（可爱卡通泡泡风，~3.3MB）⭐ 当前
/// ═══════════════════════════════════════════════════

abstract class AppFonts {
  /// 中文主字体 ← ✏️ 换字体只改这一行
  ///
  /// 可选值：
  ///   'AZhuBubble' — 阿朱泡泡体（已打包，卡通可爱）⭐

  static const String primary = 'Plus Jakarta Sans'; // 系统兜底 iOS→苹方 Android→Noto CJK

  /// 英文辅助字体（Plus Jakarta Sans，作为非中文字符的回退）
  static const String latin = 'Plus Jakarta Sans';

  /// 全局字体缩放系数 ← ✏️ 调整字号只改这一行（1.0 = 不缩放）
  ///
  /// 阿朱泡泡体视觉偏小，放大 1.2 倍使其更清晰易读
  static const double scale = 1.1;

  /// fontFamilyFallback 列表（直接用于 TextStyle）
  static const List<String> fallback = [primary];
}
