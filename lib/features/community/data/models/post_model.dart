/// 帖子数据模型
library;

enum MediaType {
  none,   // 纯文字
  image,  // 图片
  video,  // 视频
}

class PostModel {
  final String id;
  final String content;
  final MediaType mediaType;
  final List<String> mediaUrls;
  final String? videoUrl;
  final String? coverUrl;
  final double? duration;
  final String? location;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final DateTime createdAt;

  // 作者
  final String userId;
  final String nickname;
  final String? userAvatar;

  // 本地临时状态（不来自接口）
  final bool isLiked;

  const PostModel({
    required this.id,
    required this.content,
    required this.mediaType,
    required this.mediaUrls,
    this.videoUrl,
    this.coverUrl,
    this.duration,
    this.location,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    required this.createdAt,
    required this.userId,
    required this.nickname,
    this.userAvatar,
    this.isLiked = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final mt = (json['media_type'] as int?) ?? 0;
    return PostModel(
      id:           json['id'] as String,
      content:      (json['content'] as String?) ?? '',
      mediaType:    mt == 1 ? MediaType.image : mt == 2 ? MediaType.video : MediaType.none,
      mediaUrls:    _parseUrls(json['media_urls']),
      videoUrl:     json['video_url'] as String?,
      coverUrl:     json['cover_url'] as String?,
      duration:     (json['duration'] as num?)?.toDouble(),
      location:     json['location'] as String?,
      likeCount:    (json['like_count'] as int?) ?? 0,
      commentCount: (json['comment_count'] as int?) ?? 0,
      viewCount:    (json['view_count'] as int?) ?? 0,
      createdAt:    DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      userId:       json['user_id'] as String,
      nickname:     (json['nickname'] as String?) ?? '用户',
      userAvatar:   json['user_avatar'] as String?,
      isLiked:      (json['is_liked'] as bool?) ?? false,
    );
  }

  PostModel copyWith({
    bool? isLiked,
    int? likeCount,
    int? commentCount,
  }) => PostModel(
    id:           id,
    content:      content,
    mediaType:    mediaType,
    mediaUrls:    mediaUrls,
    videoUrl:     videoUrl,
    coverUrl:     coverUrl,
    duration:     duration,
    location:     location,
    likeCount:    likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    viewCount:    viewCount,
    createdAt:    createdAt,
    userId:       userId,
    nickname:     nickname,
    userAvatar:   userAvatar,
    isLiked:      isLiked ?? this.isLiked,
  );

  /// 封面图（视频取 coverUrl，图片取第一张，无则 null）
  String? get thumbnailUrl {
    if (mediaType == MediaType.video) return coverUrl;
    if (mediaUrls.isNotEmpty) return mediaUrls.first;
    return null;
  }

  /// 是否有媒体内容
  bool get hasMedia => mediaType != MediaType.none;

  static List<String> _parseUrls(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }
}

/// 评论模型
class CommentModel {
  final String id;
  final String content;
  final int likeCount;
  final DateTime createdAt;
  final String userId;
  final String nickname;
  final String? userAvatar;

  const CommentModel({
    required this.id,
    required this.content,
    required this.likeCount,
    required this.createdAt,
    required this.userId,
    required this.nickname,
    this.userAvatar,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) => CommentModel(
    id:         json['id'] as String,
    content:    (json['content'] as String?) ?? '',
    likeCount:  (json['like_count'] as int?) ?? 0,
    createdAt:  DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    userId:     json['user_id'] as String,
    nickname:   (json['nickname'] as String?) ?? '用户',
    userAvatar: json['avatar'] as String?,
  );
}

/// OSS 签名响应
class OssSignResult {
  final String uploadUrl;
  final String key;
  final String cdnUrl;

  const OssSignResult({
    required this.uploadUrl,
    required this.key,
    required this.cdnUrl,
  });

  factory OssSignResult.fromJson(Map<String, dynamic> json) => OssSignResult(
    uploadUrl: json['uploadUrl'] as String,
    key:       json['key'] as String,
    cdnUrl:    json['cdnUrl'] as String,
  );
}
