import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/result.dart';
import 'user_stats.dart';

class UserStatsState {
  final UserStats? stats;
  final bool isLoading;
  final String? errorMessage;

  const UserStatsState({
    this.stats,
    this.isLoading = false,
    this.errorMessage,
  });

  UserStatsState copyWith({
    UserStats? stats,
    bool? isLoading,
    String? errorMessage,
  }) => UserStatsState(
    stats:        stats        ?? this.stats,
    isLoading:    isLoading    ?? this.isLoading,
    errorMessage: errorMessage,
  );
}

class UserStatsNotifier extends StateNotifier<UserStatsState> {
  final ApiClient _client;
  UserStatsNotifier(this._client) : super(const UserStatsState());

  /// 获取自己的统计（不传 userId）
  Future<void> loadMyStats() => _load(null);

  /// 获取他人的统计
  Future<void> loadUserStats(String userId) => _load(userId);

  Future<void> _load(String? userId) async {
    state = state.copyWith(isLoading: true);
    final result = await guardResult(() async {
      final params = userId != null ? {'userId': userId} : null;
      final data = await _client.get<Map<String, dynamic>>(
        '/sdkapi/user/stats',
        params: params,
      );
      return UserStats.fromJson(data);
    });
    result.when(
      success: (s) => state = state.copyWith(stats: s, isLoading: false),
      failure: (e) => state = state.copyWith(isLoading: false, errorMessage: e.userMessage),
    );
  }
}

final userStatsProvider =
    StateNotifierProvider<UserStatsNotifier, UserStatsState>((ref) {
  return UserStatsNotifier(ref.read(apiClientProvider));
});
