import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/device/data/repository/device_repository.dart';

void main() {
  group('buildMotorControlPayload', () {
    test('builds forward and reverse commands', () {
      final payload = buildMotorControlPayload(
        motor0Direction: 1,
        motor0Speed: 10,
        motor1Direction: 2,
        motor1Speed: 8,
      );

      expect(payload['motor_0'], {'direction': 1, 'speed': 10});
      expect(payload['motor_1'], {'direction': 2, 'speed': 8});
      expect(utf8.encode(jsonEncode(payload)).length, lessThanOrEqualTo(512));
    });

    test('builds a full stop command', () {
      final payload = buildMotorControlPayload(
        motor0Direction: 0,
        motor0Speed: 0,
        motor1Direction: 0,
        motor1Speed: 0,
      );

      expect(payload, {
        'motor_0': {'direction': 0, 'speed': 0},
        'motor_1': {'direction': 0, 'speed': 0},
      });
    });

    test('rejects invalid directions and speeds', () {
      expect(
        () => buildMotorControlPayload(
          motor0Direction: 3,
          motor0Speed: 10,
          motor1Direction: 0,
          motor1Speed: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => buildMotorControlPayload(
          motor0Direction: 1,
          motor0Speed: 101,
          motor1Direction: 0,
          motor1Speed: 0,
        ),
        throwsRangeError,
      );
    });
  });
}
