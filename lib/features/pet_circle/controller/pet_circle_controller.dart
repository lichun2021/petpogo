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
    if (state.selectedPetId == petId && state.posts.isNotEmpty) return;
    state = PetCircleState(selectedPetId: petId, isLoading: true);
    await _loadFirst(petId, refreshing: false);
  }

  Future<void> refresh() async {
    final petId = state.selectedPetId;
    if (petId.isEmpty || state.isRefreshing) return;
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
      },
      failure: (error) {
        state = state.copyWith(
          isLoadingMore: false,
          errorMessage: error.userMessage,
        );
      },
    );
  }

  Future<bool> deletePost(String id) async {
    final result = await _repo.deletePost(id);
    return result.when(
      success: (_) {
        state = state.copyWith(
          posts: state.posts.where((post) => post.id != id).toList(),
          errorMessage: null,
        );
        return true;
      },
      failure: (error) {
        state = state.copyWith(errorMessage: error.userMessage);
        return false;
      },
    );
  }

  Future<void> _loadFirst(String petId, {required bool refreshing}) async {
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
      },
      failure: (error) {
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
