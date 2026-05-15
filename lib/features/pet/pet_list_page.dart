import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../device/data/repository/device_repository.dart';
import '../device/data/models/device_model.dart';
import '../device/device_list_page.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import '../pet/data/models/pet_peer_models.dart';

// ════════════════════════════════════════════════════════════
//  宠物列表页 — 宠物依附于设备（PeerApi）
//  从设备列表中加载每台设备绑定的宠物
// ════════════════════════════════════════════════════════════

// ── 宠物 + 所属设备的组合模型 ────────────────────────────
class _PetWithDevice {
  final PetInfoModel pet;
  final DeviceModel  device;
  const _PetWithDevice({required this.pet, required this.device});
}

class PetListPage extends ConsumerStatefulWidget {
  const PetListPage({super.key});

  @override
  ConsumerState<PetListPage> createState() => _PetListPageState();
}

class _PetListPageState extends ConsumerState<PetListPage> {
  List<_PetWithDevice> _pets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // 1. 获取设备列表
      final devices = ref.read(deviceListProvider).devices;
      final petRepo = ref.read(petPeerRepositoryProvider);

      // 2. 并发拉取每个设备的宠物
      final results = <_PetWithDevice>[];
      await Future.wait(devices.map((d) async {
        try {
          final pet = await petRepo.fetchPetInfo(deviceId: d.deviceId);
          if (pet.petName.isNotEmpty) {
            results.add(_PetWithDevice(pet: pet, device: d));
          }
        } catch (_) {
          // 该设备未绑定宠物，跳过
        }
      }));

      if (mounted) setState(() { _pets = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _refresh() async {
    // 先刷新设备列表，再刷新宠物
    await ref.read(deviceListProvider.notifier).load();
    await _load();
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
        title: const Text('我的宠物',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          if (_loading)
            const Padding(padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.onSurfaceVariant,
              onPressed: _refresh,
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.onSurfaceVariant),
        const SizedBox(height: 12),
        Text('加载失败', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        const SizedBox(height: 8),
        Text(_error!, style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton(onPressed: _load,
            child: const Text('重试', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700))),
      ]));
    }
    if (_pets.isEmpty) {
      return _buildEmpty(context);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        itemCount: _pets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) => _PetCard(data: _pets[i]),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    // 检查是否有设备
    final hasDevices = ref.read(deviceListProvider).devices.isNotEmpty;
    return Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🐾', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 20),
        Text(
          hasDevices ? '设备还没有绑定宠物' : '还没有绑定任何设备',
          style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          hasDevices
              ? '点击设备卡片上的「绑定宠物」给设备绑定宠物'
              : '先绑定智能项圈或机器人，再为宠物建档',
          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
              color: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => const DeviceListPage(),
            ));
          },
          icon: const Icon(Icons.devices_rounded),
          label: Text(hasDevices ? '去绑定宠物' : '去添加设备',
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]),
    ));
  }
}

// ── 宠物卡片 ──────────────────────────────────────────────
class _PetCard extends StatelessWidget {
  final _PetWithDevice data;
  const _PetCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pet    = data.pet;
    final device = data.device;

    final isMale   = pet.sex == 'GG' || pet.sex == 'GG_sterilization';
    final isFemale = pet.sex == 'MM' || pet.sex == 'MM_sterilization';
    final gLabel   = isMale ? '♂ 公' : isFemale ? '♀ 母' : '';
    final gColor   = isMale ? const Color(0xFF1565C0) : const Color(0xFFC2185B);
    final gBg      = isMale ? const Color(0xFFDCEEFF)  : const Color(0xFFFFDCEE);

    // 设备类型渐变
    final isCat = pet.breed.contains('猫') || pet.breed.toLowerCase().contains('cat');
    final gradient = isCat
        ? [const Color(0xFF6EC6F5), const Color(0xFF4A90D9)]
        : [const Color(0xFFFFB347), const Color(0xFFE07B39)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: gradient.first.withOpacity(0.35),
            blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 6))],
      ),
      child: Stack(children: [
        Positioned(right: -20, top: -20,
          child: Container(width: 100, height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.10)))),

        Padding(padding: const EdgeInsets.all(18), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // 头像
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2)),
                child: ClipOval(
                  child: pet.avatar.isNotEmpty
                      ? Image.network(pet.avatar, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                              child: Text('🐾', style: TextStyle(fontSize: 26))))
                      : const Center(child: Text('🐾', style: TextStyle(fontSize: 26))),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(pet.petName,
                      style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                          fontSize: 18, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: -0.3))),
                  if (gLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: gBg, borderRadius: BorderRadius.circular(12)),
                      child: Text(gLabel, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11, fontWeight: FontWeight.w800, color: gColor)),
                    ),
                ]),
                if (pet.breed.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(pet.breed, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12, color: Colors.white.withOpacity(0.8))),
                ],
              ])),
            ]),
            const SizedBox(height: 12),

            // 标签行
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (pet.age > 0)    _Chip(Icons.cake_rounded, '${pet.age}岁'),
              if (pet.weight.isNotEmpty) _Chip(Icons.monitor_weight_outlined, '${pet.weight}kg'),
              if (pet.sex.isNotEmpty)
                _Chip(Icons.pets_rounded, pet.sexDisplay),
            ]),

            const SizedBox(height: 10),
            // 所属设备
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.router_rounded, size: 12, color: Colors.white70),
                const SizedBox(width: 5),
                Text(device.deviceNickname.isNotEmpty ? device.deviceNickname : device.mac,
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        )),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: Colors.white),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    ]),
  );
}
