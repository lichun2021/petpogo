import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../device/data/repository/device_repository.dart';
import '../device/data/models/device_model.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import '../pet/pet_location_page.dart';

// ── 设备详情页 ────────────────────────────────────────────
class DeviceDetailPage extends ConsumerStatefulWidget {
  final String mac;
  final String name;
  const DeviceDetailPage({super.key, required this.mac, required this.name});

  @override
  ConsumerState<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends ConsumerState<DeviceDetailPage> {
  DeviceDetailModel? _detail;
  PetInfoModel?      _petInfo;
  OtaInfoModel?      _otaInfo;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(deviceRepositoryProvider);
      final petRepo = ref.read(petPeerRepositoryProvider);
      final results = await Future.wait([
        repo.fetchDeviceDetail(widget.mac),
        petRepo.fetchPetInfo(mac: widget.mac).catchError((_) => const PetInfoModel()),
        repo.fetchOtaInfo(widget.mac).catchError((_) => const OtaInfoModel()),
      ]);
      if (mounted) {
        setState(() {
          _detail  = results[0] as DeviceDetailModel;
          _petInfo = results[1] as PetInfoModel;
          _otaInfo = results[2] as OtaInfoModel;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5))
          : _error != null
              ? _buildError()
              : CustomScrollView(slivers: [
                  _buildAppBar(context),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverList(delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),
                      _buildStatusHero(),
                      const SizedBox(height: 20),
                      _buildInfoGrid(),
                      const SizedBox(height: 20),
                      if (_petInfo != null && _petInfo!.petName.isNotEmpty) _buildPetSection(),
                      if (_petInfo != null && _petInfo!.petName.isNotEmpty) const SizedBox(height: 20),
                      if (_otaInfo != null && _otaInfo!.isUpgrade) _buildOtaBanner(),
                      if (_otaInfo != null && _otaInfo!.isUpgrade) const SizedBox(height: 20),
                      _buildActions(context),
                    ])),
                  ),
                ]),
    );
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.onSurfaceVariant),
      const SizedBox(height: 16),
      Text(_error!, textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: AppColors.onSurfaceVariant)),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: _loadAll, child: const Text('重试')),
    ]));
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        color: AppColors.onSurface,
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(widget.name, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w700)),
      centerTitle: true,
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), color: AppColors.onSurfaceVariant,
            onPressed: _loadAll),
      ],
    );
  }

  Widget _buildStatusHero() {
    final online = _detail?.onlineStatus ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7a1f02), Color(0xFFa83206), Color(0xFFff784e)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 24, spreadRadius: -4, offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        Container(width: 72, height: 72,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.router_rounded, color: Colors.white, size: 38)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(
            color: online ? const Color(0xFF4ADE80) : Colors.white38, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(online ? '设备在线' : '设备离线',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w700,
                  color: online ? const Color(0xFF4ADE80) : Colors.white60)),
        ]),
        const SizedBox(height: 6),
        Text('最后在线: ${_detail?.lastOnlineDisplay ?? "未知"}',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: Colors.white.withOpacity(0.65))),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(widget.mac, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5))),
      ]),
    );
  }

  Widget _buildInfoGrid() {
    final items = [
      ('设备型号',   _detail?.productKey     ?? '-'),
      ('产品名称',   _detail?.productName    ?? '-'),
      ('固件',       _otaInfo?.currentVersion ?? '-'),
      ('商户',       _detail?.merchantName   ?? '-'),
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2,
      children: items.map((e) => _InfoCell(label: e.$1, value: e.$2)).toList(),
    );
  }

  Widget _buildPetSection() {
    final pet = _petInfo!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('绑定的宠物', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => PetLocationPage(petName: pet.petName, deviceMac: widget.mac),
        )),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceContainerHigh)),
          child: Row(children: [
            Container(width: 46, height: 46,
                decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.25), shape: BoxShape.circle),
                child: const Icon(Icons.pets_rounded, color: AppColors.primary, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pet.petName, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              Text([if (pet.breed.isNotEmpty) pet.breed, if (pet.age > 0) '${pet.age}岁',
                    if (pet.weight.isNotEmpty) '${pet.weight}kg', if (pet.sex.isNotEmpty) pet.sexDisplay]
                  .join(' · '),
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.onSurfaceVariant)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant, size: 20),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildOtaBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tertiary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tertiary.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.system_update_rounded, color: AppColors.tertiary, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('有新版本可升级', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.tertiary)),
          Text(_otaInfo?.msg ?? '', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 11, color: AppColors.onSurfaceVariant)),
        ])),
        TextButton(onPressed: () {}, child: const Text('升级', style: TextStyle(color: AppColors.tertiary))),
      ]),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _ActionButton(icon: Icons.edit_rounded, label: '重命名', onTap: () => _showRenameDialog(context))),
        const SizedBox(width: 12),
        Expanded(child: _ActionButton(icon: Icons.location_on_rounded, label: '查看位置', onTap: () {
          final pet = _petInfo;
          if (pet != null && pet.petName.isNotEmpty) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => PetLocationPage(petName: pet.petName, deviceMac: widget.mac),
            ));
          }
        })),
      ]),
      const SizedBox(height: 12),
      _ActionButton(icon: Icons.link_off_rounded, label: '解绑设备',
          color: AppColors.error, fullWidth: true, onTap: () => _showUnbindDialog(context)),
    ]);
  }

  void _showRenameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: widget.name);
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('重命名设备', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
      content: TextField(controller: ctrl, decoration: InputDecoration(
          hintText: '设备名称', filled: true, fillColor: AppColors.surfaceContainer,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await ref.read(deviceRepositoryProvider).updateDeviceName(widget.mac, ctrl.text);
              await ref.read(deviceListProvider.notifier).load();
            } catch (e) { debugPrint('[DeviceDetail] 重命名失败: $e'); }
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('确认'),
        ),
      ],
    ));
  }

  void _showUnbindDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('解绑设备', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
      content: Text('确定要解绑「${widget.name}」吗？解绑后宠物数据将停止同步。',
          style: const TextStyle(fontFamily: 'Plus Jakarta Sans')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await ref.read(deviceRepositoryProvider).unbindDevice(widget.mac);
              ref.read(deviceListProvider.notifier).removeDevice(widget.mac);
              if (mounted) Navigator.pop(context);
            } catch (e) { debugPrint('[DeviceDetail] 解绑失败: $e'); }
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('确认解绑'),
        ),
      ],
    ));
  }
}

class _InfoCell extends StatelessWidget {
  final String label, value;
  const _InfoCell({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceContainerHigh)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10,
          fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant, letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
          fontWeight: FontWeight.w600, color: AppColors.onSurface), overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final Color? color; final bool fullWidth;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.color, this.fullWidth = false});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurface;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withOpacity(0.18))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, fontWeight: FontWeight.w700, color: c)),
        ]),
      ),
    );
  }
}
