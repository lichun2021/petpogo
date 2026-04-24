import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../app.dart' show AppL10nX;

class DeviceCard extends StatelessWidget {
  final String deviceType;
  final String deviceName;
  final bool isOnline;
  final int battery;
  final String location;
  final String? nowPlaying;

  const DeviceCard({
    super.key,
    required this.deviceType,
    required this.deviceName,
    required this.isOnline,
    required this.battery,
    required this.location,
    this.nowPlaying,
  });

  bool get _isCollar  => deviceType == '项圈';
  bool get _isRobot   => deviceType == '机器人';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Center(
                  child: Icon(
                    _isCollar ? Icons.watch_rounded : Icons.smart_toy_rounded,
                    color: _isCollar ? AppColors.secondary : AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deviceName,
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17,
                            fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            color: isOnline ? AppColors.online : AppColors.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isOnline ? l10n.deviceOnline : l10n.deviceOffline,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                            fontWeight: FontWeight.w700, letterSpacing: 0.8,
                            color: isOnline ? AppColors.secondary : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text('$battery%',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                          fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  const SizedBox(width: 4),
                  Icon(_batteryIcon(battery), color: AppColors.onSurfaceVariant, size: 20),
                ],
              ),
            ],
          ),

          if (_isRobot && nowPlaying != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.music_note_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.deviceNowPlaying,
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9,
                              fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.primary),
                        ),
                        Text(nowPlaying!,
                            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                                fontWeight: FontWeight.w500, color: AppColors.onSurface)),
                      ],
                    ),
                  ),
                  Icon(Icons.pause_circle_filled_rounded, color: AppColors.primary, size: 24),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _batteryIcon(int pct) {
    if (pct > 80) return Icons.battery_full_rounded;
    if (pct > 60) return Icons.battery_5_bar_rounded;
    if (pct > 40) return Icons.battery_4_bar_rounded;
    if (pct > 20) return Icons.battery_3_bar_rounded;
    if (pct > 10) return Icons.battery_2_bar_rounded;
    return Icons.battery_1_bar_rounded;
  }
}
