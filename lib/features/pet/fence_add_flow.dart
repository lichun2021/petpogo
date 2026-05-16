import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/coord_transform.dart';
import '../../shared/widgets/pet_toast.dart';
import 'data/repository/pet_peer_repository.dart';

// ── 逆地理编码（OSM Nominatim，免费无需 Key）────────────────
// 高德 REST API 需单独申请「Web 服务」类型 Key（Android Key 不适用）
// 此处改用 OpenStreetMap Nominatim，支持中文地址返回
Future<String> _amapRegeocode(LatLng pos) async {
  try {
    final dio = Dio();
    // Nominatim 要求 User-Agent 标识应用
    dio.options.headers['User-Agent'] = 'PetPogoApp/1.0';
    final resp = await dio.get(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'format':          'json',
        'lat':             pos.latitude.toStringAsFixed(7),
        'lon':             pos.longitude.toStringAsFixed(7),
        'accept-language': 'zh-CN,zh',
        'zoom':            18,
      },
    ).timeout(const Duration(seconds: 8));

    final data = resp.data;
    debugPrint('[Geocode] Nominatim response: $data');

    if (data is Map) {
      // 优先使用 display_name（完整地址）
      final display = data['display_name']?.toString() ?? '';
      if (display.isNotEmpty) {
        // 去掉末尾多余的国家名（"中国"）
        final parts = display.split(', ');
        if (parts.length > 1 && parts.last == '中国') parts.removeLast();
        return parts.join(' ');
      }
    }
  } catch (e) {
    debugPrint('[Geocode] Nominatim error: $e');
  }
  // 兜底：显示坐标
  return '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
}

// ── 高德瓦片 URL ──────────────────────────────────────────
// 使用高德矢量路网瓦片（支持中文标注，style=8）
const _amapTileUrl =
    'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}';

// ═══════════════════════════════════════════════════════════
// Step 1: 地图选点页
// ═══════════════════════════════════════════════════════════
class FenceMapPickerPage extends StatefulWidget {
  final String deviceMac;
  const FenceMapPickerPage({super.key, required this.deviceMac});

  @override
  State<FenceMapPickerPage> createState() => _FenceMapPickerPageState();
}

class _FenceMapPickerPageState extends State<FenceMapPickerPage> {
  final _mapController = MapController();

  LatLng _center    = const LatLng(31.2304, 121.4737); // 默认上海
  double  _radius   = 300.0; // 预览半径（米）
  bool    _locating = false;
  String  _address  = '正在获取位置...';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // ── GPS 定位 ──────────────────────────────────────────
  // GPS 返回 WGS-84，高德地图瓦片是 GCJ-02，必须转换否则偏移 100~500m
  Future<void> _getCurrentLocation() async {
    setState(() { _locating = true; });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() { _address = '请在系统设置中开启位置权限'; _locating = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      ).timeout(const Duration(seconds: 8));

      // WGS-84 → GCJ-02（火星坐标），解决高德地图偏移
      final gcj = CoordTransform.wgs84ToGcj02(pos.latitude, pos.longitude);
      debugPrint('[Fence] GPS WGS84: ${pos.latitude},${pos.longitude}');
      debugPrint('[Fence] Map GCJ02: ${gcj.latitude},${gcj.longitude}');

      setState(() { _center = gcj; _locating = false; });
      _mapController.move(gcj, 16);

      // Nominatim 用原始 WGS-84 查询（OSM 坐标系）
      _reverseGeocode(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      setState(() { _address = '定位失败，请手动选点'; _locating = false; });
    }
  }

  // ── 逆地理编码（高德 REST API）──
  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() { _address = '正在获取地址...'; });
    final addr = await _amapRegeocode(pos);
    if (mounted) setState(() { _address = addr; });
  }

  // ── 地图移动时更新中心 ──
  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      setState(() { _center = camera.center; });
      _reverseGeocode(camera.center);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // ── 全屏地图 ──
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:    _center,
            initialZoom:      15,
            onMapEvent: (event) {
              if (event is MapEventMoveEnd || event is MapEventScrollWheelZoom) {
                _onMapMoved(_mapController.camera, true);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _amapTileUrl,
              subdomains: const ['1', '2', '3', '4'],
              userAgentPackageName: 'com.junxin.petpogo_and',
            ),
            // 围栏圆形预览
            CircleLayer(circles: [
              CircleMarker(
                point:  _center,
                radius: _radius,
                color:  AppColors.primary.withOpacity(0.12),
                borderColor: AppColors.primary.withOpacity(0.6),
                borderStrokeWidth: 2,
                useRadiusInMeter: true,
              ),
            ]),
          ],
        ),

        // ── 中心 Pin（固定，地图在其下移动）──
        const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on_rounded, color: AppColors.primary, size: 42, shadows: [
              Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
            ]),
            SizedBox(height: 36), // Pin 底部偏移
          ]),
        ),

        // ── 顶部 AppBar 覆盖层 ──
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Row(children: [
              _GlassButton(
                icon: Icons.arrow_back_ios_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: Row(children: [
                    const Icon(Icons.search_rounded, size: 18, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '位置信息与电子围栏',
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.onSurface),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),

        // ── 定位按钮 ──
        Positioned(
          right: 16,
          bottom: 200,
          child: _GlassButton(
            icon: Icons.my_location_rounded,
            loading: _locating,
            onTap: _getCurrentLocation,
          ),
        ),

        // ── 底部地址 + 下一步 ──
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16)],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // 拖把条
                  Center(child: Container(width: 36, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),

                  // 当前地址
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('当前选点', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11, color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(_address, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                    ])),
                  ]),
                  const SizedBox(height: 16),

                  // 下一步按钮
                  FilledButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => FenceConfigPage(
                          deviceMac:    widget.deviceMac,
                          pickedCenter: _center,
                          pickedAddress: _address,
                        ),
                      ));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('下一步', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // (unused helper removed)
}

