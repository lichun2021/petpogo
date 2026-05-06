import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/post_model.dart';
import '../data/post_repository.dart';

// ── Feed 状态 ────────────────────────────────────────────
class FeedState {
  final List<PostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int page;

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.page = 1,
  });

  FeedState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? page,
  }) => FeedState(
    posts:         posts         ?? this.posts,
    isLoading:     isLoading     ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore:       hasMore       ?? this.hasMore,
    error:         error,
    page:          page          ?? this.page,
  );
}

// ── Feed Controller ─────────────────────────────────────
class FeedController extends StateNotifier<FeedState> {
  final PostRepository _repo;
  static const _pageSize = 20;

  FeedController(this._repo) : super(const FeedState()) {
    loadFeed();
  }

  Future<void> loadFeed() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final posts = await _repo.fetchFeed(page: 1, size: _pageSize);
      state = state.copyWith(
        posts:     posts,
        isLoading: false,
        page:      1,
        hasMore:   posts.length >= _pageSize,
      );
      debugPrint('[Feed] 加载 ${posts.length} 条');
    } catch (e) {
      debugPrint('[Feed] 加载失败: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final posts = await _repo.fetchFeed(page: nextPage, size: _pageSize);
      state = state.copyWith(
        posts:         [...state.posts, ...posts],
        isLoadingMore: false,
        page:          nextPage,
        hasMore:       posts.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> refresh() => loadFeed();

  // ── 点赞（乐观更新）────────────────────────────────────
  Future<void> toggleLike(String postId) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = state.posts[idx];
    final optimistic = post.copyWith(
      isLiked:   !post.isLiked,
      likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
    );
    updatePost(idx, optimistic);
    try {
      final liked = await _repo.toggleLike(postId);
      updatePost(idx, optimistic.copyWith(isLiked: liked));
    } catch (_) {
      // 回滚
      updatePost(idx, post);
    }
  }

  void updatePost(int idx, PostModel updated) {
    final list = [...state.posts];
    list[idx] = updated;
    state = state.copyWith(posts: list);
  }

  // ── 发布后插入到顶部 ────────────────────────────────────
  void prependPost(PostModel post) {
    state = state.copyWith(posts: [post, ...state.posts]);
  }
}

final feedControllerProvider =
    StateNotifierProvider<FeedController, FeedState>((ref) {
  return FeedController(ref.watch(postRepositoryProvider));
});
