import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/pet_circle_post.dart';
import '../data/repository/pet_circle_repository.dart';

class PetCircleState {
  final String selectedPetId;
  final List<PetCirclePost> posts;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final String? errorMessage;

  const PetCircleState({
    this.selectedPetId = '',
    this.posts = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.errorMessage,
  });

  PetCircleState copyWith({
    String? selectedPetId,
    List<PetCirclePost>? posts,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? errorMessage,
  }) {
    return PetCircleState(
      selectedPetId: selectedPetId ?? this.selectedPetId,
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorMessage: errorMessage,
    );
  }
}

class PetCircleController extends StateNotifier<PetCircleState> {
  final PetCircleRepository _repo;
  static const _pageSize = 20;

  PetCircleController(this._repo) : super(const PetCircleState());

  Future<void> selectPet(String petId) async {
    if (petId.isEmpty) return;
    if (state.selectedPetId == petId && state.posts.isNotEmpty) {
      debugPrint('[萌宠圈][动态] 跳过选中 petId=$petId posts=${state.posts.length}');
      return;
    }
    debugPrint('[萌宠圈][动态] 选择宠物 petId=$petId');
    state = PetCircleState(selectedPetId: petId, isLoading: true);
    await _loadFirst(petId, refreshing: false);
  }

  Future<void> refresh() async {
    final petId = state.selectedPetId;
    if (petId.isEmpty || state.isRefreshing) return;
    debugPrint('[萌宠圈][动态] 下拉刷新 petId=$petId');
    state = state.copyWith(isRefreshing: true, errorMessage: null);
    await _loadFirst(petId, refreshing: true);
  }

  Future<void> loadMore() async {
    if (state.selectedPetId.isEmpty ||
        state.isLoadingMore ||
        state.isLoading ||
        !state.hasMore) {
      return;
    }

    final nextPage = state.page + 1;
    debugPrint(
        '[萌宠圈][动态] 加载更多 petId=${state.selectedPetId} page=$nextPage pageSize=$_pageSize');
    state = state.copyWith(isLoadingMore: true, errorMessage: null);
    final result = await _repo.fetchFeed(
      petId: state.selectedPetId,
      page: nextPage,
      pageSize: _pageSize,
    );

    result.when(
      success: (data) {
        state = state.copyWith(
          posts: [...state.posts, ...data.list],
          page: nextPage,
          hasMore: data.list.length >= _pageSize,
          isLoadingMore: false,
          errorMessage: null,
        );
        debugPrint(
            '[萌宠圈][动态] 加载更多成功 page=$nextPage add=${data.list.length} totalPosts=${state.posts.length} hasMore=${state.hasMore}');
      },
      failure: (error) {
        debugPrint('[萌宠圈][动态] 加载更多失败: ${error.userMessage}');
        state = state.copyWith(
          isLoadingMore: false,
          errorMessage: error.userMessage,
        );
      },
    );
  }

  Future<bool> deletePost(String id) async {
    debugPrint('[萌宠圈][动态] 删除动态 id=$id');
    final result = await _repo.deletePost(id);
    return result.when(
      success: (_) {
        state = state.copyWith(
          posts: state.posts.where((post) => post.id != id).toList(),
          errorMessage: null,
        );
        debugPrint('[萌宠圈][动态] 删除成功 id=$id remain=${state.posts.length}');
        return true;
      },
      failure: (error) {
        debugPrint('[萌宠圈][动态] 删除失败 id=$id error=${error.userMessage}');
        state = state.copyWith(errorMessage: error.userMessage);
        return false;
      },
    );
  }

  Future<void> _loadFirst(String petId, {required bool refreshing}) async {
    debugPrint(
        '[萌宠圈][动态] 请求首页 petId=$petId page=1 pageSize=$_pageSize refreshing=$refreshing');
    final result = await _repo.fetchFeed(
      petId: petId,
      page: 1,
      pageSize: _pageSize,
    );

    result.when(
      success: (data) {
        state = state.copyWith(
          selectedPetId: petId,
          posts: data.list,
          page: 1,
          hasMore: data.list.length >= _pageSize,
          isLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          errorMessage: null,
        );
        debugPrint(
            '[萌宠圈][动态] 首页成功 petId=$petId count=${data.list.length} total=${data.total} hasMore=${state.hasMore}');
      },
      failure: (error) {
        debugPrint('[萌宠圈][动态] 首页失败 petId=$petId error=${error.userMessage}');
        state = state.copyWith(
          selectedPetId: petId,
          isLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          errorMessage: error.userMessage,
        );
      },
    );
  }
}

final petCircleControllerProvider =
    StateNotifierProvider<PetCircleController, PetCircleState>((ref) {
  return PetCircleController(ref.watch(petCircleRepositoryProvider));
});
