import 'package:flutter/material.dart';
import '../../shared/theme/app_tokens.dart';
import 'collar_bluetooth_access_dialog.dart';
import 'collar_bluetooth_setup_page.dart';
import 'robot_wifi_setup_page.dart';
import 'widgets/collar_ui.dart';

/// Shared permission gate for first-time setup and changing an existing collar's WiFi.
Future<void> openCollarSetup(
  BuildContext context, {
  required String productKey,
  String? existingMac,
  String? deviceName,
}) async {
  if (existingMac != null) {
    final ready = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('更换项圈 WiFi'),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('即将为「${deviceName ?? '项圈'}」重新配网，仍绑定当前账号，无需解绑。',
                        style: CollarText.body.copyWith(height: 1.6)),
                    const SizedBox(height: AppSpacing.x16),
                    const CollarGuideList(items: [
                      CollarGuideItem(Icons.restart_alt_rounded,
                          '在项圈旁连续按复位键 3 次，清除旧 WiFi。'),
                      CollarGuideItem(
                          Icons.lightbulb_outline_rounded, '确认蓝灯每秒闪烁后再继续。'),
                      CollarGuideItem(
                          Icons.looks_one_rounded, '附近一次只开启这一台项圈的配网模式。'),
                    ]),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('蓝灯已闪烁，继续')),
              ],
            ));
    if (!context.mounted || ready != true) return;
  }
  final allowed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CollarBluetoothAccessDialog());
  if (!context.mounted || allowed != true) return;
  await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CollarBluetoothSetupPage(
              productKey: productKey,
              existingMac: existingMac,
              deviceName: deviceName)));
}

Future<void> openRobotWifiSetup(
  BuildContext context, {
  required String productKey,
  required String existingMac,
  required String deviceName,
}) async {
  final ready = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('更换机器人 WiFi'),
            content: Text(
                '为「$deviceName」设置新 WiFi，仍绑定当前账号，无需解绑。\n\n请先按设备说明让机器人进入配网扫码状态，再让摄像头扫描接下来生成的二维码。'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('开始重新配网'))
            ],
          ));
  if (!context.mounted || ready != true) return;
  await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => RobotWifiSetupPage(
              productKey: productKey,
              existingMac: existingMac,
              deviceName: deviceName)));
}
