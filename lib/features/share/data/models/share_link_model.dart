class ShareCreateResult {
  final String code;
  final String type;
  final String title;
  final String description;
  final String imageUrl;
  final String shareUrl;
  final String deepLink;
  final int expireDays;

  const ShareCreateResult({
    required this.code,
    required this.type,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.shareUrl,
    required this.deepLink,
    required this.expireDays,
  });

  factory ShareCreateResult.fromJson(Map<String, dynamic> json) {
    return ShareCreateResult(
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl:
          json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? '',
      shareUrl:
          json['shareUrl']?.toString() ?? json['share_url']?.toString() ?? '',
      deepLink:
          json['deepLink']?.toString() ?? json['deep_link']?.toString() ?? '',
      expireDays: _asInt(json['expireDays'] ?? json['expire_days']),
    );
  }
}

class ShareResolveResult {
  final String code;
  final String type;
  final String title;
  final String description;
  final String imageUrl;
  final String deepLink;
  final String targetId;
  final bool createdByCurrentUser;
  final Map<String, dynamic> payload;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  const ShareResolveResult({
    required this.code,
    required this.type,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.deepLink,
    required this.targetId,
    required this.createdByCurrentUser,
    required this.payload,
    this.expiresAt,
    this.createdAt,
  });

  factory ShareResolveResult.fromJson(Map<String, dynamic> json) {
    return ShareResolveResult(
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl:
          json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? '',
      deepLink:
          json['deepLink']?.toString() ?? json['deep_link']?.toString() ?? '',
      targetId:
          json['targetId']?.toString() ?? json['target_id']?.toString() ?? '',
      createdByCurrentUser: json['createdByCurrentUser'] == true ||
          json['created_by_current_user'] == true,
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ??
          json['expires_at']?.toString() ??
          ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ??
          json['created_at']?.toString() ??
          ''),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
