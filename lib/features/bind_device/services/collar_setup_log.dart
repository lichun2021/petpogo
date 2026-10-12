import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/api/api_exception.dart';

/// Only record stage names, counts, durations and error types. Never payloads.
class CollarSetupLog extends ChangeNotifier {
  final _clock = Stopwatch()..start();
  final List<String> entries = [];
  void failure(String stage, Object error) {
    if (error is DioException && error.error is ApiException) {
      error = error.error as ApiException;
    }
    add('$stage failed: ${error.runtimeType}'
        '${error is ApiException ? " http=${error.statusCode} category=${error.type.name}" : ""}');
  }

  void add(String message) {
    final line =
        '${DateTime.now().toIso8601String()} +${_clock.elapsedMilliseconds}ms $message';
    entries.add(line);
    if (entries.length > 150) entries.removeAt(0);
    debugPrint('[CollarSetup] $line');
    notifyListeners();
  }
}
