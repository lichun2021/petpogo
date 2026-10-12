/// An already-online response alone is not evidence of a new connection.
class DeviceReconnectTracker {
  final int previousLastOnlineTime;
  final int startedAt;
  bool _sawOffline;
  DeviceReconnectTracker(
      {required bool initiallyOnline,
      required this.previousLastOnlineTime,
      required this.startedAt})
      : _sawOffline = !initiallyOnline;

  bool observe({required bool online, required int lastOnlineTime}) {
    if (!online) {
      _sawOffline = true;
      return false;
    }
    return _sawOffline ||
        (lastOnlineTime > previousLastOnlineTime &&
            lastOnlineTime >= startedAt);
  }
}
