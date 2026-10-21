import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Debug output is disabled in release. Operational events carry only a small
/// allowlist of metadata; request bodies and credentials never enter the log.
abstract final class AppLog {
  static void debug(String? message, {int? wrapWidth}) {
    if (!kDebugMode) return;
    debugPrint(redact(message ?? ''), wrapWidth: wrapWidth);
  }

  static void event(String event,
      {String level = 'info', Map<String, Object?> fields = const {}}) {
    if (!kDebugMode && level != 'warning' && level != 'error') return;
    const allowed = {
      'requestId',
      'method',
      'path',
      'status',
      'durationMs',
      'errorType',
      'attempt',
      'category'
    };
    debugPrint(jsonEncode({
      'time': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'event': event,
      for (final entry in fields.entries)
        if (allowed.contains(entry.key))
          entry.key: entry.value is String
              ? redact(entry.value as String)
              : entry.value,
    }));
  }

  @visibleForTesting
  static String redact(String message) {
    var safe = message
        .replaceAllMapped(RegExp(r'(?:https?|petpogo)://[^\s<>]+'), (match) {
      final url = Uri.tryParse(match[0]!);
      if (url == null) return '<url>';
      return '${url.scheme}://${url.host}${url.hasPort ? ':${url.port}' : ''}${url.path}';
    });
    safe = safe.replaceAll(
        RegExp(r'Bearer\s+[^\s,}]+', caseSensitive: false), 'Bearer ***');
    safe = safe.replaceAllMapped(
        RegExp(
            r'''(["']?)(password|oldPassword|newPassword|refreshToken|refresh_token|access_token|userSig|token|secret|x-signature|code)\1\s*[:=]\s*(?:"[^"]*"|'[^']*'|[^\s,}]+)''',
            caseSensitive: false),
        (match) => '${match[2]}=***');
    return safe.replaceAllMapped(RegExp(r'\b(1\d{2})\d{4}(\d{4})\b'),
        (match) => '${match[1]}****${match[2]}');
  }
}
