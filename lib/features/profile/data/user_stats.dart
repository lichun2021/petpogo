/// 用户统计数据模型 — UserStats
/// 对应后端 GET /sdkapi/user/stats?userId=xxx 返回
class UserStats {
  final String userId;
  final int postCount;
  final int followerCount;
  final int likeCount;

  const UserStats({
    required this.userId,
    this.postCount = 0,
    this.followerCount = 0,
    this.likeCount = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
    userId:        (json['userId'] as String?) ?? '',
    postCount:     (json['postCount'] as num?)?.toInt() ?? 0,
    followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
    likeCount:     (json['likeCount'] as num?)?.toInt() ?? 0,
  );
}
