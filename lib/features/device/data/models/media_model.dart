/// 媒体库数据模型
library;

// ── MediaItem（单条图库记录）──────────────────────────────
class MediaItem {
  final int    id;
  final int    type;       // 1 图片  2 视频
  final String url;        // CDN 完整地址
  final String thumbUrl;   // 缩略图
  final int?   fileSize;
  final int?   duration;   // 视频时长（秒）
  final String userId;
  final String nickname;
  final String? deviceId;
  final DateTime createdAt;

  const MediaItem({
    required this.id,
    required this.type,
    required this.url,
    required this.thumbUrl,
    this.fileSize,
    this.duration,
    required this.userId,
    required this.nickname,
    this.deviceId,
    required this.createdAt,
  });

  bool get isVideo => type == 2;
  bool get isPhoto => type == 1;

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    // MySQL BigInt 在 Node.js 里序列化为字符串，需兼容 String 和 num 两种类型
    int _int(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
    int? _intOrNull(dynamic v) => v == null ? null : int.tryParse(v.toString());
    return MediaItem(
      id:        _int(json['id']),
      type:      _int(json['type']),
      url:       (json['url'] as String?) ?? '',
      thumbUrl:  (json['thumb_url'] as String?)
                   ?? (json['thumbUrl'] as String?)
                   ?? (json['url'] as String?) ?? '',
      fileSize:  _intOrNull(json['file_size'] ?? json['fileSize']),
      duration:  _intOrNull(json['duration']),
      userId:    json['user_id']?.toString() ?? '',
      nickname:  (json['nickname'] as String?) ?? '用户',
      deviceId:  json['device_id']?.toString() ?? json['deviceId']?.toString(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// ── MediaListResult（分页结果）──────────────────────────────
class MediaListResult {
  final int total;
  final int page;
  final int pageSize;
  final List<MediaItem> list;

  const MediaListResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.list,
  });

  factory MediaListResult.fromJson(Map<String, dynamic> json) {
    int _int(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
    return MediaListResult(
      total:    _int(json['total']),
      page:     _int(json['page']),
      pageSize: _int(json['pageSize']),
      list:     ((json['list'] as List<dynamic>?) ?? [])
          .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasMore => list.length >= pageSize && (page * pageSize) < total;
}

// ── SaveMediaResult（保存后响应）────────────────────────────
class SaveMediaResult {
  final bool   success;
  final int    id;
  final String thumbUrl;

  const SaveMediaResult({
    required this.success,
    required this.id,
    required this.thumbUrl,
  });

  factory SaveMediaResult.fromJson(Map<String, dynamic> json) => SaveMediaResult(
    success:  (json['success'] as bool?) ?? false,
    id:       (json['id'] as num?)?.toInt() ?? 0,
    thumbUrl: (json['thumbUrl'] as String?) ?? '',
  );
}
