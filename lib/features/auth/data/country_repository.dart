/// 国家/地区 Repository
///
/// 直接调用 iPet 后台（PeerApi）公开接口：
///   POST {peer}/world/country/list    → fetchList()
///   GET  {peer}/world/country/default → fetchDefault()
///
/// 两个接口均免登录，使用独立 Dio 实例，不走 Nuxt 服务器。

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/country_model.dart';

/// iPet 对方后台公网地址（国家列表等公开接口）
const _kPeerPublicUrl = 'http://49.234.39.11:8006';

class CountryRepository {
  late final Dio _dio;

  CountryRepository() {
    _dio = Dio(BaseOptions(
      baseUrl: _kPeerPublicUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
  }

  /// 获取国家/地区列表
  /// 失败时返回仅含中国的 fallback 列表，保证 UI 不崩溃。
  Future<List<CountryInfo>> fetchList() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/world/country/list');
      final rawList = (res.data?['info'] as List?);
      if (rawList == null) return [CountryInfo.china];
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(CountryInfo.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[CountryRepo] fetchList 失败（使用默认列表）: $e');
      return [CountryInfo.china];
    }
  }

  /// 获取默认国家（中国大陆）
  Future<CountryInfo> fetchDefault() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/world/country/default');
      final info = res.data;
      if (info != null) {
        // default 接口返回的是不带 code 封装的直接对象
        final raw = info['info'] ?? info;
        if (raw is Map<String, dynamic>) {
          // 兼容字段名差异：countryName / country
          final name = (raw['country'] ?? raw['countryName'] ?? '') as String;
          final countryId = (raw['countryId'] ?? '') as String;
          final phoneId = (raw['phoneId'] ?? '') as String;
          if (countryId.isNotEmpty) {
            return CountryInfo(
              id: (raw['id'] ?? '0').toString(),
              country: name,
              countryEn: name,
              countryId: countryId,
              phoneId: phoneId.isEmpty ? '+86' : phoneId,
            );
          }
        }
      }
      return CountryInfo.china;
    } catch (e) {
      debugPrint('[CountryRepo] fetchDefault 失败（使用中国默认）: $e');
      return CountryInfo.china;
    }
  }
}

// ── Riverpod Provider ─────────────────────────────────────────
final countryRepositoryProvider = Provider<CountryRepository>((ref) {
  return CountryRepository();
});

/// 国家列表 FutureProvider（缓存一次，页面重建不重复请求）
final countryListProvider = FutureProvider<List<CountryInfo>>((ref) {
  return ref.watch(countryRepositoryProvider).fetchList();
});
