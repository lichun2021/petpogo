import 'package:uuid/uuid.dart';
import 'stream_diagnostics.dart';

/// 固定录像开始时的观看上下文，避免重连或下一段录像覆盖仍在上传的日志。
class RecordingDiagnostics {
  final StreamDiagnostics stream;
  final String recordingId;
  final int _attempt;
  final _clock = Stopwatch()..start();
  RecordingDiagnostics(this.stream, {String? recordingId})
      : recordingId = recordingId ?? const Uuid().v4().substring(0, 12),
        _attempt = stream.attempt;

  void log(String event, String stage, String message,
      {String level = 'info', Map<String, Object?> fields = const {}}) {
    stream.log('record.$event', stage, message,
        level: level,
        fields: {...fields, 'recordingId': recordingId},
        forAttempt: _attempt,
        elapsedMs: _clock.elapsedMilliseconds);
  }

  void failure(String event, String stage, String message, Object error,
      {Map<String, Object?> fields = const {}, StackTrace? stackTrace}) {
    log(event, stage, message, level: 'warning', fields: {
      ...fields,
      ...StreamDiagnostics.safeError(error),
      if (stackTrace != null)
        'errorStack': stackTrace.toString().split('\n').take(5).join(' | '),
    });
  }
}
