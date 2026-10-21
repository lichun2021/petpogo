import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/account_session_provider.dart';
import '../../pet/data/repository/pet_peer_repository.dart';
import '../../pet/controller/pet_controller.dart';
import '../../pet_circle/controller/pet_circle_pet_controller.dart';
import '../data/models/device_model.dart';
import '../data/repository/device_repository.dart';

/// Coordinates an unbind across screens; views do not manage cache refreshes.
class DeviceActions {
  DeviceActions(this._ref);
  final Ref _ref;
  final Map<String, Future<bool>> _pending = {};

  Future<bool> unbind(DeviceModel device) {
    final key =
        '${_ref.read(accountSessionProvider)}:${device.mac.toUpperCase()}';
    return _pending.putIfAbsent(
        key,
        () => _unbind(device).whenComplete(() {
              _pending.remove(key);
            }));
  }

  Future<bool> _unbind(DeviceModel device) async {
    final session = _ref.read(accountSessionProvider);
    final repository = _ref.read(deviceRepositoryProvider);
    final petRepository = _ref.read(petPeerRepositoryProvider);
    final devices = _ref.read(deviceListProvider.notifier);
    final pets = _ref.read(petControllerProvider.notifier);
    final circlePets = _ref.read(petCirclePetControllerProvider.notifier);
    if (device.deviceId.isNotEmpty) {
      try {
        await petRepository.deletePet(deviceId: device.deviceId);
      } catch (_) {
        // A device without an associated pet must still be able to unbind.
      }
    }
    if (_ref.read(accountSessionProvider) != session) return false;
    await repository.unbindDevice(device.mac);
    if (_ref.read(accountSessionProvider) != session) return false;
    // Publish the confirmed removal without waiting for an eventually
    // consistent list endpoint or slow online-state enrichment.
    devices.removeDevice(device.mac, deviceId: device.deviceId);
    pets.removeForDevice(device.deviceId);
    circlePets.removeForDevice(device.deviceId);
    return true;
  }
}

final deviceActionsProvider =
    Provider<DeviceActions>((ref) => DeviceActions(ref));
