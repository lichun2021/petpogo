import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/bind_device/services/collar_provisioning_protocol.dart';

class _Transport implements CollarProvisioningTransport {
  int mtu = 247;
  String? failAt;
  final writes = <(String, List<int>)>[];
  @override
  Future<int> negotiatedMtu(int minimum) async => mtu;
  @override
  Future<void> write(String uuid, List<int> value) async {
    if (uuid == failAt) throw StateError('write rejected or disconnected');
    writes.add((uuid, value));
  }
}

void main() {
  test('fetches fresh token after credentials and writes token before save',
      () async {
    final transport = _Transport()..mtu = 67;
    var calls = 0;
    Future<String> acquire() async {
      calls++;
      expect(transport.writes.last.$1, CollarProvisioningProtocol.password);
      return 'A' * 64;
    }

    await CollarProvisioningProtocol.send(transport, 'wifi', 'password',
        acquireBindToken: acquire);
    expect(transport.writes.map((e) => e.$1), [
      CollarProvisioningProtocol.ssid,
      CollarProvisioningProtocol.password,
      CollarProvisioningProtocol.bindToken,
      CollarProvisioningProtocol.control
    ]);
    expect(transport.writes[2].$2, utf8.encode('A' * 64));
    await CollarProvisioningProtocol.send(transport, 'wifi', 'password',
        acquireBindToken: acquire);
    expect(calls, 2);
  });

  for (final token in ['', 'A' * 65, 'abc-def', '令牌', 'abc\n']) {
    test('rejects invalid token ${token.length} before committing', () async {
      final transport = _Transport();
      await expectLater(
          CollarProvisioningProtocol.send(transport, 'wifi', 'password',
              acquireBindToken: () async => token),
          throwsA(isA<CollarProvisioningException>()));
      expect(
          transport.writes
              .any((e) => e.$1 == CollarProvisioningProtocol.control),
          isFalse);
    });
  }

  test('64-byte token requires MTU 67', () async {
    final transport = _Transport()..mtu = 66;
    await expectLater(
        CollarProvisioningProtocol.send(transport, 'wifi', 'password',
            acquireBindToken: () async => 'A' * 64),
        throwsA(isA<CollarProvisioningException>()));
    expect(
        transport.writes.any((e) => e.$1 == CollarProvisioningProtocol.control),
        isFalse);
  });

  test('token retrieval failure never commits configuration', () async {
    final transport = _Transport();
    await expectLater(
        CollarProvisioningProtocol.send(transport, 'wifi', 'password',
            acquireBindToken: () async => throw StateError('network failure')),
        throwsStateError);
    expect(transport.writes.length, 2);
  });

  test('token write rejection never commits configuration', () async {
    final transport = _Transport()
      ..failAt = CollarProvisioningProtocol.bindToken;
    await expectLater(
        CollarProvisioningProtocol.send(transport, 'wifi', 'password',
            acquireBindToken: () async => 'abc123'),
        throwsStateError);
    expect(transport.writes.length, 2);
  });

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

  test('rejects insufficient MTU for actual payload', () async {
    final transport = _Transport()..mtu = 23;
    await expectLater(CollarProvisioningProtocol.send(transport, 'a' * 32, 'b'),
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
