import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_flags.dart';

const kShowRawErrorKey = 'dev_show_raw_error';

/// 「显示原始错误信息」开关
///
/// 初始值由 main.dart 通过 [resolveInitialShowRawError] 计算后 override 注入：
///   - 配置露出开关（showRawErrorToggle）且用户曾切换过 → 用户值
///   - 否则 → 配置默认值 showRawError
final showRawErrorProvider =
    StateNotifierProvider<ShowRawErrorNotifier, bool>((ref) {
  return ShowRawErrorNotifier(AppFlags.current.showRawError);
});

/// 按 AppFlags + 已持久化的用户选择解析初始值
bool resolveInitialShowRawError(SharedPreferences prefs, AppFlags flags) {
  if (flags.showRawErrorToggle) {
    final saved = prefs.getBool(kShowRawErrorKey);
    if (saved != null) return saved;
  }
  return flags.showRawError;
}

class ShowRawErrorNotifier extends StateNotifier<bool> {
  ShowRawErrorNotifier(super.initial);

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kShowRawErrorKey, value);
  }

  Future<void> toggle() => set(!state);
}
