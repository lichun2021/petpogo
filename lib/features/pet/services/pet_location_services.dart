import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/utils/map_services.dart';

typedef PetAddressLookup = Future<String> Function(
    double latitude, double longitude);

/// 接口没有文字地址时，使用设备的 WGS84 坐标解析地址。
final petAddressLookupProvider = Provider<PetAddressLookup>((ref) {
  return (latitude, longitude) async {
    final display =
        await fetchNominatimDisplayName(LatLng(latitude, longitude));
    final parts = display.split(', ');
    if (parts.length > 1 && parts.last == '中国') parts.removeLast();
    return parts.take(4).join(' ').trim();
  };
});

final petLocationClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);
