import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kLocaleKey = 'app_locale';
const _storage = FlutterSecureStorage();

/// 语言 Provider — 持久化存储，全局响应
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('zh')) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _storage.read(key: _kLocaleKey);
    if (saved != null) {
      state = Locale(saved);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _storage.write(key: _kLocaleKey, value: locale.languageCode);
  }

  bool get isChinese => state.languageCode == 'zh';
  bool get isEnglish => state.languageCode == 'en';
}
