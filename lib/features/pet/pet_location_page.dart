import 'package:petpogo_app/core/logging/app_log.dart';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_tokens.dart';
import '../../shared/utils/coord_transform.dart';
import '../../shared/utils/map_services.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/pet_toast.dart';
import '../../shared/widgets/app_error_view.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import 'widgets/pet_navigation_sheet.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

// ── 逆地理编码（Nominatim，WGS84 坐标）───────────────────────
Future<String> _reverseGeocode(double lat, double lng) async {
  try {
    final display = await fetchNominatimDisplayName(LatLng(lat, lng));
    if (display.isNotEmpty) {
      final parts = display.split(', ');
      if (parts.length > 1 && parts.last == '中国') parts.removeLast();
      return parts.take(4).join(' ');
    }
  } catch (e) {
    AppLog.debug('[Location] geocode error: $e');
  }
  return '';
}

// ── 宠物位置页 ────────────────────────────────────────────
class PetLocationPage extends ConsumerStatefulWidget {
  final String petName;
  final String deviceMac;
  final String petAvatar;

  const PetLocationPage({
    super.key,
    required this.petName,
    required this.deviceMac,
    this.petAvatar = '',
  });

  @override
  ConsumerState<PetLocationPage> createState() => _PetLocationPageState();
}

class _PetLocationPageState extends ConsumerState<PetLocationPage> {
  PetPositionModel? _position;

  /// WGS84 → GCJ02 转换后的坐标，用于在高德地图上标点
  LatLng? _gcjLatLng;

  /// 逆地理编码得到的文字地址（空 = 未获取或失败）
  String _address = '';
  bool _geocoding = false;

  bool _isRefreshing = false;
  Object? _error;
  bool _choosingNavigation = false;
  int _loadGeneration = 0;
  bool _mapReady = false;

