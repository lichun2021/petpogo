import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/bind_device/services/collar_provisioning_protocol.dart';

class _Transport implements CollarProvisioningTransport {
  int mtu = 247;
  String? failAt;
  final writes = <(String, List<int>)>[];
  @override
  Future<int> negotiatedMtu() async => mtu;
  @override
  Future<void> write(String uuid, List<int> value) async {
    if (uuid == failAt) throw StateError('write rejected or disconnected');
    writes.add((uuid, value));
  }
}

void main() {
  test('writes UTF-8 SSID, password and save in order without terminators',
      () async {
    final transport = _Transport();
    await CollarProvisioningProtocol.send(transport, '宠物 WiFi', ' password ');
    expect(transport.writes.map((entry) => entry.$1), [
      CollarProvisioningProtocol.ssid,
      CollarProvisioningProtocol.password,
      CollarProvisioningProtocol.control,
    ]);
    expect(transport.writes.map((entry) => entry.$2), [
      utf8.encode('宠物 WiFi'),
      utf8.encode(' password '),
      [1],
    ]);
  });

  test('accepts maximum byte lengths and MTU 66', () async {
    final transport = _Transport()..mtu = 66;
    await CollarProvisioningProtocol.send(transport, 'a' * 32, 'b' * 63);
    expect(transport.writes.last.$1, CollarProvisioningProtocol.control);
  });

  test('open network explicitly clears previously staged password', () async {
    final transport = _Transport();
    await CollarProvisioningProtocol.send(transport, 'open', '');
    expect(transport.writes[1].$1, CollarProvisioningProtocol.password);
    expect(transport.writes[1].$2, isEmpty);
  });

  for (final ssid in ['', 'a' * 33, '中' * 11]) {
    test(
        'rejects invalid SSID byte count ${utf8.encode(ssid).length} before writes',
        () async {
      final transport = _Transport();
      await expectLater(CollarProvisioningProtocol.send(transport, ssid, ''),
          throwsA(isA<CollarProvisioningException>()));
      expect(transport.writes, isEmpty);
    });
  }

  test('rejects multibyte password above 63 bytes', () async {
    final transport = _Transport();
    await expectLater(
        CollarProvisioningProtocol.send(transport, 'wifi', '中' * 22),
        throwsA(isA<CollarProvisioningException>()));
    expect(transport.writes, isEmpty);
  });

  test('rejects insufficient MTU even for short credentials', () async {
    final transport = _Transport()..mtu = 65;
    await expectLater(CollarProvisioningProtocol.send(transport, 'a', 'b'),
        throwsA(isA<CollarProvisioningException>()));
    expect(transport.writes, isEmpty);
  });

  test('password failure never sends save command', () async {
    final transport = _Transport()
      ..failAt = CollarProvisioningProtocol.password;
    await expectLater(
        CollarProvisioningProtocol.send(transport, 'wifi', 'password'),
        throwsStateError);
    expect(transport.writes.length, 1);
  });

  test('unacknowledged save is not reported as success', () async {
    final transport = _Transport()..failAt = CollarProvisioningProtocol.control;
    await expectLater(
        CollarProvisioningProtocol.send(transport, 'wifi', 'password'),
        throwsStateError);
    expect(transport.writes.length, 2);
  });
}
