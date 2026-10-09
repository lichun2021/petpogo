/// Serializes press/release around an asynchronous native recording start.
/// Releasing before start completes always discards the recording.
class HoldRecordingSession {
  HoldRecordingSession(
      {required this.start, required this.stop, required this.cancel});
  final Future<bool> Function() start;
  final Future<String?> Function() stop;
  final Future<void> Function() cancel;
  Future<bool>? _starting;
  Future<String?>? _ending;
  bool _held = false;
  bool _active = false;
  bool get isRecording => _held && _active;

  Future<void> begin() async {
    if (_starting != null || _ending != null) return;
    _held = true;
    _starting = start();
    try {
      _active = await _starting!;
    } catch (_) {
      _held = false;
      _active = false;
      _starting = null;
      rethrow;
    }
  }

  Future<String?> end({required bool submit}) {
    if (_ending != null) return _ending!;
    final starting = _starting;
    if (starting == null) return Future.value(null);
    final canSubmit = submit && isRecording;
    _held = false;
    return _ending = _finish(starting, canSubmit);
  }

  Future<String?> _finish(Future<bool> starting, bool submit) async {
    try {
      if (!await starting) return null;
      if (submit) return await stop();
      await cancel();
      return null;
    } finally {
      _active = false;
      _held = false;
      _starting = null;
      _ending = null;
    }
  }
}
