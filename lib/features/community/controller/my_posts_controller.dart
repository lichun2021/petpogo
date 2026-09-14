import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/result.dart';
import '../../auth/controller/auth_controller.dart';
import '../data/post_repository.dart';
import '../data/models/post_model.dart';

class MyPostsState {
  final List<PostModel> posts;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int page;
  final bool failedRefresh;
  final Result<void> outcome;
  const MyPostsState(
      {this.posts = const [],
      this.loading = false,
      this.loadingMore = false,
      this.hasMore = false,
      this.page = 0,
      this.failedRefresh = false,
      this.outcome = const Success<void>(null)});
}

class MyPostsController extends StateNotifier<MyPostsState> {
  final PostRepository repository;
  final String userId;
  int _generation = 0;
  MyPostsController(this.repository, this.userId)
      : super(const MyPostsState()) {
    if (userId.isNotEmpty) refresh();
  }

  Future<void> refresh() => _load(refreshing: true);
  Future<void> loadMore() => _load(refreshing: false);

  Future<void> _load({required bool refreshing}) async {
    if (userId.isEmpty ||
        (!refreshing && (state.loading || state.loadingMore || !state.hasMore)))
      return;
    final generation = refreshing ? ++_generation : _generation;
    final page = refreshing ? 1 : state.page + 1;
    state = MyPostsState(
        posts: state.posts,
        page: state.page,
        loading: refreshing,
        loadingMore: !refreshing,
        hasMore: state.hasMore);
    final result = await repository.fetchOwnPosts(userId: userId, page: page);
    if (!mounted || generation != _generation) return;
    if (result is Success<OwnPostsPage>) {
      final byId = {
        for (final post in refreshing ? <PostModel>[] : state.posts)
          post.id: post
      };
      for (final post in result.data.posts) {
        if (post.userId == userId) byId[post.id] = post;
      }
      final posts = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = MyPostsState(
          posts: List.unmodifiable(posts),
          page: page,
          hasMore: result.data.hasMore);
    } else if (result is Failure<OwnPostsPage>) {
      state = MyPostsState(
          posts: state.posts,
          page: state.page,
          hasMore: state.hasMore,
          failedRefresh: refreshing,
          outcome: Failure<void>(result.exception));
    }
  }
}

final myPostsOwnerProvider = Provider<String>((ref) => ref.watch(
    authControllerProvider
        .select((auth) => auth.isLoggedIn ? auth.user?.id ?? '' : '')));

// 账号改变时销毁旧列表，不复用其他账号的缓存。
final myPostsControllerProvider =
    StateNotifierProvider.autoDispose<MyPostsController, MyPostsState>((ref) =>
        MyPostsController(ref.watch(postRepositoryProvider),
            ref.watch(myPostsOwnerProvider)));
