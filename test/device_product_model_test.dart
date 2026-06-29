import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/device/data/models/device_model.dart';
import 'package:petpogo_app/features/device/data/models/device_product_model.dart';

void main() {
  group('DeviceProductType', () {
    test('uses product catalog alias when available', () {
      final product = DeviceProductModel.fromJson({
        'id': 1,
        'productKey': DeviceProductKeys.robot,
        'alias': 'ROBOT',
        'name': '机器人',
        'productTypeName': '机器人',
        'status': 1,
      });

      expect(product.type, DeviceProductType.robot);
      expect(product.displayName, '机器人');
    });

    test('falls back to exact productKey without fuzzy matching', () {
      expect(
        DeviceProductType.fromProductKey(DeviceProductKeys.collar),
        DeviceProductType.collar,
      );
      expect(
        DeviceProductType.fromProductKey('PK_SOMETHING_ROBOT_LIKE'),
        DeviceProductType.unknown,
      );
    });

    test('device name never changes product type', () {
      const device = DeviceModel(
        deviceId: '1',
        productKey: '',
        name: '客厅机器人',
      );

      expect(device.productType, DeviceProductType.unknown);
      expect(device.isRobot, isFalse);
      expect(device.isCollar, isFalse);
    });
  });
}
