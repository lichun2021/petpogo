import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/coord_transform.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

// ── 逆地理编码（Nominatim，WGS84 坐标）───────────────────────
Future<String> _reverseGeocode(double lat, double lng) async {
  try {
    final dio = Dio();
    dio.options.headers['User-Agent'] = 'PetPogoApp/1.0';
    final resp = await dio.get(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'format': 'json',
        'lat': lat.toStringAsFixed(7),
        'lon': lng.toStringAsFixed(7),
        'accept-language': 'zh-CN,zh',
        'zoom': 18,
      },
    ).timeout(Duration(seconds: 8));
    final data = resp.data;
    if (data is Map) {
      final display = data['display_name']?.toString() ?? '';
      if (display.isNotEmpty) {
        final parts = display.split(', ');
        if (parts.length > 1 && parts.last == '中国') parts.removeLast();
        return parts.take(4).join(' '); // 取前4段，不要太长
      }
    }
  } catch (e) {
    debugPrint('[Location] geocode error: $e');
  }
  return ''; // 失败返回空，BottomCard 降级显示坐标
}

// ── 高德瓦片（同 fence_add_flow.dart，GCJ02 坐标系）─────────
const _amapTileUrl =
    'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}';

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
  String? _error;

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
          _error = e.toString();
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
                urlTemplate: _amapTileUrl,
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
                    color: Color(0xFF3EBD6D).withValues(alpha: 0.15),
                    borderColor: Color(0xFF3EBD6D).withValues(alpha: 0.5),
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
                              Border.all(color: Color(0xFF3EBD6D), width: 3),
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
          ),
        ),
      ]),
    );
  }
}

// ── 底部信息卡片 ─────────────────────────────────────────
class _BottomCard extends StatelessWidget {
  final String petName, petAvatar, updateTime;
  final String address; // 逆地理编码结果（可能为空）
  final bool geocoding; // 正在解析地址中
  final PetPositionModel? position;
  final bool inFence;
  final String? error;
  final double safeBottom;

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
                    color: Color(0xFFF0F0EE),
                    border: Border.all(color: Color(0xFF3EBD6D), width: 2.5)),
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
                            color: Color(0xFF1A1A1A))),
                    SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.shield_rounded,
                          size: 14, color: Color(0xFF3EBD6D)),
                      SizedBox(width: 4),
                      Text(
                        !hasLoc ? '定位中...' : (inFence ? '安全守护中' : '已离开围栏'),
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (!hasLoc || inFence)
                                ? Color(0xFF3EBD6D)
                                : AppColors.error),
                      ),
                    ]),
                  ])),
            ]),
            SizedBox(height: 14),
            Row(children: [
              _StatBadge(
                icon: Icons.radio_button_checked_rounded,
                label: inFence ? '范围内' : '范围外',
                color: inFence ? Color(0xFF3EBD6D) : Colors.grey,
              ),
              SizedBox(width: 8),
              _StatBadge(
                icon: Icons.gps_fixed_rounded,
                label: hasLoc ? 'GPS' : 'GPS 无信号',
                color: hasLoc ? Color(0xFF3EBD6D) : Colors.grey,
              ),
              SizedBox(width: 8),
              _StatBadge(
                icon: Icons.access_time_rounded,
                label: updateTime,
                color: Colors.grey.shade600,
              ),
            ]),
            SizedBox(height: 14),
            Divider(height: 1, color: Color(0xFFF0F0EE)),
            SizedBox(height: 12),
            if (error != null)
              Row(children: [
                Icon(Icons.error_outline_rounded,
                    size: 16, color: AppColors.error),
                SizedBox(width: 6),
                Expanded(
                    child: Text(error!,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 12,
                            color: AppColors.error))),
              ])
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
                                color: Color(0xFF1A1A1A)))
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
                                color: Color(0xFF1A1A1A)),
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
                                    color: Color(0xFF999999),
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
                                color: Color(0xFF999999))),
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

// ── Pin 三角尖 ───────────────────────────────────────────
class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, ui.Paint()..color = Color(0xFF3EBD6D));
  }

  @override
  bool shouldRepaint(_) => false;
}
