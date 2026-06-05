import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/theme/app_fonts.dart';

const kFontKey = 'app_font';

/// 可选字体列表（name = 显示名称，family = 字体 family 名）
class AppFontOption {
  final String name;
  final String description;
  final String family;
  final String preview;
  const AppFontOption({
    required this.name,
    required this.description,
    required this.family,
    this.preview = '宠物你好',
  });
}

const kFontOptions = [
  AppFontOption(
    name: '系统默认',
    description: 'iOS 苹方 · Android Noto CJK',
    family: 'Plus Jakarta Sans',
  ),
  AppFontOption(
    name: '阿朱泡泡体',
    description: '可爱卡通 · 泡泡圆润风格',
    family: 'AZhuBubble',
  ),
];

/// 字体 Provider
/// 初始值由 main.dart 在启动时同步读取后通过 override 注入，不再异步加载
final fontFamilyProvider =
    StateNotifierProvider<FontFamilyNotifier, String>((ref) {
  return FontFamilyNotifier(AppFonts.primary);
});

class FontFamilyNotifier extends StateNotifier<String> {
  FontFamilyNotifier(String initialFamily) : super(initialFamily);

  Future<void> setFont(String family) async {
    AppFonts.primary = family;
    state = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kFontKey, family);
  }

  bool isSelected(String family) => state == family;
}
