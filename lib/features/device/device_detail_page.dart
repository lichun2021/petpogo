import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import '../device/data/repository/device_repository.dart';
import '../device/data/models/device_model.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import '../pet/pet_location_page.dart';
import '../pet/bind_pet_sheet.dart';

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
  bool _ringing = false;   // 响铃进行中
  bool _ledOn   = false;   // LED 当前状态（本地 toggle，无法从设备读回）

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo    = ref.read(deviceRepositoryProvider);
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
                      // 宠物区块（始终显示：有宠物显示详情，无宠物显示绑定入口）
                      _buildPetSection(context),
                      const SizedBox(height: 20),
                      if (_otaInfo != null && _otaInfo!.isUpgrade) _buildOtaBanner(),
                      if (_otaInfo != null && _otaInfo!.isUpgrade) const SizedBox(height: 20),
                      const SizedBox(height: 20),
                      // 设备控制（在线时显示）
                      if (_detail?.onlineStatus == true) ...[
                        _buildControls(context),
                        const SizedBox(height: 20),
                      ],
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
        IconButton(icon: const Icon(Icons.refresh_rounded), color: AppColors.onSurfaceVariant, onPressed: _loadAll),
      ],
    );
  }

  Widget _buildStatusHero() {
    final online = _detail?.onlineStatus ?? false;
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7a1f02), Color(0xFFa83206), Color(0xFFff784e)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35),
            blurRadius: 24, spreadRadius: -4, offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        Container(width: 72, height: 72,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
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
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                color: Colors.white.withOpacity(0.65))),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Text(widget.mac, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5))),
      ]),
    );
  }

  Widget _buildInfoGrid() {
    final items = [
      ('设备型号',  _detail?.productKey    ?? '-'),
      ('产品名称',  _detail?.productName   ?? '-'),
      ('固件版本',  _otaInfo?.currentVersion ?? '-'),
      ('商户',      _detail?.merchantName  ?? '-'),
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2,
      children: items.map((e) => _InfoCell(label: e.$1, value: e.$2)).toList(),
    );
  }

  // ── 宠物区块：有宠物显示详情 + 编辑/删除，无宠物显示绑定入口 ──
  Widget _buildPetSection(BuildContext context) {
    final hasPet = _petInfo != null && _petInfo!.petName.isNotEmpty;

    if (!hasPet) {
      return GestureDetector(
        onTap: () async {
          final ok = await PetBindHelper.showAdd(context, mac: widget.mac);
          if (ok) _loadAll();
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(width: 46, height: 46,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 26)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('绑定宠物', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
              Text('点此添加宠物信息，开始跟踪位置、管理围栏',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                      color: AppColors.onSurfaceVariant)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
          ]),
        ),
      );
    }

    final pet = _petInfo!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('绑定的宠物', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        Row(children: [
          _SmallAction(icon: Icons.edit_rounded, label: '编辑', onTap: () async {
            final ok = await PetBindHelper.showEdit(
              context, mac: widget.mac, pet: pet,
            );
            if (ok) _loadAll();
          }),
          const SizedBox(width: 8),
          _SmallAction(icon: Icons.delete_outline_rounded, label: '删除',
              color: AppColors.error, onTap: () => _confirmDeletePet(context, pet)),
        ]),
      ]),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => PetLocationPage(petName: pet.petName, deviceMac: widget.mac),
        )),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceContainerHigh)),
          child: Row(children: [
            Container(width: 46, height: 46,
                decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.25),
                    shape: BoxShape.circle),
                child: pet.avatar.isNotEmpty
                    ? ClipOval(child: Image.network(pet.avatar, fit: BoxFit.cover))
                    : const Icon(Icons.pets_rounded, color: AppColors.primary, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pet.petName, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              Text(
                [if (pet.breed.isNotEmpty) pet.breed,
                 if (pet.age > 0) '${pet.age}岁',
                 if (pet.weight.isNotEmpty) '${pet.weight}kg',
                 if (pet.sex.isNotEmpty) pet.sexDisplay].join(' · '),
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                    color: AppColors.onSurfaceVariant),
              ),
            ])),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('查看位置', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondary)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant, size: 20),
            ]),
          ]),
        ),
      ),
    ]);
  }

  void _confirmDeletePet(BuildContext context, PetInfoModel pet) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('删除宠物', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
      content: Text('确定要删除「${pet.petName}」吗？删除后数据不可恢复。',
          style: const TextStyle(fontFamily: 'Plus Jakarta Sans')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            Navigator.pop(ctx);   // 用 dialog 自己的 ctx，避免 null state 崩溃
            try {
              await ref.read(petPeerRepositoryProvider).deletePet(
                petId: pet.petId.isNotEmpty ? pet.petId : null,
                // 不传 deviceId：避免后端把设备关联一并删除
              );
              await _loadAll();
              if (mounted) PetToast.success(context, '宠物已删除');
            } catch (e) {
              if (mounted) PetToast.error(context, e.toString().replaceAll('Exception: ', ''));
            }
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('删除'),
        ),
      ],
    ));
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

  // ── 设备控制：响铃 + LED ───────────────────────────────────
  Widget _buildControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('设备控制',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        const SizedBox(height: 14),
        Row(children: [
          // 响铃按鈕
          Expanded(
            child: _ControlChip(
              icon: _ringing ? Icons.volume_off_rounded : Icons.notifications_active_rounded,
              label: _ringing ? '停止响铃' : '响铃寻找',
              active: _ringing,
              activeColor: const Color(0xFFFF6B35),
              loading: false,
              onTap: () => _toggleRing(),
            ),
          ),
          const SizedBox(width: 10),
          // LED 开关
          Expanded(
            child: _ControlChip(
              icon: _ledOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
              label: _ledOn ? 'LED 已开' : '开启 LED',
              active: _ledOn,
              activeColor: const Color(0xFFFFD60A),
              loading: false,
              onTap: () => _toggleLed(),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _toggleRing() async {
    final next = !_ringing;
    setState(() => _ringing = next);
    try {
      await ref.read(deviceRepositoryProvider).shadowUpdate(
        mac: widget.mac,
        data: {'ring_tone': next ? '1' : '0'},
      );
    } catch (e) {
      if (mounted) {
        setState(() => _ringing = !next);
        PetToast.error(context, '响铃失败：${e.toString().replaceAll("Exception: ", "")}');
      }
    }
  }

  Future<void> _toggleLed() async {
    final next = !_ledOn;
    setState(() => _ledOn = next);
    try {
      // 三色同时点亮（全亮 = 白光），全关时三色同时关
      await ref.read(deviceRepositoryProvider).shadowUpdate(
        mac: widget.mac,
        data: {
          'led_r': next ? 'true' : 'false',
          'led_g': next ? 'true' : 'false',
          'led_b': next ? 'true' : 'false',
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _ledOn = !next);
        PetToast.error(context, 'LED 控制失败：${e.toString().replaceAll("Exception: ", "")}');
      }
    }
  }

  Widget _buildActions(BuildContext context) {
    final hasPet = _petInfo != null && _petInfo!.petName.isNotEmpty;
    return Column(children: [
      Row(children: [
        Expanded(child: _ActionButton(icon: Icons.edit_rounded, label: '重命名',
            onTap: () => _showRenameDialog(context))),
        const SizedBox(width: 12),
        Expanded(child: _ActionButton(
          icon: Icons.location_on_rounded, label: '查看位置',
          onTap: () {
            final pet = _petInfo;
            if (pet != null && pet.petName.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => PetLocationPage(petName: pet.petName, deviceMac: widget.mac),
              ));
            } else {
              PetToast.warning(context, '请先绑定宠物再查看位置');
            }
          },
        )),
      ]),
      const SizedBox(height: 12),
      // 无宠物时额外显示「绑定宠物」按钮
      if (!hasPet) ...[
        _ActionButton(
          icon: Icons.pets_rounded, label: '绑定宠物',
          color: AppColors.secondary, fullWidth: true,
          onTap: () async {
            final ok = await PetBindHelper.showAdd(context, mac: widget.mac);
            if (ok) _loadAll();
          },
        ),
        const SizedBox(height: 12),
      ],
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

// ── 小操作按钮（用于宠物区块右上角 编辑/删除）────────────
class _SmallAction extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final Color? color;
  const _SmallAction({required this.icon, required this.label, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurfaceVariant;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
              fontWeight: FontWeight.w700, color: c)),
        ]),
      ),
    );
  }
}

