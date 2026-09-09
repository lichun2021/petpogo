import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 运行时功能开关，来源于 `assets/config/app_flags.json`。
///
/// 与 debug / release 构建模式无关：改文件重新打包即可切换行为。
/// 文件缺失或格式错误时全部回退为 false，不影响启动。
///
/// ```json
/// { "showRawError": false, "showRawErrorToggle": true }
/// ```
class AppFlags {
  const AppFlags({
    this.showRawError = false,
    this.showRawErrorToggle = false,
  });

  /// 错误提示下方是否附带原始错误文本（默认值；设置页开关可覆盖）
  final bool showRawError;

  /// 设置页是否露出「显示原始错误信息」运行时开关
  final bool showRawErrorToggle;

  static const assetPath = 'assets/config/app_flags.json';

  static AppFlags _current = const AppFlags();

  /// 当前生效的配置（[load] 之前为全 false 默认值）
  static AppFlags get current => _current;

  /// 启动时调用一次；解析失败静默回退
  static Future<AppFlags> load({AssetBundle? bundle}) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(assetPath);
      _current = AppFlags.fromJson(raw);
    } catch (e) {
      debugPrint('[AppFlags] 读取 $assetPath 失败，使用默认值: $e');
      _current = const AppFlags();
    }
    debugPrint('[AppFlags] showRawError=${_current.showRawError} '
        'showRawErrorToggle=${_current.showRawErrorToggle}');
    return _current;
  }

  /// 解析 JSON 字符串；非法内容抛出异常由 [load] 兜底
  factory AppFlags.fromJson(String raw) {
    final map = jsonDecode(raw);
    if (map is! Map<String, dynamic>) {
      throw const FormatException('app_flags.json 顶层必须是对象');
    }
    return AppFlags(
      showRawError: map['showRawError'] == true,
      showRawErrorToggle: map['showRawErrorToggle'] == true,
    );
  }

  /// 仅供测试注入
  @visibleForTesting
  static void overrideForTest(AppFlags flags) => _current = flags;
}
