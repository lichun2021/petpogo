import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import 'models/country_model.dart';

class CountryRepository {
  final ApiClient _client;

  CountryRepository(this._client);

  /// 获取国家/地区列表
  /// 失败时返回仅含中国的 fallback 列表，保证 UI 不崩溃。
  Future<List<CountryInfo>> fetchList() async {
    try {
      final res = await _client
          .post<Map<String, dynamic>>(ApiEndpoints.peerCountryList);
      final rawList = (res['info'] as List?);
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
      final res = await _client
          .get<Map<String, dynamic>>(ApiEndpoints.peerCountryDefault);
      final info = res;
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
      return CountryInfo.china;
    } catch (e) {
      debugPrint('[CountryRepo] fetchDefault 失败（使用中国默认）: $e');
      return CountryInfo.china;
    }
  }
}

// ── Riverpod Provider ─────────────────────────────────────────
final countryRepositoryProvider = Provider<CountryRepository>((ref) {
  return CountryRepository(ref.watch(apiClientProvider));
});

/// 国家列表 FutureProvider（缓存一次，页面重建不重复请求）
final countryListProvider = FutureProvider<List<CountryInfo>>((ref) {
  return ref.watch(countryRepositoryProvider).fetchList();
});
