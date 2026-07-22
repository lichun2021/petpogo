import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../device/data/models/device_model.dart';
import '../../device/data/repository/device_repository.dart';
import '../../pet/data/models/pet_peer_models.dart';
import '../../pet/data/repository/pet_peer_repository.dart';
import '../../pet/data/repository/pet_share_repository.dart';

/// 萌宠圈宠物来源
enum PetCircleSource {
  /// 我的宠物（/pet/info/list）
  owned,
  /// 共享给我的宠物（/pet/share/withme）
  shared,
}

class PetCirclePet {
  final PetInfoModel pet;
  final DeviceModel device;
  final PetCircleSource source;

  const PetCirclePet({
    required this.pet,
    required this.device,
    this.source = PetCircleSource.owned,
  });

  String get id => pet.petId;

  String get name => pet.petName;

  String get avatar => pet.avatar;

  /// 是否是别人共享给我的
  bool get isShared => source == PetCircleSource.shared;

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
      final shareRepo = _ref.read(petShareRepositoryProvider);

      // 并行拉取：我的宠物 + 共享给我的宠物
      // 两个接口理论上不会返回同一只宠物（一个是我创建的，一个是别人共享给我的）
      debugPrint('[萌宠圈][宠物] 并行调用 /pet/info/list + /pet/share/withme');
      final results = await Future.wait([
        petRepo.fetchPetList().catchError((e) {
          debugPrint('[萌宠圈][宠物] /pet/info/list 失败: $e');
          return const <PetInfoModel>[];
        }),
        shareRepo.fetchSharedPets(pageNo: 1, pageSize: 20).catchError((e) {
          debugPrint('[萌宠圈][宠物] /pet/share/withme 失败: $e');
          return const <PetInfoModel>[];
        }),
      ]);
      final myPets = results[0];
      final sharedPets = results[1];
      debugPrint(
          '[萌宠圈][宠物] 我的=${myPets.length} 共享=${sharedPets.length}');

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

      // 按 petId 去重合并：我的宠物优先，共享宠物追加（理论上不会重复）
      final seen = <String>{};
      final petList = <PetCirclePet>[];

      // 1. 先放我的宠物
      for (final pet in myPets) {
        if (pet.petId.isEmpty || pet.petName.isEmpty) continue;
        if (!seen.add(pet.petId)) continue; // 去重
        final device = _resolveDevice(pet, deviceMap);
        if (device != null) {
          petList.add(PetCirclePet(
              pet: pet, device: device, source: PetCircleSource.owned));
        }
      }
      // 2. 再放共享宠物
      for (final pet in sharedPets) {
        if (pet.petId.isEmpty || pet.petName.isEmpty) continue;
        if (!seen.add(pet.petId)) continue; // 去重（理论上不会命中）
        final device = _resolveDevice(pet, deviceMap);
        if (device != null) {
          petList.add(PetCirclePet(
              pet: pet, device: device, source: PetCircleSource.shared));
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

  /// 强制刷新（下拉刷新用）：清除缓存标志重新拉取
  Future<void> refresh() async {
    debugPrint('[萌宠圈][宠物] 强制刷新');
    state = state.copyWith(hasLoaded: false);
    await load();
  }

  /// 解析宠物关联的设备（找不到则创建虚拟设备）
  DeviceModel? _resolveDevice(
      PetInfoModel pet, Map<String, DeviceModel> deviceMap) {
    if (pet.deviceId.isNotEmpty) {
      final device = deviceMap[pet.deviceId];
      if (device != null) return device;
      // 有 deviceId 但设备列表里没有，创建虚拟设备
      debugPrint(
          '[萌宠圈][宠物] 警告: 宠物 ${pet.petName} 的设备ID ${pet.deviceId} 在设备列表中未找到');
      return DeviceModel(
        deviceId: pet.deviceId,
        mac: '',
        name: '未知设备',
        productKey: '',
        uType: '3',
      );
    }
    // 未绑定设备，创建虚拟设备
    return DeviceModel(
      deviceId: '',
      mac: '',
      name: '未绑定设备',
      productKey: '',
      uType: '3',
    );
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
