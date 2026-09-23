import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/coord_transform.dart';
import '../../shared/utils/map_services.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/pet_toast.dart';
import '../../shared/widgets/app_error_view.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/data/repository/pet_peer_repository.dart';
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
    debugPrint('[Location] geocode error: $e');
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

  Future<void> _load() async {
    setState(() {
      _isRefreshing = true;
      _error = null;
    });
    try {
      final repo = ref.read(petPeerRepositoryProvider);
      final pos = await repo.fetchPosition(mac: widget.deviceMac);

      // API 返回的 latitude/longitude 是 WGS84，
      // 高德地图瓦片使用 GCJ02（火星坐标），必须转换否则偏移 ~500m
      LatLng? gcj;
      if (pos.hasLocation) {
        gcj = CoordTransform.wgs84ToGcj02(pos.lat, pos.lng);
        debugPrint('[Location] WGS84: ${pos.lat},${pos.lng}');
        debugPrint('[Location] GCJ02: ${gcj.latitude},${gcj.longitude}');
      }

      if (mounted) {
        setState(() {
          _position = pos;
          _gcjLatLng = gcj;
          _isRefreshing = false;
          _address = pos.address; // 若 API 本身带了地址直接用
          if (pos.address.isEmpty) {
            _geocoding = true;
          }
        });
        if (gcj != null) {
          _mapCtrl.move(gcj, 16);
        }
        // API 没带地址 → 用 Nominatim 逆地理编码（WGS84 查询）
        if (pos.hasLocation && pos.address.isEmpty) {
          _reverseGeocode(pos.lat, pos.lng).then((addr) {
            if (mounted) {
              setState(() {
                _address = addr;
                _geocoding = false;
              });
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _error = e;
        });
      }
    }
  }

  bool get _inFence => _position?.hasLocation ?? false;

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

              // 围栏半径圆（GCJ02 坐标）
              if (hasLoc)
                CircleLayer(circles: [
                  CircleMarker(
                    point: _gcjLatLng!,
                    radius: 80,
                    useRadiusInMeter: true,
                    color: AppColors.statusOnline.withValues(alpha: 0.15),
                    borderColor: AppColors.statusOnline.withValues(alpha: 0.5),
                    borderStrokeWidth: 1.5,
                  ),
                ]),

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
                          border:
                              Border.all(color: AppColors.statusOnline, width: 3),
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
                    onPressed: _load,
                  ),
                ),
            ]),
          ),
        ),

        // ── 3. 右侧工具按鈕 ──────────────────────────────
        Positioned(
          right: 16,
          bottom: safeBottom + 224,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _MapBtn(
              icon: Icons.my_location_rounded,
              color: AppColors.primary,
              onTap: () {
                HapticFeedback.lightImpact();
                if (_gcjLatLng != null) {
                  _mapCtrl.move(_gcjLatLng!, 16);
                }
              },
            ),
          ]),
        ),

        // ── 4. 底部宠物信息卡片 ──────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomCard(
            petName: widget.petName,
            petAvatar: widget.petAvatar,
            position: _position,
            address: _address,
            geocoding: _geocoding,
            inFence: _inFence,
            error: _error,
            updateTime: _updateTime,
            safeBottom: safeBottom,
            onNavigate: _startNavigation,
          ),
        ),
      ]),
    );
  }

  // ── 寻宠导航：弹出导航 App 选择面板，点击后唤起对应软件 ──
  Future<void> _startNavigation() async {
    final gcj = _gcjLatLng;
    final pos = _position;
    if (gcj == null || pos == null || !pos.hasLocation) {
      PetToast.show(context, '宠物位置未就绪，请稍候');
      return;
    }
    HapticFeedback.lightImpact();

    final latGcj = gcj.latitude.toStringAsFixed(6);
    final lonGcj = gcj.longitude.toStringAsFixed(6);
    final latWgs = pos.lat.toStringAsFixed(6);
    final lonWgs = pos.lng.toStringAsFixed(6);

    // 候选导航 App：腾讯/高德/百度用 GCJ02，Apple 原生地图用 WGS84
    final candidates = <_NavOption>[
      _NavOption(
        name: '腾讯地图',
        color: AppColors.tencentMap,
        icon: Icons.directions_rounded,
        uri: Uri.parse(
            'qqmap://map/routeplan?type=drive&to=宠物位置&tocoord=$latGcj,$lonGcj&referer=petpogo'),
      ),
      _NavOption(
        name: '高德地图',
        color: AppColors.amap,
        icon: Icons.navigation_rounded,
        uri: Platform.isIOS
            ? Uri.parse(
                'iosamap://navi?sourceApplication=petpogo&lat=$latGcj&lon=$lonGcj&dev=0&style=2')
            : Uri.parse(
                'androidamap://navi?sourceApplication=petpogo&lat=$latGcj&lon=$lonGcj&dev=0&style=2'),
      ),
      _NavOption(
        name: '百度地图',
        color: AppColors.baiduMap,
        icon: Icons.map_rounded,
        uri: Uri.parse(
            'baidumap://map/direction?destination=$latGcj,$lonGcj&coord_type=gcj02&mode=driving&src=petpogo'),
      ),
      if (Platform.isIOS)
        _NavOption(
          name: '原生地图',
          color: AppColors.appleMaps,
          icon: Icons.apple,
          uri: Uri.parse('maps://?daddr=$latWgs,$lonWgs'),
        ),
    ];

    // 只保留设备上已安装的导航 App
    final available = <_NavOption>[];
    for (final o in candidates) {
      if (await canLaunchUrl(o.uri)) available.add(o);
    }

    if (!mounted) return;
    if (available.isEmpty) {
      PetToast.show(context, '未找到地图 App');
      return;
    }

    final selected = await showModalBottomSheet<_NavOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _NavAppSheet(options: available),
    );

    if (selected == null || !mounted) return;
    final ok =
        await launchUrl(selected.uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      PetToast.show(context, '打开 ${selected.name} 失败');
    }
  }
}

