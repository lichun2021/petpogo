import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/color_schemes.dart';

const kThemeKey = 'app_color_scheme';

/// 配色方案 Provider
/// 初始值由 main.dart 在启动时同步读取后通过 override 注入，不再异步加载
final colorSchemeProvider =
    StateNotifierProvider<ColorSchemeNotifier, String>((ref) {
  return ColorSchemeNotifier(warmPinkScheme.key);
});

class ColorSchemeNotifier extends StateNotifier<String> {
  ColorSchemeNotifier(String initialKey) : super(initialKey);

  Future<void> setScheme(String key) async {
    final scheme = kColorSchemes.firstWhere(
      (s) => s.key == key,
      orElse: () => warmPinkScheme,
    );
    AppColors.setScheme(scheme);
    state = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kThemeKey, key);
  }

  PetColorScheme get currentScheme => kColorSchemes.firstWhere(
      (s) => s.key == state,
      orElse: () => warmPinkScheme);
}
