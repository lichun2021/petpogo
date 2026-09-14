import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import 'models/post_model.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/result.dart';

class PostRepository {
  final ApiClient _client;
  PostRepository(this._client);

  /// 复用按作者 ID 列表查询的接口，仅传当前账号；翻页发生在服务端。
  Future<Result<OwnPostsPage>> fetchOwnPosts(
          {required String userId, int page = 1, int size = 20}) =>
      guardResult(() async {
        if (userId.isEmpty)
          return const OwnPostsPage(posts: [], hasMore: false);
        final data = await _client.post<Map<String, dynamic>>(
          ApiEndpoints.postAuthorsFeed,
          data: {
            'friendIds': [userId],
            'page': page,
            'size': size
          },
        );
        final raw = (data['list'] as List?) ?? const [];
        final posts = raw
            .whereType<Map>()
            .map((item) => PostModel.fromJson(item.cast<String, dynamic>()))
            .where((post) => post.userId == userId)
            .toList();
        // 防止服务端异常返回其他作者；hasMore 根据原始分页长度判断。
        return OwnPostsPage(posts: posts, hasMore: raw.length >= size);
      });

  // ── Feed 分页 ──────────────────────────────────────────
  /// 发现流（全站最新）
  Future<List<PostModel>> fetchFeed(
      {int page = 1, int size = 20, String? tag}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/sdkapi/post/feed',
      params: {
        'page': page,
        'size': size,
        if (tag != null) 'tag': tag,
      },
    );
    final list = res['list'] as List<dynamic>? ?? [];
    return list
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 好友流（好友+自己的帖子）
  Future<List<PostModel>> fetchFriendFeed({
    required List<String> friendIds,
    int page = 1,
    int size = 20,
    String? tag,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.postAuthorsFeed,
      data: {
        'friendIds': friendIds,
        'page': page,
        'size': size,
        if (tag != null) 'tag': tag,
      },
    );
    final list = res['list'] as List<dynamic>? ?? [];
    return list
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── 发布帖子 ────────────────────────────────────────────
  Future<Map<String, dynamic>> createPost({
    required String content,
    required MediaType mediaType,
    List<String>? mediaUrls,
    String? videoUrl,
    String? coverUrl,
    String? rawVideoKey,
    String? location,
    String? tag,
  }) async {
    return await _client.post<Map<String, dynamic>>(
      '/sdkapi/post/create',
      data: {
        'content': content,
        'mediaType': mediaType == MediaType.image
            ? 1
            : mediaType == MediaType.video
                ? 2
                : 0,
        'mediaUrls': mediaUrls,
        'videoUrl': videoUrl,
        'coverUrl': coverUrl,
        'rawVideoKey': rawVideoKey,
        'location': location,
        'visibility': 1,
        // 分类标签（后端字段 tag）
        if (tag != null) 'tag': tag,
      },
    );
  }

  // ── 点赞 / 取消点赞 ─────────────────────────────────────
  Future<bool> toggleLike(String postId) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/sdkapi/post/$postId/like',
    );
    return (res['liked'] as bool?) ?? false;
  }

  // ── 评论列表 ────────────────────────────────────────────
  Future<List<CommentModel>> fetchComments(String postId,
      {int page = 1}) async {
    final res = await _client.get<List<dynamic>>(
      '/sdkapi/post/$postId/comments',
      params: {'page': page, 'size': 20},
    );
    return res
        .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── 发表评论 ────────────────────────────────────────────
  Future<void> addComment(String postId, String content) async {
    await _client.post<Map<String, dynamic>>(
      '/sdkapi/post/$postId/comment',
      data: {'content': content},
    );
  }

  // ── 获取 OSS 预签名 ─────────────────────────────────────
  Future<OssSignResult> getOssSign(
      {required String fileType, String folder = 'posts'}) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/sdkapi/upload/sign',
      data: {'fileType': fileType, 'folder': folder},
    );
    return OssSignResult.fromJson(res);
  }

  // ── 直传 OSS（PUT） ─────────────────────────────────────
  // NOTE: OSS 预签名 URL v1 签名把 Content-Type 纳入 HMAC 计算。
  //       若后端签名时 Content-Type 为空（常见做法），客户端再发
  //       Content-Type 头会导致签名不匹配 → 403。故此处不发 Content-Type。
  Future<void> uploadToOss({
    required String uploadUrl,
    required File file,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final dio = Dio();
    final bytes = await file.readAsBytes();
    debugPrint('[OSS] 开始上传 ${bytes.length} bytes → $uploadUrl');
    try {
      final resp = await dio.put(
        uploadUrl,
        data: bytes,
        options: Options(
          // ⚠️ 不发 Content-Type，避免与预签名中的签名字符串不匹配
          headers: const <String, dynamic>{},
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
          validateStatus: (status) => status != null && status < 400,
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );
      debugPrint('[OSS] 上传成功 status=${resp.statusCode}');
    } on DioException catch (e) {
      // 打印 OSS 返回的 XML 错误体，方便排查
      debugPrint('[OSS] 上传失败 status=${e.response?.statusCode}');
      debugPrint('[OSS] 错误响应体: ${e.response?.data}');
      rethrow;
    }
  }
}

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(ref.watch(apiClientProvider));
});

class OwnPostsPage {
  final List<PostModel> posts;
  final bool hasMore;
  const OwnPostsPage({required this.posts, required this.hasMore});
}