// ═══════════════════════════════════════════════════════════
// Step 2: 围栏配置页
// ═══════════════════════════════════════════════════════════
class FenceConfigPage extends ConsumerStatefulWidget {
  final String   deviceMac;
  final LatLng   pickedCenter;
  final String   pickedAddress;

  const FenceConfigPage({
    super.key,
    required this.deviceMac,
    required this.pickedCenter,
    required this.pickedAddress,
  });

  @override
  ConsumerState<FenceConfigPage> createState() => _FenceConfigPageState();
}

class _FenceConfigPageState extends ConsumerState<FenceConfigPage> {
  final _nameCtrl = TextEditingController();
  double _radius  = 300; // 米
  bool   _saving  = false;

  static const _quickRadii = [100.0, 300.0, 500.0, 1000.0];

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      PetToast.warning(context, '请填写围栏名称');
      return;
    }
    setState(() { _saving = true; });
    HapticFeedback.mediumImpact();
    try {
      await ref.read(petPeerRepositoryProvider).addFence(
        fenceName: _nameCtrl.text.trim(),
        longitude: widget.pickedCenter.longitude.toStringAsFixed(6),
        latitude:  widget.pickedCenter.latitude.toStringAsFixed(6),
        radius:    _radius.toInt().toString(),
        address:   widget.pickedAddress,
        mac:       widget.deviceMac,
        coordinateType: 'gcj02',
      );
      if (!mounted) return;
      // 成功：弹提示并弹出两层（选点页 + 配置页）回到围栏列表
      PetToast.success(context, '围栏已添加 ✅');
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.pop(context, true); // 回到地图选点页
      Navigator.pop(context, true); // 回到围栏管理页，触发刷新
    } catch (e) {
      if (mounted) {
        setState(() { _saving = false; });
        PetToast.warning(context, '添加失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('设置围栏', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── 地图小预览 ──
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: widget.pickedCenter,
                  initialZoom:   15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none, // 配置页地图不可交互
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: _amapTileUrl,
                    subdomains: const ['1', '2', '3', '4'],
                    userAgentPackageName: 'com.junxin.petpogo_and',
                  ),
                  CircleLayer(circles: [
                    CircleMarker(
                      point:  widget.pickedCenter,
                      radius: _radius,
                      color:  AppColors.primary.withOpacity(0.15),
                      borderColor: AppColors.primary.withOpacity(0.7),
                      borderStrokeWidth: 2,
                      useRadiusInMeter: true,
                    ),
                  ]),
                  MarkerLayer(markers: [
                    Marker(
                      point: widget.pickedCenter,
                      child: const Icon(Icons.location_on_rounded,
                          color: AppColors.primary, size: 32),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── 围栏名称 ──
          _SectionLabel('围栏名称'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              hintText: '如：家、公园、公司',
              hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withOpacity(0.5),
                  fontFamily: 'Plus Jakarta Sans'),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),

          // ── 快捷半径选择 ──
          _SectionLabel('搜索范围'),
          const SizedBox(height: 8),
          Row(children: _quickRadii.map((r) {
            final active = _radius == r;
            return Expanded(
              child: GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); setState(() { _radius = r; }); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? AppColors.primary : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Column(children: [
                    Text(_radiusLabel(r),
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: active ? Colors.white : AppColors.onSurface)),
                    Text('米', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 10, color: active ? Colors.white70 : AppColors.onSurfaceVariant)),
                  ]),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 12),

          // ── 精细滑块 ──
          Row(children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  thumbColor: AppColors.primary,
                  inactiveTrackColor: Colors.grey.withOpacity(0.2),
                  overlayColor: AppColors.primary.withOpacity(0.12),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _radius,
                  min: 50, max: 2000,
                  onChanged: (v) => setState(() { _radius = v.roundToDouble(); }),
                ),
              ),
            ),
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${_radius.toInt()}m',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ]),
          const SizedBox(height: 20),

          // ── 位置信息 ──
          _SectionLabel('位置信息'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.pickedAddress,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13, color: AppColors.onSurface))),
            ]),
          ),
          const SizedBox(height: 20),

          // ── 警报通知入口（准备按钮，不跳转）──
          _SectionLabel('警报通知'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => PetToast.warning(context, '警报通知即将上线'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_rounded,
                      color: Color(0xFFFF9800), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('设置警报通知', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  Text('即将上线', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11, color: AppColors.onSurfaceVariant)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('即将上线', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // ── 警报声音入口（准备按钮，不跳转）──
          GestureDetector(
            onTap: () => PetToast.warning(context, '警报声音即将上线'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('选择警报声音', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  Text('设置宠物越界时的提醒声音', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11, color: AppColors.onSurfaceVariant)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('即将上线', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)),
                ),
              ]),
            ),
          ),
        ]),
      ),

      // ── 底部保存按钮 ──
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _saving
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('保存围栏', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  String _radiusLabel(double r) {
    if (r >= 1000) return '${(r / 1000).toStringAsFixed(0)}k';
    return r.toInt().toString();
  }
}

// ── 工具组件 ──────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
          fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.onSurface));
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;
  const _GlassButton({required this.icon, required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: loading
          ? const Center(child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
          : Icon(icon, size: 20, color: AppColors.onSurface),
    ),
  );
}
