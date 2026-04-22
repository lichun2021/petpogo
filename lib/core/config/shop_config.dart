/// 商城 - 附近门店数据源配置
/// 修改 [nearbySource] 的值即可一键切换数据源，无需改其他代码
enum NearbyStoreSource {
  /// 高德 POI 搜索（无需后台，立即可用）
  amapPoi,

  /// 自有后台门店数据（后台需新建 /uclgwapp/merchant/nearby/list）
  ownBackend,
}

class ShopConfig {
  ShopConfig._();

  // ──────────────────────────────────────────────
  // 🔧 改这一行即可切换附近门店数据源
  // ──────────────────────────────────────────────
  static const NearbyStoreSource nearbySource = NearbyStoreSource.amapPoi;

  // 高德 POI 搜索关键词（amapPoi 模式使用）
  static const List<String> poiKeywords = [
    '宠物医院',
    '宠物美容',
    '宠物用品店',
    '宠物培训',
  ];

  // 附近门店搜索半径（米）
  static const int searchRadius = 5000;
}
