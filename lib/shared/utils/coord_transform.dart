import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// WGS-84 → GCJ-02（火星坐标）转换工具
///
/// 中国大陆地图（高德/腾讯/百度底图）使用 GCJ-02 坐标系。
/// GPS / geolocator 返回的是国际标准 WGS-84 坐标系。
/// 直接把 WGS-84 坐标放到高德地图上会产生 100~500m 偏移。
class CoordTransform {
  static const _a   = 6378245.0;       // 克拉索夫斯基椭球体长半轴
  static const _ee  = 0.00669342162296594323; // 偏心率平方

  /// 判断是否在中国大陆范围内（在范围外不做偏移）
  static bool _outOfChina(double lat, double lon) {
    return lon < 72.004 || lon > 137.8347 || lat < 0.8293 || lat > 55.8271;
  }

  static double _transformLat(double x, double y) {
    double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y +
        0.1 * x * y + 0.2 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    ret += (20.0 * math.sin(y * math.pi) +
            40.0 * math.sin(y / 3.0 * math.pi)) * 2.0 / 3.0;
    ret += (160.0 * math.sin(y / 12.0 * math.pi) +
            320.0 * math.sin(y * math.pi / 30.0)) * 2.0 / 3.0;
    return ret;
  }

  static double _transformLon(double x, double y) {
    double ret = 300.0 + x + 2.0 * y + 0.1 * x * x +
        0.1 * x * y + 0.1 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    ret += (20.0 * math.sin(x * math.pi) +
            40.0 * math.sin(x / 3.0 * math.pi)) * 2.0 / 3.0;
    ret += (150.0 * math.sin(x / 12.0 * math.pi) +
            300.0 * math.sin(x / 30.0 * math.pi)) * 2.0 / 3.0;
    return ret;
  }

  /// WGS-84 → GCJ-02
  ///
  /// 使用场景：
  ///   - geolocator 获取到 GPS 坐标后，转换再传给高德地图
  ///   - 保存围栏前转换（coordinateType: gcj02）
  static LatLng wgs84ToGcj02(double lat, double lon) {
    if (_outOfChina(lat, lon)) return LatLng(lat, lon);

    double dLat = _transformLat(lon - 105.0, lat - 35.0);
    double dLon = _transformLon(lon - 105.0, lat - 35.0);

    final radLat = lat / 180.0 * math.pi;
    double magic = math.sin(radLat);
    magic = 1 - _ee * magic * magic;
    final sqrtMagic = math.sqrt(magic);

    dLat = (dLat * 180.0) /
        ((_a * (1 - _ee)) / (magic * sqrtMagic) * math.pi);
    dLon = (dLon * 180.0) /
        (_a / sqrtMagic * math.cos(radLat) * math.pi);

    return LatLng(lat + dLat, lon + dLon);
  }
}