// ── 底部信息卡片 ─────────────────────────────────────────
class _BottomCard extends StatelessWidget {
  final String petName, petAvatar, updateTime;
  final String address; // 逆地理编码结果（可能为空）
  final bool geocoding; // 正在解析地址中
  final PetPositionModel? position;
  final bool inFence;
  final Object? error;
  final double safeBottom;
  final VoidCallback? onNavigate; // 寻宠导航回调

  const _BottomCard({
    required this.petName,
    required this.petAvatar,
    required this.position,
    required this.address,
    required this.geocoding,
    required this.inFence,
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
                    border: Border.all(color: AppColors.statusOnline, width: 2.5)),
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
                          size: 14, color: AppColors.statusOnline),
                      SizedBox(width: 4),
                      Text(
                        !hasLoc ? '定位中...' : (inFence ? '安全守护中' : '已离开围栏'),
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (!hasLoc || inFence)
                                ? AppColors.statusOnline
                                : AppColors.error),
                      ),
                    ]),
                  ])),
              SizedBox(width: 8),
              _NavTextBtn(onTap: onNavigate),
            ]),
            SizedBox(height: 14),
            Row(children: [
              _StatBadge(
                icon: Icons.radio_button_checked_rounded,
                label: inFence ? '范围内' : '范围外',
                color: inFence ? AppColors.statusOnline : AppColors.statusNeutral,
              ),
              SizedBox(width: 8),
              _StatBadge(
                icon: Icons.gps_fixed_rounded,
                label: hasLoc ? 'GPS' : 'GPS 无信号',
                color: hasLoc ? AppColors.statusOnline : AppColors.statusNeutral,
              ),
              SizedBox(width: 8),
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

// ── 导航 App 选项 ──────────────────────────────────────
class _NavOption {
  final String name;
  final Color color;
  final IconData icon;
  final Uri uri;
  const _NavOption({
    required this.name,
    required this.color,
    required this.icon,
    required this.uri,
  });
}

// ── 导航方式选择面板 ───────────────────────────────────
class _NavAppSheet extends StatelessWidget {
  final List<_NavOption> options;
  const _NavAppSheet({required this.options});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('导航到宠物位置',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            ...options.map((o) => _NavOptionTile(option: o)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onSurfaceVariant,
                backgroundColor: AppColors.surfaceSunken,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('取消',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 单个导航 App 选项 ─────────────────────────────────
class _NavOptionTile extends StatelessWidget {
  final _NavOption option;
  const _NavOptionTile({required this.option});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, option),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: option.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(option.icon, color: option.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(option.name,
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary))),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textTertiary),
          ]),
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
