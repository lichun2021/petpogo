import 'dart:io';

import '../../core/api/api_exception.dart';
import '../../core/api/result.dart';

/// 面向用户的错误文案
class ErrorCopy {
  const ErrorCopy({required this.message, required this.raw});

  /// 设计好的用户文案，始终显示
  final String message;

  /// 原始错误文本（`e.toString()`），仅在「显示原始错误信息」开关打开时附带
  final String raw;
}

/// 把任意错误对象转成 [ErrorCopy]。
///
/// 全 App 唯一的错误 → 文案入口；页面禁止自行 `e.toString()` 显示。
/// 映射顺序：
///   1. [ApiException] → `userMessage`
///   2. `Exception('[iPet] <tip>')` → 已知 tip 映射表，未命中则用 tip 本身
///      （iPet 网关的 tip 多数已是中文业务提示）
///   3. 网络类异常 → 网络文案
///   4. 其他 → [genericMessage]
abstract final class ErrorPresenter {
  static const genericMessage = '操作失败，请稍后重试';
  static const networkMessage = '网络连接失败，请检查你的网络设置';

  static const iPetPrefix = '[iPet]';

  /// 已知 iPet tip → 设计文案。键为包含匹配（contains）。
  static const iPetTipTable = <String, String>{
    '未上报位置': '设备暂未上报位置，请稍后再试',
    '设备不在线': '设备当前离线，请检查设备电量和网络',
    '设备离线': '设备当前离线，请检查设备电量和网络',
    '配网凭证无效': '配网信息已失效，请重新开始配网',
    '口令生成失败': '分享口令生成失败，请重试',
    'token': '登录状态已失效，请重新登录',
  };

  static ErrorCopy describe(Object? error, {String? fallback}) {
    final raw = error?.toString() ?? '';
    final generic = fallback ?? genericMessage;

    if (error == null) return ErrorCopy(message: generic, raw: raw);

    if (error is Failure) {
      return describe(error.exception, fallback: fallback);
    }

    if (error is ApiException) {
      return ErrorCopy(message: error.userMessage, raw: raw);
    }

    final iPetTip = _extractIPetTip(raw);
    if (iPetTip != null) {
      for (final entry in iPetTipTable.entries) {
        if (iPetTip.contains(entry.key)) {
          return ErrorCopy(message: entry.value, raw: raw);
        }
      }
      return ErrorCopy(
        message: iPetTip.isNotEmpty ? iPetTip : generic,
        raw: raw,
      );
    }

    if (error is SocketException || error is HttpException) {
      return ErrorCopy(message: networkMessage, raw: raw);
    }

    return ErrorCopy(message: generic, raw: raw);
  }

  /// 仅取用户文案的快捷方式
  static String message(Object? error, {String? fallback}) =>
      describe(error, fallback: fallback).message;

  /// 从 `Exception: [iPet] xxx` 中提取 `xxx`
  static String? _extractIPetTip(String raw) {
    final idx = raw.indexOf(iPetPrefix);
    if (idx < 0) return null;
    return raw.substring(idx + iPetPrefix.length).trim();
  }
}
