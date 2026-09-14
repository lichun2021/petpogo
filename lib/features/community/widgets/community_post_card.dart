import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_fonts.dart';
import '../../../shared/theme/app_tokens.dart';
import '../data/models/post_model.dart';

// ── 帖子卡片（接真实数据）────────────────────────────────────
class CommunityPostCard extends StatelessWidget {
  final PostModel post;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLike; // null = 自己的帖子，禁止点赞

  const CommunityPostCard({
    super.key,
    required this.post,
    required this.index,
    required this.onTap,
    required this.onAvatarTap,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.cardRadius,
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 封面图（不用 Hero，避免新帖刷新时 iOS 出现白色占位框）──
            if (post.thumbnailUrl != null)
              _Thumbnail(
                  url: post.thumbnailUrl!,
                  isVideo: post.mediaType == MediaType.video),

            // ── 底部信息 ──────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 作者 + 点赞
                    Row(children: [
                      GestureDetector(
                        onTap: onAvatarTap,
                        child: _SmallAvatar(
                            url: post.userAvatar, name: post.nickname),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: onAvatarTap,
                          child: Text(post.nickname,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: AppFonts.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface)),
                        ),
                      ),
                      GestureDetector(
                        onTap: onLike, // null 时 GestureDetector 不响应
                        child: Row(children: [
                          Icon(
                            post.isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            // 自己帖子(onLike==null)：置灰；已点赞：红色；未点赞：浅灰
                            color: onLike == null
                                ? AppColors.onSurfaceVariant.withOpacity(0.25)
                                : post.isLiked
                                    ? AppColors.error
                                    : AppColors.onSurfaceVariant
                                        .withOpacity(0.5),
                            size: 16,
                          ),
                          SizedBox(width: 2),
                          Text('${post.likeCount}',
                              style: TextStyle(
                                fontSize: 11,
                                color: onLike == null
                                    ? AppColors.onSurfaceVariant
                                        .withOpacity(0.3)
                                    : AppColors.onSurfaceVariant,
                              )),
                        ]),
                      ),
                    ]),

                    if (post.content.isNotEmpty) ...[
                      SizedBox(height: 6),
                      Text(post.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                              height: 1.4)),
                    ],
                  ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 封面图（带视频图标，固定宽高比 3:4 保证卡片等高）──────────
class _Thumbnail extends StatelessWidget {
  final String url;
  final bool isVideo;
  const _Thumbnail({required this.url, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (_, __) =>
                Container(color: AppColors.surfaceContainerHigh),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.surfaceContainerHigh,
              child: Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.onSurfaceVariant, size: 32),
              ),
            ),
          ),
        ),
        // ── 视频播放图标（居中大按钮）────────────────
        if (isVideo)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.7), width: 2),
            ),
            child:
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
          ),
        // ── 视频标签（右上角小标）────────────────────
        if (isVideo)
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.videocam_rounded, color: Colors.white, size: 11),
                SizedBox(width: 2),
                Text('视频',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ],
    );
  }
}

// ── 小头像 ───────────────────────────────────────────────────
class _SmallAvatar extends StatelessWidget {
  final String? url;
  final String name;
  const _SmallAvatar({this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
          radius: 12, backgroundImage: CachedNetworkImageProvider(url!));
    }
    return CircleAvatar(
      radius: 12,
      backgroundColor: AppColors.primaryContainer,
      child: Text(name.isNotEmpty ? name[0] : '?',
          style: TextStyle(
              fontSize: 10,
              color: AppColors.primary,
              fontWeight: FontWeight.w700)),
    );
  }
}
