import 'dart:async';

/// HTTP 控制串行发送；慢请求期间合并移动指令，松手停止覆盖待发移动。
class HttpMotorController {
  final Future<void> Function(int, int, int, int) send;
  final void Function(Object)? onError;
  List<int>? _pending;
  Future<void>? _work;
  bool _closed = false, _moved = false;
  HttpMotorController(this.send, {this.onError});
  void update(
      int leftDirection, int leftSpeed, int rightDirection, int rightSpeed) {
    if (_closed) return;
    _moved = _moved || leftSpeed != 0 || rightSpeed != 0;
    _pending = [leftDirection, leftSpeed, rightDirection, rightSpeed];
    _work ??= _drain();
  }

  Future<void> _drain() async {
    while (_pending != null) {
      final next = _pending!;
      _pending = null;
      try {
        await send(next[0], next[1], next[2], next[3]);
      } catch (error) {
        onError?.call(error);
      }
    }
    _work = null;
  }

  Future<void> stop() async {
    if (!_moved || _closed) return;
    update(0, 0, 0, 0);
    await _work;
    _moved = false;
  }

  Future<void> close() async {
    await stop();
    _closed = true;
  }
}
