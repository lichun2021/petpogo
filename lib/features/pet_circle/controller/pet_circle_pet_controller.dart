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
    if (state.hasLoaded || state.isLoading) return;
    await load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final deviceState = await _ensureDevices();
      if (deviceState.errorMessage != null && deviceState.devices.isEmpty) {
        throw Exception(deviceState.errorMessage);
      }

      final petRepo = _ref.read(petPeerRepositoryProvider);

      final loadedPets =
          await Future.wait(deviceState.devices.map((device) async {
        try {
          final pet = await petRepo.fetchPetInfo(
            deviceId: device.deviceId.isEmpty ? null : device.deviceId,
            mac: device.deviceId.isEmpty ? device.mac : null,
          );
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
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        errorMessage: e.toString(),
      );
    }
  }

  Future<DeviceListState> _ensureDevices() async {
    var deviceState = _ref.read(deviceListProvider);
    if (deviceState.devices.isEmpty && !deviceState.isLoading) {
      await _ref.read(deviceListProvider.notifier).load();
      return _ref.read(deviceListProvider);
    }

    if (deviceState.isLoading) {
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (_ref.read(deviceListProvider).isLoading &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      deviceState = _ref.read(deviceListProvider);
    }

    return deviceState;
  }
}

final petCirclePetControllerProvider =
    StateNotifierProvider<PetCirclePetController, PetCirclePetState>((ref) {
  return PetCirclePetController(ref);
});