  late final MapController _mapCtrl;

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
    _load();
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool userInitiated = false}) async {
    if (_isRefreshing) return;
    final generation = ++_loadGeneration;
    final previous = _position;
    setState(() {
      _isRefreshing = true;
      _error = null;
    });
    try {
      final repo = ref.read(petPeerRepositoryProvider);
      final pos = await repo.fetchPosition(mac: widget.deviceMac);
      if (!mounted || generation != _loadGeneration) return;
      // 旧缓存响应不能把页面上较新的设备报告覆盖掉。
      final retained = previous != null &&
          previous.reportTime > 0 &&
          pos.reportTime > 0 &&
          pos.reportTime < previous.reportTime;
      final displayed = retained ? previous : pos;

      // API 返回的 latitude/longitude 是 WGS84，
      // 高德地图瓦片使用 GCJ02（火星坐标），必须转换否则偏移 ~500m
      LatLng? gcj;
      if (displayed.hasLocation) {
        gcj = CoordTransform.wgs84ToGcj02(displayed.lat, displayed.lng);
      }

      if (mounted) {
        setState(() {
          _position = displayed;
          _gcjLatLng = gcj;
          _isRefreshing = false;
          _address = displayed.address;
          _geocoding = displayed.hasLocation && displayed.address.isEmpty;
        });
        if (gcj != null && _mapReady) {
          _mapCtrl.move(gcj, 16);
        }
        if (userInitiated) {
          final message = !pos.hasLocation
              ? '设备暂未上报有效位置'
              : pos.reportTime <= 0
                  ? '位置已查询，上报时间未知'
                  : previous != null &&
                          previous.reportTime > 0 &&
                          pos.reportTime <= previous.reportTime
                      ? '设备尚未上报新位置'
                      : '已获取设备上报位置';
          PetToast.show(context, message);
        }
        // API 没带地址 → 用 Nominatim 逆地理编码（WGS84 查询）
        if (displayed.hasLocation && displayed.address.isEmpty) {
          _reverseGeocode(displayed.lat, displayed.lng).then((addr) {
            if (mounted && generation == _loadGeneration) {
              setState(() {
                _address = addr;
                _geocoding = false;
              });
            }
          });
        }
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isRefreshing = false;
          _error = e;
        });
      }
    }
  }

  String get _updateTime {
    if (_position == null || _position!.reportTime == 0) return '--:--';
    final dt = DateTime.fromMillisecondsSinceEpoch(_position!.reportTime);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final hasLoc = _gcjLatLng != null;

    return Scaffold(
      body: Stack(children: [
        // ── 1. 高德地图（GCJ02 瓦片）──────────────────────────
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _gcjLatLng ?? LatLng(39.9042, 116.4074),
              initialZoom: hasLoc ? 16 : 12,
              onMapReady: () {
                _mapReady = true;
                if (_gcjLatLng != null) _mapCtrl.move(_gcjLatLng!, 16);
              },
              minZoom: 4,
              maxZoom: 18,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // 高德矢量瓦片（中文标注）
              TileLayer(
                urlTemplate: amapTileUrl,
                subdomains: ['1', '2', '3', '4'],
                userAgentPackageName: 'com.junxin.petpogo_and',
                maxZoom: 18,
              ),

              // 当前接口没有生效围栏标识，不能用宠物位置生成虚构围栏。

              // 宠物 pin（GCJ02 坐标）
              if (hasLoc)
                MarkerLayer(markers: [
                  Marker(
                    point: _gcjLatLng!,
                    width: 64,
                    height: 74,
                    alignment: Alignment.topCenter,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                              color: AppColors.statusOnline, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: Offset(0, 3)),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: PetAvatar(imageUrl: widget.petAvatar, size: 56),
                      ),
                      // 三角箭头
                      CustomPaint(
                          painter: _PinTailPainter(), size: Size(14, 9)),
                    ]),
                  ),
                ]),
            ],
          ),
        ),

        // ── 2. 顶部透明 AppBar ─────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(8, safeTop + 4, 8, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(children: [
              Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_rounded, size: 20),
                  color: AppColors.onSurface,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Spacer(),
              if (_isRefreshing)
                Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.primary)))
              else
                Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: Icon(Icons.refresh_rounded),
                    color: AppColors.onSurface,
                    onPressed: () => _load(userInitiated: true),
                  ),
                ),
            ]),
          ),
        ),

        // 工具按钮随信息卡片高度移动，避免大字体时互相遮挡。
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 12),
              child: Align(
                  alignment: Alignment.centerRight,
                  child: _MapBtn(
                    icon: Icons.my_location_rounded,
                    color: AppColors.primary,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _load(userInitiated: true);
                    },
                  )),
            ),
            ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .65),
                child: SingleChildScrollView(
                    child: _BottomCard(
                  petName: widget.petName,
                  petAvatar: widget.petAvatar,
                  position: _position,
                  address: _address,
                  geocoding: _geocoding,
                  error: _error,
                  updateTime: _updateTime,
                  safeBottom: safeBottom,
                  onNavigate: hasLoc ? _startNavigation : null,
                ))),
          ]),
        ),
      ]),
    );
  }

  // ── 寻宠导航：弹出导航 App 选择面板，点击后唤起对应软件 ──
  Future<void> _startNavigation() async {
    if (_choosingNavigation) return;
    final gcj = _gcjLatLng;
    final pos = _position;
    if (gcj == null || pos == null || !pos.hasLocation) {
      PetToast.show(context, '宠物位置未就绪，请稍候');
      return;
    }
    HapticFeedback.lightImpact();

    final isIOS = Platform.isIOS;
    final gpsPosition = LatLng(pos.lat, pos.lng);
    final destinationName = '${widget.petName}的位置';
    _choosingNavigation = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppColors.surfaceCard,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
        builder: (_) => PetNavigationSheet(
          isIOS: isIOS,
          destinationName: destinationName,
          onNavigate: (app) => launchUrl(
              app.navigationUri(
                  isIOS: isIOS,
                  gcjPosition: gcj,
                  gpsPosition: gpsPosition,
                  destinationName: destinationName),
              mode: LaunchMode.externalApplication),
        ),
      );
    } finally {
      _choosingNavigation = false;
    }
  }
}

// ── 底部信息卡片 ─────────────────────────────────────────
class _BottomCard extends StatelessWidget {
  final String petName, petAvatar, updateTime;
  final String address; // 逆地理编码结果（可能为空）
  final bool geocoding; // 正在解析地址中
  final PetPositionModel? position;
  final Object? error;
  final double safeBottom;
  final VoidCallback? onNavigate; // 寻宠导航回调

