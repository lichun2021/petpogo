import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../shared/theme/app_fonts.dart';

const _kFontKey = 'app_font';
const _storage = FlutterSecureStorage();

/// 可选字体列表（name = 显示名称，family = 字体 family 名）
class AppFontOption {
  final String name;
  final String description;
  final String family;
  final String preview; // 预览用的中文字
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

/// 字体 Provider — 持久化存储，全局响应
final fontFamilyProvider =
    StateNotifierProvider<FontFamilyNotifier, String>((ref) {
  return FontFamilyNotifier();
});

class FontFamilyNotifier extends StateNotifier<String> {
  FontFamilyNotifier() : super(AppFonts.primary) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _storage.read(key: _kFontKey);
    if (saved != null && saved != state) {
      AppFonts.primary = saved;
      state = saved;
    }
  }

  Future<void> setFont(String family) async {
    AppFonts.primary = family;
    state = family;
    await _storage.write(key: _kFontKey, value: family);
  }

  bool isSelected(String family) => state == family;
}
