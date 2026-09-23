import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import 'models/country_model.dart';

class CountryRepository {
  final ApiClient _client;

  CountryRepository(this._client);

  /// 获取可用国家和区号；请求失败交由页面处理。
  Future<List<CountryInfo>> fetchList() async {
    final res = await _client.post<Map<String, dynamic>>(ApiEndpoints.peerCountryList);
    final rawList = res['info'];
    if (rawList is! List) throw const FormatException('国家列表格式错误');
    return rawList.map((item) => CountryInfo.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<CountryInfo> fetchDefault() async {
    final info = await _client.get<Map<String, dynamic>>(ApiEndpoints.peerCountryDefault);
    final name = (info['countryName'] ?? info['country'] ?? '') as String;
    final countryId = info['countryId'] as String? ?? '';
    final phoneId = info['phoneId'] as String? ?? '';
    if (countryId.isEmpty || phoneId.isEmpty) {
      throw const FormatException('默认国家缺少国家码或区号');
    }
    return CountryInfo(
      id: (info['id'] ?? '').toString(),
      country: name,
      countryEn: name,
      countryId: countryId,
      phoneId: phoneId,
    );
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
