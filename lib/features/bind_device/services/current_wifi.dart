import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/logging/app_log.dart';

final currentWifiReaderProvider =
    Provider<CurrentWifiReader>((ref) => const CurrentWifiReader());

enum CurrentWifiIssue {
  permissionDenied,
  permissionBlocked,
  locationDisabled,
  unavailable,
  readFailed,
}

class CurrentWifiResult {
  final String? name;
  final CurrentWifiIssue? issue;
  const CurrentWifiResult.found(String this.name) : issue = null;
  const CurrentWifiResult.failure(CurrentWifiIssue this.issue) : name = null;
}

/// 区分权限、系统定位和网络状态，供配网输入框就地恢复。
class CurrentWifiReader {
  const CurrentWifiReader();

  Future<CurrentWifiResult> read({bool requestPermission = true}) async {
    try {
      var status = await Permission.locationWhenInUse.status;
      if (!status.isGranted &&
          !status.isPermanentlyDenied &&
          !status.isRestricted &&
          requestPermission) {
        status = await Permission.locationWhenInUse.request();
      }
      if (!status.isGranted) {
        return CurrentWifiResult.failure(
            status.isPermanentlyDenied || status.isRestricted
                ? CurrentWifiIssue.permissionBlocked
                : CurrentWifiIssue.permissionDenied);
      }
      if (await Permission.locationWhenInUse.serviceStatus.isDisabled) {
        return const CurrentWifiResult.failure(
            CurrentWifiIssue.locationDisabled);
      }
      var name = await NetworkInfo().getWifiName();
      if (name == null) {
        return const CurrentWifiResult.failure(CurrentWifiIssue.unavailable);
      }
      // 只移除系统添加的外围引号，保留名称自身的空格和内部引号。
      if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
        name = name.substring(1, name.length - 1);
      }
      if (name.isEmpty || name.toLowerCase() == '<unknown ssid>') {
        return const CurrentWifiResult.failure(CurrentWifiIssue.unavailable);
      }
      return CurrentWifiResult.found(name);
    } catch (error) {
      AppLog.debug('[WiFi] 无法读取当前网络名称: $error');
      return const CurrentWifiResult.failure(CurrentWifiIssue.readFailed);
    }
  }

  Future<bool> openSettings() => openAppSettings();
}
