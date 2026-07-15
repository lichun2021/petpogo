import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// 高德矢量路网瓦片（GCJ-02 坐标系）。
const amapTileUrl =
    'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}';

/// 发起 Nominatim 逆地理编码基础请求并返回 display_name。
///
/// 地址展示格式与失败降级由调用页面自行处理。
Future<String> fetchNominatimDisplayName(LatLng position) async {
  final dio = Dio(
    BaseOptions(headers: {'User-Agent': 'PetPogoApp/1.0'}),
  );
  final response = await dio.get<dynamic>(
    'https://nominatim.openstreetmap.org/reverse',
    queryParameters: {
      'format': 'json',
      'lat': position.latitude.toStringAsFixed(7),
      'lon': position.longitude.toStringAsFixed(7),
      'accept-language': 'zh-CN,zh',
      'zoom': 18,
    },
  ).timeout(const Duration(seconds: 8));
  final data = response.data;
  if (data is Map) return data['display_name']?.toString() ?? '';
  return '';
}
