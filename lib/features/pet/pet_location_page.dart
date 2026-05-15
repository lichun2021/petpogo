import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import '../pet/fence_manage_page.dart';

// ── 宠物位置页 ────────────────────────────────────────────
class PetLocationPage extends ConsumerStatefulWidget {
  final String petName;
  final String deviceMac;
  const PetLocationPage({super.key, required this.petName, required this.deviceMac});

  @override
  ConsumerState<PetLocationPage> createState() => _PetLocationPageState();
}

class _PetLocationPageState extends ConsumerState<PetLocationPage> {
  PetPositionModel? _position;
  List<FenceModel>  _fences = [];
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isRefreshing = true; _error = null; });
    try {
      final repo = ref.read(petPeerRepositoryProvider);
      final results = await Future.wait([
        repo.fetchPosition(mac: widget.deviceMac),
        repo.fetchFences(mac: widget.deviceMac),
      ]);
      if (mounted) {
        setState(() {
          _position      = results[0] as PetPositionModel;
          _fences        = results[1] as List<FenceModel>;
          _isRefreshing  = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isRefreshing = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e1e2e),
      body: Stack(children: [
        _buildMapPlaceholder(),
        Positioned(top: 0, left: 0, right: 0, child: _buildAppBar(context)),
        DraggableScrollableSheet(
          initialChildSize: 0.40,
          minChildSize: 0.22,
          maxChildSize: 0.75,
          builder: (_, controller) => _buildBottomPanel(controller),
        ),
      ]),
    );
  }

  Widget _buildMapPlaceholder() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2d2b3f), Color(0xFF1a1a2e)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: CustomPaint(
          painter: _MapGridPainter(
            hasLocation: _position?.hasLocation ?? false,
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 4, 8, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1e1e2e), const Color(0xFF1e1e2e).withOpacity(0)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        Expanded(child: Text('${widget.petName} 的位置',
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16,
                fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center)),
        IconButton(
          icon: _isRefreshing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _isRefreshing ? null : _load,
        ),
      ]),
    );
  }

  Widget _buildBottomPanel(ScrollController controller) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFfff4f3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: ListView(controller: controller, padding: EdgeInsets.zero, children: [
        Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 宠物信息行
            Row(children: [
              Container(width: 46, height: 46,
                  decoration: const BoxDecoration(color: Color(0xFFffe1df), shape: BoxShape.circle),
                  child: const Icon(Icons.pets_rounded, color: AppColors.primary, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.petName, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                Text('更新: ${_position?.updateDisplay ?? "加载中"}',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.onSurfaceVariant)),
              ])),
            ]),
            const SizedBox(height: 16),

            // 位置信息
            if (_error != null)
              _buildError()
            else if (_position == null)
              const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
            else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceContainerHigh)),
                child: Column(children: [
                  if (_position!.address.isNotEmpty)
                    _CoordRow(icon: Icons.location_on_rounded, label: '地址', value: _position!.address),
                  if (_position!.address.isNotEmpty) const Divider(height: 16),
                  Row(children: [
                    Expanded(child: _CoordRow(icon: Icons.north_east_rounded, label: '纬度', value: '${_position!.latitude}°')),
                    Expanded(child: _CoordRow(icon: Icons.north_east_rounded, label: '经度', value: '${_position!.longitude}°')),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
            ],

            // 围栏管理
            Row(children: [
              const Expanded(child: Text('围栏管理', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface))),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FenceManagePage(deviceMac: widget.deviceMac, petName: widget.petName),
                  ));
                  _load(); // 返回后刷新围栏
                },
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text('管理'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ]),
            const SizedBox(height: 10),
            if (_fences.isEmpty)
              Text('暂无围栏', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.onSurfaceVariant))
            else
              ..._fences.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FenceItem(fence: f),
              )),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => FenceManagePage(deviceMac: widget.deviceMac, petName: widget.petName),
                ));
                _load();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary, side: const BorderSide(color: AppColors.secondary),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('添加围栏', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
            ),
          ],
        )),
      ]),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.errorContainer.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12)),
      child: Text(_error!, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
          color: AppColors.onSurfaceVariant)),
    );
  }
}

class _CoordRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _CoordRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: AppColors.primary),
    const SizedBox(width: 6),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10,
          fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
      Text(value, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
          fontWeight: FontWeight.w600, color: AppColors.onSurface)),
    ]),
  ]);
}

class _FenceItem extends StatelessWidget {
  final FenceModel fence;
  const _FenceItem({required this.fence});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceContainerHigh)),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🏠 ${fence.fenceName}', style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        Text('半径 ${fence.displayRadius}', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 11, color: AppColors.onSurfaceVariant)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFF4ADE80).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: const Text('活跃', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
      ),
    ]),
  );
}

// ── 地图网格 CustomPainter ──────────────────────────────
class _MapGridPainter extends CustomPainter {
  final bool hasLocation;
  const _MapGridPainter({this.hasLocation = false});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y < size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);

    final road = Paint()..color = Colors.white.withOpacity(0.09)..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.42), Offset(size.width, size.height * 0.42), road);
    canvas.drawLine(Offset(size.width * 0.38, 0), Offset(size.width * 0.38, size.height), road);

    if (hasLocation) {
      final cx = size.width * 0.38, cy = size.height * 0.42;
      canvas.drawCircle(Offset(cx, cy), 80, Paint()..color = const Color(0xFFa83206).withOpacity(0.12));
      canvas.drawCircle(Offset(cx, cy), 80, Paint()..color = const Color(0xFFa83206).withOpacity(0.4)
        ..style = PaintingStyle.stroke..strokeWidth = 1.5);
      canvas.drawCircle(Offset(cx, cy), 10, Paint()..color = const Color(0xFFa83206));
      canvas.drawCircle(Offset(cx, cy), 7, Paint()..color = Colors.white);
    } else {
      final c = Paint()..color = Colors.white.withOpacity(0.12);
      canvas.drawCircle(Offset(size.width * 0.38, size.height * 0.42), 24, c);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter old) => old.hasLocation != hasLocation;
}