  const _BottomCard({
    required this.petName,
    required this.petAvatar,
    required this.position,
    required this.address,
    required this.geocoding,
    required this.error,
    required this.updateTime,
    required this.safeBottom,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final hasLoc = position?.hasLocation ?? false;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + safeBottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))
        ],
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(99)))),
            SizedBox(height: 14),
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceSunken,
                    border:
                        Border.all(color: AppColors.statusOnline, width: 2.5)),
                clipBehavior: Clip.antiAlias,
                child: PetAvatar(imageUrl: petAvatar, size: 52),
              ),
              SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(petName,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.shield_rounded,
                          size: 14, color: AppColors.statusNeutral),
                      SizedBox(width: 4),
                      Expanded(
                          child: Text(
                        hasLoc ? '围栏状态待确认' : '暂无设备位置',
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceVariant),
                      )),
                    ]),
                  ])),
              SizedBox(width: 8),
              _NavTextBtn(onTap: onNavigate),
            ]),
            SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _StatBadge(
                icon: Icons.radio_button_checked_rounded,
                label: '围栏状态未知',
                color: AppColors.statusNeutral,
              ),
              _StatBadge(
                icon: Icons.gps_fixed_rounded,
                label: hasLoc ? '设备定位' : '暂无定位',
                color: AppColors.statusNeutral,
              ),
              _StatBadge(
                icon: Icons.access_time_rounded,
                label: updateTime,
                color: Colors.grey.shade600,
              ),
            ]),
            SizedBox(height: 14),
            Divider(height: 1, color: AppColors.borderSubtle),
            SizedBox(height: 12),
            if (error != null)
              AppErrorBanner(error: error, fallback: '位置获取失败，请稍后重试')
            else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.location_on_rounded,
                    size: 16, color: AppColors.primary),
                SizedBox(width: 6),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      if (!hasLoc)
                        Text('等待设备上报位置...',
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary))
                      else if (geocoding)
                        // 正在解析地址
                        Row(children: [
                          SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.8, color: AppColors.primary)),
                          SizedBox(width: 6),
                          Text('正在解析地址...',
                              style: TextStyle(
                                  fontFamily: AppFonts.primary,
                                  fontSize: 13,
                                  color: AppColors.onSurfaceVariant)),
                        ])
                      else
                        // 地址（纬度, 经度）
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                            children: [
                              TextSpan(
                                  text: address.isNotEmpty
                                      ? address
                                      : '${position!.latitude}, ${position!.longitude}'),
                              if (address.isNotEmpty)
                                TextSpan(
                                  text:
                                      '  (${position!.latitude}, ${position!.longitude})',
                                  style: TextStyle(
                                    fontFamily: AppFonts.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (hasLoc) ...[
                        SizedBox(height: 2),
                        Text('更新于 $updateTime',
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 11,
                                color: AppColors.textTertiary)),
                      ],
                    ])),
              ]),
          ]),
    );
  }
}

// ── 状态徽章 ─────────────────────────────────────────────
class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ]),
      );
}

// ── 右侧地图按鈕 ───────────────────────────────
class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color; // null = 默认灰色，传入则显示主题色
  const _MapBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.onSurface;
    final bgColor =
        color != null ? color!.withValues(alpha: 0.12) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: color != null
              ? Border.all(color: color!.withValues(alpha: 0.3), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: Offset(0, 2))
          ],
        ),
        child: Icon(icon, size: 22, color: iconColor),
      ),
    );
  }
}

// ── 头像行导航按钮（icon + 文字）────────────────────────
class _NavTextBtn extends StatelessWidget {
  final VoidCallback? onTap;
  const _NavTextBtn({this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final Color color = enabled
        ? AppColors.primary
        : AppColors.onSurfaceVariant.withValues(alpha: 0.4);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.navigation_rounded, size: 16, color: color),
              const SizedBox(width: 4),
              Text('导航',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pin 三角尖 ───────────────────────────────────────────
class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, ui.Paint()..color = AppColors.statusOnline);
  }

  @override
  bool shouldRepaint(_) => false;
}
