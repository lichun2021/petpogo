import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/providers/account_session_provider.dart';
import 'package:petpogo_app/features/device/controller/device_actions.dart';
import 'package:petpogo_app/features/device/data/models/device_model.dart';
import 'package:petpogo_app/features/device/data/models/device_product_model.dart';
import 'package:petpogo_app/features/device/data/repository/device_repository.dart';
import 'package:petpogo_app/features/pet/controller/pet_controller.dart';
import 'package:petpogo_app/features/pet/data/models/pet_model.dart';
import 'package:petpogo_app/features/pet/data/models/pet_peer_models.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_peer_repository.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_repository.dart';
import 'package:petpogo_app/features/pet_circle/controller/pet_circle_pet_controller.dart';

const _device = DeviceModel(deviceId: 'device-1', mac: 'AA:BB', name: '项圈');
const _pet = PetInfoModel(petId: 'pet-1', petName: '毛毛', deviceId: 'device-1');

class _Devices implements DeviceRepository {
  List<DeviceModel> items = [_device];
  Completer<bool>? online;
  Completer<void>? unbind;
  int fetches = 0;
  int unbinds = 0;
  bool failUnbind = false;
  @override
  Future<List<DeviceProductModel>> fetchProducts() async => [];
  @override
  Future<List<DeviceModel>> fetchDevices() async {
    fetches++;
    return items;
  }

  @override
  Future<bool> fetchOnlineState(String mac) =>
      online?.future ?? Future.value(false);
  @override
  Future<DeviceDetailModel> fetchDeviceDetail(String mac) async =>
      const DeviceDetailModel();
  @override
  Future<void> unbindDevice(String mac) async {
    unbinds++;
    if (failUnbind) throw StateError('offline');
    await unbind?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pets implements PetPeerRepository {
  Completer<void>? deletion;
  bool failList = false;
  @override
  Future<void> deletePet({String? petId, String? deviceId}) async =>
      deletion?.future;
  @override
  Future<List<PetInfoModel>> fetchPetList() async {
    if (failList) throw StateError('offline');
    return [_pet];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PetState extends PetController {
  _PetState(super.repo, {required super.peerRepo}) {
    state = const PetState(pets: [
      PetModel(id: 'pet-1', name: '毛毛', type: 'cat', linkedDeviceId: 'device-1')
    ]);
  }
}

class _CirclePets extends PetCirclePetController {
  _CirclePets(super.ref) {
    state = const PetCirclePetState(
        hasLoaded: true, pets: [PetCirclePet(pet: _pet, device: _device)]);
  }
}

void main() {
  test('confirmed removal is immediate and stale lists cannot restore it',
      () async {
    final repo = _Devices();
    final notifier = DeviceListNotifier(repo);
    addTearDown(notifier.dispose);
    await notifier.load();
    notifier.removeDevice('aa:bb');
    expect(notifier.state.devices, isEmpty);
    expect(notifier.state.removedDeviceIds, contains('device-1'));
    await notifier.load();
    expect(notifier.state.devices, isEmpty);
    notifier.allowDevice('aa:bb');
    await notifier.load();
    expect(notifier.state.devices.single.deviceId, 'device-1');
  });

  test('a late online-state response cannot resurrect an unbound device',
      () async {
    final repo = _Devices()..online = Completer<bool>();
    final notifier = DeviceListNotifier(repo);
    addTearDown(notifier.dispose);
    final pending = notifier.load();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.devices, hasLength(1));
    notifier.removeDevice(_device.mac);
    repo.online!.complete(true);
    await pending;
    expect(notifier.state.devices, isEmpty);
    expect(notifier.state.isLoading, isFalse);
  });

  ProviderContainer containerFor(_Devices devices, _Pets pets) =>
      ProviderContainer(overrides: [
        deviceRepositoryProvider.overrideWithValue(devices),
        petPeerRepositoryProvider.overrideWithValue(pets),
        petControllerProvider.overrideWith((ref) =>
            _PetState(ref.read(petRepositoryProvider), peerRepo: pets)),
        petCirclePetControllerProvider.overrideWith((ref) => _CirclePets(ref)),
      ]);

  test('unbind updates every visible cache and coalesces duplicate taps',
      () async {
    final repo = _Devices()..unbind = Completer<void>();
    final c = containerFor(repo, _Pets());
    addTearDown(c.dispose);
    await c.read(deviceListProvider.notifier).load();
    final actions = c.read(deviceActionsProvider);
    final first = actions.unbind(_device);
    final second = actions.unbind(_device);
    await Future<void>.delayed(Duration.zero);
    expect(repo.unbinds, 1);
    expect(c.read(deviceListProvider).devices, hasLength(1));
    repo.unbind!.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(c.read(deviceListProvider).devices, isEmpty);
    expect(c.read(petControllerProvider).pets, isEmpty);
    expect(c.read(petCirclePetControllerProvider).pets, isEmpty);
    expect(repo.fetches, 1,
        reason: 'Successful removal must not wait for another list request.');
  });

  test('failed unbind preserves the device card and allows retry', () async {
    final repo = _Devices()..failUnbind = true;
    final c = containerFor(repo, _Pets());
    addTearDown(c.dispose);
    await c.read(deviceListProvider.notifier).load();
    await expectLater(
        c.read(deviceActionsProvider).unbind(_device), throwsStateError);
    expect(c.read(deviceListProvider).devices, hasLength(1));
    repo.failUnbind = false;
    expect(await c.read(deviceActionsProvider).unbind(_device), isTrue);
    expect(c.read(deviceListProvider).devices, isEmpty);
  });

  test(
      'switching account during pet cleanup cannot unbind with the next account',
      () async {
    final repo = _Devices();
    final pets = _Pets()..deletion = Completer<void>();
    final c = containerFor(repo, pets);
    addTearDown(c.dispose);
    final pending = c.read(deviceActionsProvider).unbind(_device);
    c.read(accountSessionProvider.notifier).state++;
    pets.deletion!.complete();
    expect(await pending, isFalse);
    expect(repo.unbinds, 0);
  });
}
