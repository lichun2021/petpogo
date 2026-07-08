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
    if ((state.hasLoaded && state.pets.isNotEmpty) || state.isLoading) {
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
      final petRepo = _ref.read(petPeerRepositoryProvider);

      // 使用新接口 /pet/info/list — 直接获取用户所有宠物，不依赖设备
      debugPrint('[萌宠圈][宠物] 调用 /pet/info/list');
      final pets = await petRepo.fetchPetList();
      debugPrint('[萌宠圈][宠物] 宠物列表返回 count=${pets.length}');

      // 获取设备列表用于关联显示
      final deviceState = await _ensureDevices();
      debugPrint(
          '[萌宠圈][宠物] 设备列表 count=${deviceState.devices.length}');

      // 构建 deviceId -> DeviceModel 映射
      final deviceMap = <String, DeviceModel>{};
      for (final device in deviceState.devices) {
        if (device.deviceId.isNotEmpty) {
          deviceMap[device.deviceId] = device;
        }
      }

      // 将宠物与设备关联
      final petList = <PetCirclePet>[];
      for (final pet in pets) {
        if (pet.petId.isNotEmpty && pet.petName.isNotEmpty) {
          // 如果有设备ID，尝试查找设备
          DeviceModel? device;
          if (pet.deviceId.isNotEmpty) {
            device = deviceMap[pet.deviceId];
            if (device == null) {
              debugPrint(
                  '[萌宠圈][宠物] 警告: 宠物 ${pet.petName} 的设备ID ${pet.deviceId} 在设备列表中未找到');
            }
          }

          // 显示所有宠物（包括未绑定设备的）
          // 如果没有找到设备，创建一个虚拟设备用于显示
          if (device == null && pet.deviceId.isNotEmpty) {
            // 有deviceId但找不到设备，创建虚拟设备
            device = DeviceModel(
              deviceId: pet.deviceId,
              mac: '',
              name: '未知设备',
              productKey: '',
              uType: '3', // 成员
            );
          } else if (device == null && pet.deviceId.isEmpty) {
            // 未绑定设备，创建虚拟设备
            device = DeviceModel(
              deviceId: '',
              mac: '',
              name: '未绑定设备',
              productKey: '',
              uType: '3',
            );
          }

          if (device != null) {
            petList.add(PetCirclePet(pet: pet, device: device));
            debugPrint(
                '[萌宠圈][宠物] 添加宠物 petId=${pet.petId} name=${pet.petName} device=${device.displayName}');
          }
        }
      }

      state = state.copyWith(
        pets: petList,
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
