import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/color_schemes.dart';

const _kThemeKey = 'app_color_scheme';
const _storage = FlutterSecureStorage();

/// 配色方案 Provider — 持久化存储，全局响应
final colorSchemeProvider =
    StateNotifierProvider<ColorSchemeNotifier, String>((ref) {
  return ColorSchemeNotifier();
});

class ColorSchemeNotifier extends StateNotifier<String> {
  ColorSchemeNotifier() : super(warmPinkScheme.key) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _storage.read(key: _kThemeKey);
    if (saved != null) {
      final scheme = kColorSchemes.firstWhere(
        (s) => s.key == saved,
        orElse: () => warmPinkScheme,
      );
      AppColors.setScheme(scheme);
      if (saved != state) state = saved;
    }
  }

  Future<void> setScheme(String key) async {
    final scheme = kColorSchemes.firstWhere(
      (s) => s.key == key,
      orElse: () => warmPinkScheme,
    );
    AppColors.setScheme(scheme);
    state = key;
    await _storage.write(key: _kThemeKey, value: key);
  }

  PetColorScheme get currentScheme =>
      kColorSchemes.firstWhere((s) => s.key == state,
          orElse: () => warmPinkScheme);
}
