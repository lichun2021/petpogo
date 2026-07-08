/// 设备绑定流程类型。
///
/// 新增产品时只需在此处加一行映射，绑定入口（SelectDevicePage）
/// 会自动按产品目录 API 返回的产品动态渲染，无需改二分判断。
enum BindFlow {
  scanQr,   // 扫设备背面二维码（项圈）
  wifiSetup, // 手机生成 WiFi 二维码让设备扫（机器人）
  manual,   // 手动输入（兜底，未识别类型）
}

enum DeviceProductType {
  collar,
  robot,
  unknown;

  static DeviceProductType fromAlias(String alias) {
    switch (alias.trim().toUpperCase()) {
      case 'COLLAR':
        return DeviceProductType.collar;
      case 'ROBOT':
        return DeviceProductType.robot;
      default:
        return DeviceProductType.unknown;
    }
  }

  static DeviceProductType fromProductKey(String productKey) {
    switch (productKey.trim().toUpperCase()) {
      case DeviceProductKeys.collar:
      case 'PK_IPET_ESP32': // 设备列表 API 返回旧 key，兼容处理
        return DeviceProductType.collar;
      case DeviceProductKeys.robot:
        return DeviceProductType.robot;
      default:
        return DeviceProductType.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case DeviceProductType.collar:
        return '项圈';
      case DeviceProductType.robot:
        return '机器人';
      case DeviceProductType.unknown:
        return '智能设备';
    }
  }

  /// 该产品类型对应的绑定流程。新增产品时在这里加一行即可。
  BindFlow get bindFlow {
    switch (this) {
      case DeviceProductType.collar:
        return BindFlow.scanQr;
      case DeviceProductType.robot:
        return BindFlow.wifiSetup;
      case DeviceProductType.unknown:
        return BindFlow.manual;
    }
  }
}

abstract final class DeviceProductKeys {
  static const collar = 'PK_IPET_COLLAR';
  static const robot = 'PK_IPET_ROBOT';
}

class DeviceProductModel {
  final int id;
  final String productKey;
  final String alias;
  final String name;
  final String productTypeName;
  final int status;

  const DeviceProductModel({
    required this.id,
    required this.productKey,
    required this.alias,
    required this.name,
    required this.productTypeName,
    required this.status,
  });

  DeviceProductType get type {
    final aliasType = DeviceProductType.fromAlias(alias);
    return aliasType == DeviceProductType.unknown
        ? DeviceProductType.fromProductKey(productKey)
        : aliasType;
  }

  String get displayName {
    if (productTypeName.trim().isNotEmpty) return productTypeName.trim();
    if (name.trim().isNotEmpty) return name.trim();
    return type.displayName;
  }

  bool get isEnabled => status == 1;

  factory DeviceProductModel.fromJson(Map<String, dynamic> json) {
    return DeviceProductModel(
      id: _asInt(json['id']),
      productKey: json['productKey']?.toString().trim() ?? '',
      alias: json['alias']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      productTypeName: json['productTypeName']?.toString().trim() ?? '',
      status: _asInt(json['status']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
