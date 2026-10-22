import 'package:latlong2/latlong.dart';

enum NavigationMapApp {
  amap('高德地图'),
  tencent('腾讯地图'),
  baidu('百度地图'),
  apple('苹果地图');

  final String label;
  const NavigationMapApp(this.label);

  static List<NavigationMapApp> forPlatform({required bool isIOS}) => [
        amap,
        tencent,
        baidu,
        if (isIOS) apple,
      ];

  /// 高德、腾讯和百度明确传 GCJ02，苹果地图沿用 GPS 原始坐标。
  Uri navigationUri({
    required bool isIOS,
    required LatLng gcjPosition,
    required LatLng gpsPosition,
    required String destinationName,
  }) {
    final lat = gcjPosition.latitude.toStringAsFixed(6);
    final lng = gcjPosition.longitude.toStringAsFixed(6);
    final (scheme, host, path, params) = switch (this) {
      amap => (
          isIOS ? 'iosamap' : 'androidamap',
          'navi',
          '',
          {
            'sourceApplication': 'petpogo',
            'poiname': destinationName,
            'lat': lat,
            'lon': lng,
            'dev': '0',
            'style': '2',
          }
        ),
      tencent => (
          'qqmap',
          'map',
          '/routeplan',
          {
            'type': 'drive',
            'to': destinationName,
            'tocoord': '$lat,$lng',
            'referer': 'petpogo',
          }
        ),
      baidu => (
          'baidumap',
          'map',
          '/direction',
          {
            'destination': '$lat,$lng',
            'coord_type': 'gcj02',
            'mode': 'driving',
            'src': 'petpogo',
          }
        ),
      apple => (
          'maps',
          '',
          '',
          {
            'daddr': '${gpsPosition.latitude.toStringAsFixed(6)},'
                '${gpsPosition.longitude.toStringAsFixed(6)}',
            'dirflg': 'd',
          }
        ),
    };
    // 自定义 scheme 的空格用 %20，避免地图把 + 当作目的地名称的一部分。
    return Uri(
        scheme: scheme,
        host: host,
        path: path,
        query: params.entries
            .map((entry) => '${Uri.encodeComponent(entry.key)}='
                '${Uri.encodeComponent(entry.value)}')
            .join('&'));
  }
}
