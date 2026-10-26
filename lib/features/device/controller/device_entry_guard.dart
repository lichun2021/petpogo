import 'package:flutter/material.dart';

import '../../../shared/widgets/pet_toast.dart';
import '../data/models/device_model.dart';

/// 所有硬件详情入口共用在线状态判断，离线时不创建详情或控制页面。
abstract final class DeviceEntryGuard {
  static const offlineMessage = '设备当前离线，暂时无法打开';

  static bool allow(BuildContext context, DeviceModel device) {
    if (device.isOnline) return true;
    PetToast.warning(context, offlineMessage);
    return false;
  }
}
