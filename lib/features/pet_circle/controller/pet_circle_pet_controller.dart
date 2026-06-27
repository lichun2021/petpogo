import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../device/data/models/device_model.dart';
import '../../device/data/repository/device_repository.dart';
import '../../pet/data/models/pet_peer_models.dart';
import '../../pet/data/repository/pet_peer_repository.dart';

class PetCirclePet {
  final PetInfoModel pet;
  final DeviceModel device;

  const PetCirclePet({
    required this.pet,
    required this.device,
  });

  String get id => pet.petId;

  String get name => pet.petName;

  String get avatar => pet.avatar;

  String get emoji {
    final breed = pet.breed.toLowerCase();
    if (breed.contains('cat') || pet.breed.contains('猫')) return '🐱';
    if (breed.contains('dog') ||
        pet.breed.contains('犬') ||
        pet.breed.contains('狗')) {
      return '🐶';
    }
    return '🐾';
  }
}

class PetCirclePetState {
  final List<PetCirclePet> pets;
  final bool isLoading;
  final bool hasLoaded;
  final String? errorMessage;

  const PetCirclePetState({
    this.pets = const [],
    this.isLoading = false,
    this.hasLoaded = false,
    this.errorMessage,
  });

  PetCirclePetState copyWith({
    List<PetCirclePet>? pets,
    bool? isLoading,
    bool? hasLoaded,
    String? errorMessage,
  }) {
    return PetCirclePetState(
      pets: pets ?? this.pets,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      errorMessage: errorMessage,
    );
  }
}

class PetCirclePetController extends StateNotifier<PetCirclePetState> {
  final Ref _ref;

  PetCirclePetController(this._ref) : super(const PetCirclePetState());

  Future<void> loadIfNeeded() async {
    if (state.hasLoaded || state.isLoading) {
      debugPrint(
          '[萌宠圈][宠物] 跳过加载 hasLoaded=${state.hasLoaded} isLoading=${state.isLoading} count=${state.pets.length}');
      return;
    }
    await load();
  }

  Future<void> load() async {
    debugPrint('[萌宠圈][宠物] 开始加载宠物列表');
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final deviceState = await _ensureDevices();
      debugPrint(
          '[萌宠圈][宠物] 设备列表 ready count=${deviceState.devices.length} error=${deviceState.errorMessage ?? '-'}');
      if (deviceState.errorMessage != null && deviceState.devices.isEmpty) {
        throw Exception(deviceState.errorMessage);
      }

      final petRepo = _ref.read(petPeerRepositoryProvider);

      final loadedPets =
          await Future.wait(deviceState.devices.map((device) async {
        try {
          debugPrint(
              '[萌宠圈][宠物] 请求宠物信息 device=${device.displayName} deviceId=${device.deviceId} mac=${device.mac}');
          final pet = await petRepo.fetchPetInfo(
            deviceId: device.deviceId.isEmpty ? null : device.deviceId,
            mac: device.deviceId.isEmpty ? device.mac : null,
          );
          debugPrint(
              '[萌宠圈][宠物] 宠物信息返回 device=${device.displayName} petId=${pet.petId} name=${pet.petName} avatar=${pet.avatar.isNotEmpty}');
          if (pet.petId.isNotEmpty && pet.petName.isNotEmpty) {
            return PetCirclePet(pet: pet, device: device);
          }
        } catch (e) {
          debugPrint('[萌宠圈] 设备 ${device.displayName} 未绑定宠物或读取失败: $e');
        }
        return null;
      }));

      state = state.copyWith(
        pets: loadedPets.whereType<PetCirclePet>().toList(),
        isLoading: false,
        hasLoaded: true,
        errorMessage: null,
      );
      debugPrint(
          '[萌宠圈][宠物] 加载完成 count=${state.pets.length} ids=${state.pets.map((e) => e.id).join(',')}');
    } catch (e) {
      debugPrint('[萌宠圈][宠物] 加载失败: $e');
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        errorMessage: e.toString(),
      );
    }
  }

  Future<DeviceListState> _ensureDevices() async {
    var deviceState = _ref.read(deviceListProvider);
    debugPrint(
        '[萌宠圈][设备] 当前缓存 count=${deviceState.devices.length} loading=${deviceState.isLoading}');
    if (deviceState.devices.isEmpty && !deviceState.isLoading) {
      debugPrint('[萌宠圈][设备] 缓存为空，开始请求设备列表');
      await _ref.read(deviceListProvider.notifier).load();
      deviceState = _ref.read(deviceListProvider);
      debugPrint(
          '[萌宠圈][设备] 设备列表请求完成 count=${deviceState.devices.length} error=${deviceState.errorMessage ?? '-'}');
      return deviceState;
    }

    if (deviceState.isLoading) {
      debugPrint('[萌宠圈][设备] 设备列表正在加载，等待完成');
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (_ref.read(deviceListProvider).isLoading &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      deviceState = _ref.read(deviceListProvider);
      debugPrint(
          '[萌宠圈][设备] 等待结束 count=${deviceState.devices.length} loading=${deviceState.isLoading} error=${deviceState.errorMessage ?? '-'}');
    }

    return deviceState;
  }
}

final petCirclePetControllerProvider =
    StateNotifierProvider<PetCirclePetController, PetCirclePetState>((ref) {
  return PetCirclePetController(ref);
});
