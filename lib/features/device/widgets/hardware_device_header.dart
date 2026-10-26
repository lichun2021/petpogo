import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_fonts.dart';
import '../../../shared/theme/app_tokens.dart';
import 'hardware_battery_indicator.dart';

/// 机器人和项圈共用的硬件页顶部栏。
class HardwareDeviceHeader extends StatelessWidget {
  const HardwareDeviceHeader({
    super.key,
    required this.name,
    required this.onBack,
    required this.onSwitchDevice,
    this.batteryPercent,
    this.isCharging = false,
    this.batteryIndicator,
    this.online,
    this.actions = const [],
  });

  final String name;
  final int? batteryPercent;
  final bool isCharging;
  final Widget? batteryIndicator;
  final bool? online;
  final VoidCallback onBack;
  final VoidCallback onSwitchDevice;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final foreground = AppColors.textOnBrand;
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light
            .copyWith(statusBarColor: Colors.transparent),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.brandPrimaryStrong, AppColors.brandPrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: IconTheme(
              data: IconThemeData(color: foreground, size: 22),
              child: IconButtonTheme(
                data: IconButtonThemeData(
                    style: IconButton.styleFrom(
                  foregroundColor: foreground,
                  minimumSize: const Size.square(AppSize.touchMin),
                  padding: const EdgeInsets.all(AppSpacing.x12),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.controlRadius),
                )),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
                  child: Row(children: [
                    IconButton(
                      tooltip: '返回',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.x4),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onSwitchDevice,
                          borderRadius: AppRadius.controlRadius,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.x4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(children: [
                                  Flexible(
                                      child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppFonts.primary,
                                      fontSize: 20,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.3,
                                      color: foreground,
                                    ),
                                  )),
                                  const SizedBox(width: AppSpacing.x4),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 20),
                                ]),
                                const SizedBox(height: AppSpacing.x4),
                                Wrap(
                                    spacing: AppSpacing.x12,
                                    runSpacing: AppSpacing.x4,
                                    children: [
                                      batteryIndicator ??
                                          HardwareBatteryIndicator(
                                              percent: batteryPercent,
                                              isCharging: isCharging),
                                      if (online != null)
                                        Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: foreground.withValues(
                                                      alpha: online! ? 1 : .5),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(
                                                  width: AppSpacing.x4),
                                              Flexible(
                                                  child: Text(
                                                online! ? '在线' : '离线',
                                                style: TextStyle(
                                                  fontFamily: AppFonts.primary,
                                                  fontSize: 12,
                                                  height: 1.2,
                                                  color: foreground.withValues(
                                                      alpha: .85),
                                                ),
                                              )),
                                            ]),
                                    ]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.x4),
                      ...actions,
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ));
  }
}
