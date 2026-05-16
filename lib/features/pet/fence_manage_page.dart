import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import 'fence_add_flow.dart';

// ── 围栏管理页 ────────────────────────────────────────────
class FenceManagePage extends ConsumerStatefulWidget {
  final String deviceMac;
  final String petName;
  const FenceManagePage({super.key, required this.deviceMac, required this.petName});

  @override
  ConsumerState<FenceManagePage> createState() => _FenceManagePageState();
}

class _FenceManagePageState extends ConsumerState<FenceManagePage> {
  List<FenceModel> _fences = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _loadFences(); }

  Future<void> _loadFences() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ref.read(petPeerRepositoryProvider)
          .fetchFences(mac: widget.deviceMac);
      if (mounted) setState(() { _fences = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20), color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context)),
        title: Text('${widget.petName} 的围栏',
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          if (_loading)
            const Padding(padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
          else
            IconButton(icon: const Icon(Icons.refresh_rounded), color: AppColors.onSurfaceVariant,
                onPressed: _loadFences),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            onPressed: () => _showAddFenceSheet(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.add_location_alt_rounded, size: 22),
            label: const Text('添加围栏', style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _fences.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5));
    }
    if (_error != null && _fences.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _loadFences, child: const Text('重试')),
      ]));
    }
    if (_fences.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadFences,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: _fences.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _FenceCard(
          fence: _fences[i],
          onEdit:   () => _showEditFenceSheet(context, _fences[i]),
          onDelete: () => _confirmDelete(context, _fences[i]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.fence_rounded, size: 72, color: AppColors.onSurfaceVariant.withOpacity(0.35)),
      const SizedBox(height: 16),
      const Text('还没有围栏', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
      const SizedBox(height: 8),
      const Text('添加围栏后，宠物越界会收到提醒', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
          fontSize: 13, color: AppColors.onSurfaceVariant)),
    ]));
  }

  void _showAddFenceSheet(BuildContext context) async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => FenceMapPickerPage(deviceMac: widget.deviceMac),
    ));
    if (result == true) _loadFences();
  }

  void _showEditFenceSheet(BuildContext context, FenceModel fence) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _FenceFormSheet(
        title: '编辑围栏',
        initialName: fence.fenceName,
        initialRadius: fence.radius,
        initialAddress: fence.address,
        onSave: (name, radius, address) async {
          Navigator.pop(context);
          try {
            await ref.read(petPeerRepositoryProvider).updateFence(
              fenceId: fence.fenceId, fenceName: name, radius: radius, address: address,
            );
            await _loadFences();
          } catch (e) { debugPrint('[Fence] 更新失败: $e'); }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, FenceModel fence) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除围栏',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
        content: Text('确定删除「${fence.fenceName}」围栏吗？',
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogCtx); // 用 dialog 自身 context 关闭
              try {
                await ref.read(petPeerRepositoryProvider).deleteFence(fence.fenceId);
                if (mounted) await _loadFences();
              } catch (e) { debugPrint('[Fence] 删除失败: $e'); }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

// ── 围栏卡片 ──────────────────────────────────────────────
class _FenceCard extends StatelessWidget {
  final FenceModel fence;
  final VoidCallback onEdit, onDelete;
  const _FenceCard({required this.fence, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.surfaceContainerHigh)),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 12, 8), child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.fence_rounded, color: AppColors.primary, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fence.fenceName, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            if (fence.address.isNotEmpty)
              Text(fence.address, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF4ADE80).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('活跃', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
          ),
        ])),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.radio_button_checked_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('半径 ${fence.displayRadius}', style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
            const Spacer(),
            Text('${fence.latitude}°N  ${fence.longitude}°E',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.onSurfaceVariant)),
          ]),
        ),
        Divider(height: 1, color: AppColors.surfaceContainerHigh),
        Row(children: [
          Expanded(child: TextButton.icon(onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('编辑'),
              style: TextButton.styleFrom(foregroundColor: AppColors.onSurfaceVariant))),
          Container(width: 1, height: 32, color: AppColors.surfaceContainerHigh),
          Expanded(child: TextButton.icon(onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16), label: const Text('删除'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error))),
        ]),
      ]),
    );
  }
}

// ── 围栏表单 ──────────────────────────────────────────────
class _FenceFormSheet extends StatefulWidget {
  final String title;
  final String? initialName, initialRadius, initialAddress;
  final void Function(String name, String radius, String address) onSave;
  const _FenceFormSheet({required this.title, required this.onSave,
      this.initialName, this.initialRadius, this.initialAddress});

  @override
  State<_FenceFormSheet> createState() => _FenceFormSheetState();
}

class _FenceFormSheetState extends State<_FenceFormSheet> {
  late final TextEditingController _nameCtrl, _radiusCtrl, _addressCtrl;
  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController(text: widget.initialName    ?? '');
    _radiusCtrl  = TextEditingController(text: widget.initialRadius  ?? '200');
    _addressCtrl = TextEditingController(text: widget.initialAddress ?? '');
  }
  @override
  void dispose() { _nameCtrl.dispose(); _radiusCtrl.dispose(); _addressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(widget.title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        _buildField(label: '围栏名称', controller: _nameCtrl, hint: '如：家、公司、学校'),
        const SizedBox(height: 12),
        _buildField(label: '半径 (米)', controller: _radiusCtrl, hint: '200', inputType: TextInputType.number),
        const SizedBox(height: 12),
        _buildField(label: '地址描述', controller: _addressCtrl, hint: '例：上海市静安区南京西路'),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.secondary),
              const SizedBox(width: 8),
              const Expanded(child: Text('围栏中心将设为当前设备位置',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.secondary))),
            ])),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            if (_nameCtrl.text.isEmpty) return;
            HapticFeedback.mediumImpact();
            widget.onSave(_nameCtrl.text,
                _radiusCtrl.text.isEmpty ? '200' : _radiusCtrl.text,
                _addressCtrl.text);
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('保存', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _buildField({required String label, required TextEditingController controller,
      String? hint, TextInputType? inputType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
          fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
      const SizedBox(height: 6),
      TextField(controller: controller, keyboardType: inputType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withOpacity(0.5)),
            filled: true, fillColor: AppColors.surfaceContainer,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          )),
    ]);
  }
}
