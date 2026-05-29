/// 国家/地区数据模型
///
/// 对应 PeerApi POST /world/country/list 返回的单个条目：
/// { "country": "中国", "countryEn": "China", "countryId": "CN", "id": "1", "phoneId": "+86" }
class CountryInfo {
  final String id;

  /// 中文名称，如 "中国"
  final String country;

  /// 英文名称，如 "China"
  final String countryEn;

  /// ISO 2位国家码，如 "CN"
  final String countryId;

  /// 国际区号（含+），如 "+86"
  final String phoneId;

  const CountryInfo({
    required this.id,
    required this.country,
    required this.countryEn,
    required this.countryId,
    required this.phoneId,
  });

  factory CountryInfo.fromJson(Map<String, dynamic> json) => CountryInfo(
        id:        (json['id'] as String?) ?? '',
        country:   (json['country'] as String?) ?? '',
        countryEn: (json['countryEn'] as String?) ?? '',
        countryId: (json['countryId'] as String?) ?? '',
        phoneId:   (json['phoneId'] as String?) ?? '',
      );

  /// 区号数字部分（去掉 +），用于发给后台 nationNum，如 "86"
  String get dialCode => phoneId.replaceAll('+', '');

  /// 显示在选择器上的文字，如 "+86"
  String get displayCode => phoneId.isEmpty ? '' : phoneId;

  /// 国旗 Emoji（从 ISO 2位码计算，无需额外字段）
  /// 原理：每个字母映射到 Regional Indicator Symbol Letter（U+1F1E6 起）
  String get flagEmoji {
    if (countryId.length != 2) return '🌐';
    final base = 0x1F1E6;
    final a = countryId.toUpperCase().codeUnitAt(0) - 'A'.codeUnitAt(0);
    final b = countryId.toUpperCase().codeUnitAt(1) - 'A'.codeUnitAt(0);
    if (a < 0 || a > 25 || b < 0 || b > 25) return '🌐';
    return String.fromCharCode(base + a) + String.fromCharCode(base + b);
  }

  /// 中国大陆默认值（离线 fallback）
  static const china = CountryInfo(
    id:        '1',
    country:   '中国',
    countryEn: 'China',
    countryId: 'CN',
    phoneId:   '+86',
  );

  @override
  bool operator ==(Object other) =>
      other is CountryInfo && other.countryId == countryId;

  @override
  int get hashCode => countryId.hashCode;
}