// ── 信息格 ─────────────────────────────────────────────────
class _InfoCell extends StatelessWidget {
  final String label, value;
  const _InfoCell({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceContainerHigh)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
        children: [
      Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10,
          fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant, letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
          fontWeight: FontWeight.w600, color: AppColors.onSurface), overflow: TextOverflow.ellipsis),
    ]),
  );
}

// ── 操作大按钮 ─────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  final Color? color; final bool fullWidth;
  const _ActionButton({required this.icon, required this.label, required this.onTap,
      this.color, this.fullWidth = false});
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
          Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
              fontWeight: FontWeight.w700, color: c)),
        ]),
      ),
    );
  }
}

// ── 控制芯片按钮 ──────────────────────────────────────────
class _ControlChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     active;
  final bool     loading;
  final Color    activeColor;
  final VoidCallback onTap;

  const _ControlChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.loading,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? activeColor.withOpacity(0.15)
        : AppColors.surfaceContainerLow;
    final fg = active ? activeColor : AppColors.onSurfaceVariant;

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? activeColor.withOpacity(0.5) : AppColors.surfaceContainerHigh,
            width: 1.5,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          loading
              ? SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              : Icon(icon, color: fg, size: 24),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 12, fontWeight: FontWeight.w700, color: fg,
          )),
        ]),
      ),
    );
  }
}
