import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/bind_device/services/device_reconnect_tracker.dart';

void main() {
  test('stale online state does not confirm new WiFi', () {
    final tracker = DeviceReconnectTracker(
        initiallyOnline: true, previousLastOnlineTime: 100, startedAt: 200);
    expect(tracker.observe(online: true, lastOnlineTime: 100), isFalse);
    expect(tracker.observe(online: true, lastOnlineTime: 150), isFalse);
  });
  test('a fresh online timestamp confirms target device reconnection', () {
    final tracker = DeviceReconnectTracker(
        initiallyOnline: true, previousLastOnlineTime: 100, startedAt: 200);
    expect(tracker.observe(online: true, lastOnlineTime: 220), isTrue);
  });
  test('offline to online confirms reconnection without timestamp support', () {
    final tracker = DeviceReconnectTracker(
        initiallyOnline: true, previousLastOnlineTime: 0, startedAt: 200);
    expect(tracker.observe(online: false, lastOnlineTime: 0), isFalse);
    expect(tracker.observe(online: true, lastOnlineTime: 0), isTrue);
  });
  test('device already offline must still come online', () {
    final tracker = DeviceReconnectTracker(
        initiallyOnline: false, previousLastOnlineTime: 100, startedAt: 200);
    expect(tracker.observe(online: false, lastOnlineTime: 100), isFalse);
    expect(tracker.observe(online: true, lastOnlineTime: 100), isTrue);
  });
}
