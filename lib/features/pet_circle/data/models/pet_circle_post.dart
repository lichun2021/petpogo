enum PetCircleMediaType {
  text,
  image,
  video,
}

class PetCirclePost {
  final String id;
  final String ownerUserId;
  final String petId;
  final String petName;
  final String petAvatar;
  final String content;
  final PetCircleMediaType mediaType;
  final List<String> mediaUrls;
  final String coverUrl;
  final String eventType;
  final String sourceId;
  final DateTime? sourceTime;
  final DateTime createdAt;

  const PetCirclePost({
    required this.id,
    required this.ownerUserId,
    required this.petId,
    required this.petName,
    required this.petAvatar,
    required this.content,
    required this.mediaType,
    required this.mediaUrls,
    required this.coverUrl,
    required this.eventType,
    required this.sourceId,
    required this.sourceTime,
    required this.createdAt,
  });

  factory PetCirclePost.fromJson(Map<String, dynamic> json) {
    return PetCirclePost(
      id: _string(json['id']),
      ownerUserId: _string(json['ownerUserId'] ?? json['owner_user_id']),
      petId: _string(json['petId'] ?? json['pet_id']),
      petName: _string(json['petName'] ?? json['pet_name']),
      petAvatar: _string(json['petAvatar'] ?? json['pet_avatar']),
      content: _string(json['content']),
      mediaType: _mediaType(json['mediaType'] ?? json['media_type']),
      mediaUrls: _stringList(json['mediaUrls'] ?? json['media_urls']),
      coverUrl: _string(json['coverUrl'] ?? json['cover_url']),
      eventType: _string(json['eventType'] ?? json['event_type']),
      sourceId: _string(json['sourceId'] ?? json['source_id']),
      sourceTime: _date(json['sourceTime'] ?? json['source_time']),
      createdAt:
          _date(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
    );
  }

  bool get hasMedia => mediaType != PetCircleMediaType.text;

  bool get isVideo => mediaType == PetCircleMediaType.video;

  String get displayMediaUrl {
    if (coverUrl.isNotEmpty) return coverUrl;
    if (mediaUrls.isNotEmpty) return mediaUrls.first;
    return '';
  }

  static String _string(dynamic value) => value?.toString() ?? '';

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static PetCircleMediaType _mediaType(dynamic value) {
    if (value is num) {
      if (value == 1) return PetCircleMediaType.image;
      if (value == 2) return PetCircleMediaType.video;
      return PetCircleMediaType.text;
    }
    switch (value?.toString().toLowerCase()) {
      case 'image':
      case 'images':
      case '1':
        return PetCircleMediaType.image;
      case 'video':
      case '2':
        return PetCircleMediaType.video;
      default:
        return PetCircleMediaType.text;
    }
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final raw = value.toString();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }
}

class PetCircleFeedPage {
  final int total;
  final int page;
  final int pageSize;
  final List<PetCirclePost> list;

  const PetCircleFeedPage({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.list,
  });

  factory PetCircleFeedPage.fromJson(Map<String, dynamic> json) {
    final rawList = json['list'];
    return PetCircleFeedPage(
      total: int.tryParse(json['total']?.toString() ?? '') ?? 0,
      page: int.tryParse(json['page']?.toString() ?? '') ?? 1,
      pageSize: int.tryParse(json['pageSize']?.toString() ?? '') ?? 20,
      list: rawList is List
          ? rawList
              .whereType<Map>()
              .map((item) => PetCirclePost.fromJson(
                    item.cast<String, dynamic>(),
                  ))
              .toList()
          : const [],
    );
  }
}
