import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controller/auth_controller.dart';
import 'points_repository.dart';

final pointsBalanceProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final token = ref.watch(authControllerProvider.select((s) => s.user?.token));
  if (token == null || token.isEmpty) return null;
  return ref.watch(pointsRepositoryProvider).fetchBalance();
});

final checkInStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final token = ref.watch(authControllerProvider.select((s) => s.user?.token));
  if (token == null || token.isEmpty) return null;
  return ref.watch(pointsRepositoryProvider).fetchStatus();
});

int? overviewInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value');
bool overviewBool(dynamic value) =>
    value == true || value == 1 || value == 'true' || value == '1';
