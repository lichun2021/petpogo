import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/result.dart';
import '../models/device_model.dart';

class DeviceRepository {
  final ApiClient _client;
  DeviceRepository(this._client);

  Future<Result<List<DeviceModel>>> fetchDevices() => guardResult(() async {
    final data = await _client.get<List<dynamic>>('/sdkapi/device/list');
    return data
        .map((e) => DeviceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  });
}

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(ref.read(apiClientProvider));
});

// ── 设备列表 StateNotifier ─────────────────────────────────
class DeviceListState {
  final List<DeviceModel> devices;
  final bool isLoading;
  final String? errorMessage;

  const DeviceListState({
    this.devices = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  DeviceListState copyWith({
    List<DeviceModel>? devices,
    bool? isLoading,
    String? errorMessage,
  }) => DeviceListState(
    devices:      devices      ?? this.devices,
    isLoading:    isLoading    ?? this.isLoading,
    errorMessage: errorMessage,
  );
}

class DeviceListNotifier extends StateNotifier<DeviceListState> {
  final DeviceRepository _repo;
  DeviceListNotifier(this._repo) : super(const DeviceListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final result = await _repo.fetchDevices();
    result.when(
      success: (list) => state = state.copyWith(devices: list, isLoading: false),
      failure: (err)  => state = state.copyWith(isLoading: false, errorMessage: err.userMessage),
    );
  }
}

final deviceListProvider =
    StateNotifierProvider<DeviceListNotifier, DeviceListState>((ref) {
  return DeviceListNotifier(ref.read(deviceRepositoryProvider));
});
