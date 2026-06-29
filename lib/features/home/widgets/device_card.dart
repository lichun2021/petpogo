import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../app.dart' show AppL10nX;
import 'package:petpogo_app/shared/theme/app_fonts.dart';
import '../../device/data/models/device_product_model.dart';

// ── 设备类型枚举 ──────────────────────────────────────────
/// 支持的设备类型，替代原来的字符串 magic value
// ── 设备卡片 ──────────────────────────────────────────────
class DeviceCard extends StatelessWidget {
  final String productKey;
  final String deviceName;
  final bool isOnline;
  final int battery;
  final String location;
  final String? nowPlaying;

  DeviceCard({
    super.key,
    required this.productKey,
    required this.deviceName,
    required this.isOnline,
    required this.battery,
    required this.location,
    this.nowPlaying,
  });

  DeviceProductType get _productType =>
      DeviceProductType.fromProductKey(productKey);
  bool get _isCollar => _productType == DeviceProductType.collar;
  bool get _isRobot => _productType == DeviceProductType.robot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 16,
              spreadRadius: -4,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Center(
                  child: Icon(
                    _isCollar ? Icons.watch_rounded : Icons.smart_toy_rounded,
                    color: _isCollar ? AppColors.secondary : AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deviceName,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface)),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? AppColors.online
                                : AppColors.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 5),
                        Text(
                          isOnline ? l10n.deviceOnline : l10n.deviceOffline,
                          style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: isOnline
                                ? AppColors.secondary
                                : AppColors.onSurfaceVariant,
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
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  SizedBox(width: 4),
                  Icon(_batteryIcon(battery),
                      color: AppColors.onSurfaceVariant, size: 20),
                ],
              ),
            ],
          ),
          if (_isRobot && nowPlaying != null) ...[
            SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.music_note_rounded,
                      color: AppColors.primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.deviceNowPlaying,
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppColors.primary),
                        ),
                        Text(nowPlaying!,
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurface)),
                      ],
                    ),
                  ),
                  Icon(Icons.pause_circle_filled_rounded,
                      color: AppColors.primary, size: 24),
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
