import 'package:flutter/material.dart';
import '../../shared/theme/app_colors.dart';
import '../../core/config/shop_config.dart';

/// 附近门店页（商城的子页面）
/// 数据源由 ShopConfig.nearbySource 控制
class NearbyStoresPage extends StatefulWidget {
  const NearbyStoresPage({super.key});

  @override
  State<NearbyStoresPage> createState() => _NearbyStoresPageState();
}

class _NearbyStoresPageState extends State<NearbyStoresPage> {
  int _sortIndex = 2; // 默认"距离最近"

  final List<String> _sortOptions = ['附近门店', '销量最高', '距离最近', '好评最多'];

  final List<Map<String, dynamic>> _stores = [
    {
      'name': '聚宠生活馆·乐宠它petphone (南湾店)',
      'type': '附件门店',
      'rating': 5.0,
      'sales': 0,
      'address': '南湾街道南岭村社区...',
      'distance': '1.0km',
      'emoji': '🏪',
    },
    {
      'name': '宠爱一生宠物美容医院 (科技园店)',
      'type': '宠物医院',
      'rating': 4.8,
      'sales': 238,
      'address': '科技园北区中山大道...',
      'distance': '0.8km',
      'emoji': '🏥',
    },
    {
      'name': '毛孩子宠物美容SPA',
      'type': '宠物美容',
      'rating': 4.9,
      'sales': 102,
      'address': '粤海街道高新科技园...',
      'distance': '1.2km',
      'emoji': '✂️',
    },
  ];

  String get _dataSourceLabel => ShopConfig.nearbySource == NearbyStoreSource.amapPoi
      ? '高德POI'
      : '自有后台';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(),
        title: const Text('附近门店'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text(
                _dataSourceLabel,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 筛选栏 ───────────────────────────────
          Container(
            color: AppColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: List.generate(_sortOptions.length, (i) {
                  final isSelected = _sortIndex == i;
                  return GestureDetector(
                    onTap: () => setState(() => _sortIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: isSelected
                            ? [BoxShadow(color: AppColors.primaryGlow, blurRadius: 10, offset: const Offset(0, 3))]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(
                            _sortOptions[i],
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                            ),
                          ),
                          if (i == 0) ...[
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // ── 门店列表 ─────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                itemCount: _stores.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  if (i == _stores.length) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '门店加载完毕',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: AppColors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }
                  return _StoreCard(store: _stores[i]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  const _StoreCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final rating = store['rating'] as double;
    final sales  = store['sales']  as int;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          splashColor: AppColors.primaryGlow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 门店图片
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(store['emoji'] as String, style: const TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(width: 14),

                // 门店信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store['name'] as String,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < rating.floor() ? Icons.star_rounded : Icons.star_border_rounded,
                              color: AppColors.star,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '已售$sales',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              store['type'] as String,
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              store['address'] as String,
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            store['distance'] as String,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
