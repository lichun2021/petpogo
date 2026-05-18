import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import '../community/data/post_repository.dart';
import '../pet/data/models/pet_model.dart';
import 'data/repository/pet_peer_repository.dart';
import 'data/models/pet_peer_models.dart';

// ════════════════════════════════════════════════════════════
//  绑定宠物 Sheet
//  - 绑定模式：从「我的」已建档宠物里选一只，调 PeerApi 绑到设备
//  - 编辑模式：修改当前已绑定宠物的信息（保留原有逻辑）
// ════════════════════════════════════════════════════════════

class BindPetSheet extends ConsumerStatefulWidget {
  final String deviceMac;
  /// 传入表示编辑模式
  final PetInfoModel? currentPet;

  const BindPetSheet({
    super.key,
    required this.deviceMac,
    this.currentPet,
  });

  bool get isEdit => currentPet != null;

  @override
  ConsumerState<BindPetSheet> createState() => _BindPetSheetState();
}

class _BindPetSheetState extends ConsumerState<BindPetSheet> {
  // ── 编辑模式表单 ──────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _breedCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _weightCtrl;
  String _sex = 'GG';

  bool _saving = false;

  // ── 头像──
  File?   _avatarFile;
  String? _avatarUrl;
  bool    _avatarUploading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.currentPet;
    _nameCtrl   = TextEditingController(text: p?.petName ?? '');
    _breedCtrl  = TextEditingController(text: p?.breed   ?? '');
    _ageCtrl    = TextEditingController(text: p != null && p.age > 0 ? p.age.toString() : '');
    _weightCtrl = TextEditingController(text: p?.weight  ?? '');
    _sex        = (p?.sex.isNotEmpty == true) ? p!.sex : 'GG';
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _breedCtrl.dispose();
    _ageCtrl.dispose();  _weightCtrl.dispose();
    super.dispose();
  }

  // ── 绑定（新建宠物信息）────────────────────────────────────
  // ── 选头像 + 上传 OSS ──────────────────────────────
  Future<void> _pickAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85,
        maxWidth: 512, maxHeight: 512);
    if (picked == null || !mounted) return;
    setState(() => _avatarUploading = true);
    try {
      final file = File(picked.path);
      final repo = ref.read(postRepositoryProvider);
      final sign = await repo.getOssSign(fileType: 'image', folder: 'pet_avatars');
      await repo.uploadToOss(uploadUrl: sign.uploadUrl, file: file, contentType: 'image/jpeg');
      if (mounted) setState(() {
        _avatarFile = file;
        _avatarUrl  = sign.cdnUrl;
        _avatarUploading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _avatarUploading = false);
        PetToast.error(context, '头像上传失败：$e');
      }
    }
  }

  Future<void> _showAvatarPicker() async {
    HapticFeedback.mediumImpact();
    final src = await showModalBottomSheet<ImageSource>(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.onSurfaceVariant.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          const Text('选择头像来源', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _SourceBtn(icon: Icons.camera_alt_rounded, label: '拍照',
                onTap: () => Navigator.pop(context, ImageSource.camera))),
            const SizedBox(width: 12),
            Expanded(child: _SourceBtn(icon: Icons.photo_library_rounded, label: '相册',
                onTap: () => Navigator.pop(context, ImageSource.gallery))),
          ]),
        ]),
      ),
    );
    if (src != null) _pickAvatar(src);
  }

  Future<void> _saveBind() async {
    if (_nameCtrl.text.trim().isEmpty) {
      PetToast.warning(context, '请输入宠物名字');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(petPeerRepositoryProvider);
      await repo.addPet(
        petName: _nameCtrl.text.trim(),
        mac:     widget.deviceMac,
        breed:   _breedCtrl.text.trim().isNotEmpty  ? _breedCtrl.text.trim()  : null,
        age:     int.tryParse(_ageCtrl.text.trim()),
        weight:  _weightCtrl.text.trim().isNotEmpty ? _weightCtrl.text.trim() : null,
        sex:     _sex,
        avatar:  _avatarUrl,
      );
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        PetToast.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  // ── 编辑：保存修改 ────────────────────────────────────────
  Future<void> _saveEdit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      PetToast.warning(context, '请输入宠物名字');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo   = ref.read(petPeerRepositoryProvider);
      final petId  = widget.currentPet!.petId;
      await repo.updatePet(
        petId:   petId,
        petName: _nameCtrl.text.trim(),
        breed:   _breedCtrl.text.trim().isNotEmpty ? _breedCtrl.text.trim() : null,
        age:     int.tryParse(_ageCtrl.text.trim()),
        weight:  _weightCtrl.text.trim().isNotEmpty ? _weightCtrl.text.trim() : null,
        sex:     _sex,
      );
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        PetToast.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  /// 「我的」用 male/female，PeerApi 用 GG/MM
  String _mapGender(String gender) {
    switch (gender) {
      case 'male':   return 'GG';
      case 'female': return 'MM';
      default:       return gender; // 已经是 GG/MM 格式则直接返回
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: widget.isEdit ? _buildEditMode() : _buildSelectMode(),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  绑定模式 UI（填写宠物信息，调 PeerApi addPet）
  // ══════════════════════════════════════════════════════════
  Widget _buildSelectMode() {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.onSurfaceVariant.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),

          Row(children: [
            Container(width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.25), shape: BoxShape.circle),
                child: const Icon(Icons.pets_rounded, color: AppColors.primary, size: 22)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('绑定宠物', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              SizedBox(height: 2),
              Text('填写宠物信息并绑定到此设备',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                      color: AppColors.onSurfaceVariant)),
            ])),
          ]),
          const SizedBox(height: 20),

          // ── 头像选择 ──
          Center(
            child: GestureDetector(
              onTap: _avatarUploading ? null : _showAvatarPicker,
              child: Stack(
                children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceContainerLow,
                      boxShadow: [BoxShadow(color: AppColors.cardShadow,
                          blurRadius: 16, spreadRadius: -4)],
                    ),
                    child: ClipOval(
                      child: _avatarUploading
                          ? const Center(child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.primary))
                          : _avatarFile != null
                              ? Image.file(_avatarFile!, fit: BoxFit.cover)
                              : const Center(child: Text('🐾',
                                  style: TextStyle(fontSize: 38))),
                    ),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _avatarUrl != null
                            ? const Color(0xFF4ADE80) : AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: Icon(
                        _avatarUrl != null
                            ? Icons.check_rounded : Icons.camera_alt_rounded,
                        size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _avatarUrl != null ? '头像已上传 ✓' : '点击选择头像（选填）',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                color: _avatarUrl != null ? const Color(0xFF4ADE80) : AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),

          _label('宠物名字 *'),
          const SizedBox(height: 6),
          _field(controller: _nameCtrl, hint: '例：Lucky、小饼干', icon: Icons.badge_rounded),
          const SizedBox(height: 14),

          _label('品种（选填）'),
          const SizedBox(height: 6),
          _field(controller: _breedCtrl, hint: '金毛、英短、哈士奇...', icon: Icons.category_rounded),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('年龄（岁）'),
              const SizedBox(height: 6),
              _field(controller: _ageCtrl, hint: '3', icon: Icons.cake_rounded,
                  inputType: TextInputType.number),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('体重（kg）'),
              const SizedBox(height: 6),
              _field(controller: _weightCtrl, hint: '25.5', icon: Icons.monitor_weight_rounded,
                  inputType: const TextInputType.numberWithOptions(decimal: true)),
            ])),
          ]),
          const SizedBox(height: 14),

          _label('性别'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _SexChip(label: '♂ 公',       value: 'GG',               current: _sex, onTap: (v) => setState(() => _sex = v)),
            _SexChip(label: '♀ 母',       value: 'MM',               current: _sex, onTap: (v) => setState(() => _sex = v)),
            _SexChip(label: '♂ 公(绝育)', value: 'GG_sterilization', current: _sex, onTap: (v) => setState(() => _sex = v)),
            _SexChip(label: '♀ 母(绝育)', value: 'MM_sterilization', current: _sex, onTap: (v) => setState(() => _sex = v)),
          ]),
          const SizedBox(height: 22),

          SizedBox(width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _saveBind,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('绑定宠物', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildNoPets() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🐾', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text('还没有建档的宠物', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        const SizedBox(height: 6),
        Text('先为宠物建档，再绑定到设备',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {
            // Sheet 不再显示「去添加宠物」按钮（_buildNoPets 已不被调用）
            Navigator.pop(context);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('去添加宠物', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  编辑模式 UI（修改已绑定宠物的信息）
  // ══════════════════════════════════════════════════════════
  Widget _buildEditMode() {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.onSurfaceVariant.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),

          Row(children: [
            Container(width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.25), shape: BoxShape.circle),
                child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20)),
            const SizedBox(width: 12),
            const Text('编辑宠物信息', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          ]),
          const SizedBox(height: 20),

          _label('宠物名字 *'),
          const SizedBox(height: 6),
          _field(controller: _nameCtrl, hint: '例：Lucky', icon: Icons.badge_rounded),
          const SizedBox(height: 14),

          _label('品种（选填）'),
          const SizedBox(height: 6),
          _field(controller: _breedCtrl, hint: '金毛、英短...', icon: Icons.category_rounded),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('年龄（岁）'),
              const SizedBox(height: 6),
              _field(controller: _ageCtrl, hint: '3', icon: Icons.cake_rounded,
                  inputType: TextInputType.number),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('体重（kg）'),
              const SizedBox(height: 6),
              _field(controller: _weightCtrl, hint: '25.5', icon: Icons.monitor_weight_rounded,
                  inputType: const TextInputType.numberWithOptions(decimal: true)),
            ])),
          ]),
          const SizedBox(height: 14),

          _label('性别'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _SexChip(label: '♂ 公',       value: 'GG',               current: _sex, onTap: (v) => setState(() => _sex = v)),
            _SexChip(label: '♀ 母',       value: 'MM',               current: _sex, onTap: (v) => setState(() => _sex = v)),
            _SexChip(label: '♂ 公(绝育)', value: 'GG_sterilization', current: _sex, onTap: (v) => setState(() => _sex = v)),
            _SexChip(label: '♀ 母(绝育)', value: 'MM_sterilization', current: _sex, onTap: (v) => setState(() => _sex = v)),
          ]),
          const SizedBox(height: 22),

          SizedBox(width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _saveEdit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('保存修改', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant));

  Widget _field({required TextEditingController controller, required String hint,
      required IconData icon, TextInputType? inputType}) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withOpacity(0.5), fontFamily: 'Plus Jakarta Sans'),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
        filled: true, fillColor: AppColors.surfaceContainer,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ── 宠物选择卡片 ──────────────────────────────────────────
class _PetSelectCard extends StatelessWidget {
  final PetModel pet;
  final bool saving;
  final VoidCallback onTap;
  const _PetSelectCard({required this.pet, required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isMale = pet.gender == 'male';
    final gLabel = isMale ? '♂ 公' : pet.gender == 'female' ? '♀ 母' : '';
    final gColor = isMale ? const Color(0xFF1565C0) : const Color(0xFFC2185B);

    return GestureDetector(
      onTap: saving ? null : onTap,
      child: AnimatedOpacity(
        opacity: saving ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.onSurfaceVariant.withOpacity(0.1)),
          ),
          child: Row(children: [
            // 头像 / emoji
            Container(width: 48, height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5)),
              child: ClipOval(child: pet.avatar.isNotEmpty
                  ? CachedNetworkImage(imageUrl: pet.avatar, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _emoji(pet.name))
                  : _emoji(pet.name)),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(pet.name, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                if (gLabel.isNotEmpty) ...[ const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: gColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(gLabel, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 10, fontWeight: FontWeight.w700, color: gColor))),
                ],
              ]),
              const SizedBox(height: 3),
              Text(
                [if (pet.breed.isNotEmpty) pet.breed,
                 if (pet.type.isNotEmpty) _speciesLabel(pet.type)].join(' · '),
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                    color: AppColors.onSurfaceVariant),
              ),
            ])),
            // 选择箭头
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('选择', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _emoji(String name) => Container(
      color: AppColors.primary.withOpacity(0.15),
      child: Center(child: Text(
        name.contains('猫') || name.toLowerCase().contains('cat') ? '🐱'
            : name.contains('狗') || name.toLowerCase().contains('dog') ? '🐶' : '🐾',
        style: const TextStyle(fontSize: 22))));

  String _speciesLabel(String type) {
    switch (type) {
      case 'cat':     return '猫';
      case 'dog':     return '狗';
      case 'rabbit':  return '兔子';
      case 'hamster': return '仓鼠';
      default:        return type;
    }
  }
}

// ── 性别选项 ──────────────────────────────────────────────
class _SexChip extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;
  const _SexChip({required this.label, required this.value, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(value); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
            fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.onSurfaceVariant)),
      ),
    );
  }
}

// ── 对外静态入口（保持不变）──────────────────────────────
class PetBindHelper {
  /// 打开「选择绑定宠物」Sheet
  static Future<bool> showAdd(BuildContext context, {required String mac}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BindPetSheet(deviceMac: mac),
    );
    return result == true;
  }

  /// 打开「编辑已绑定宠物」Sheet
  static Future<bool> showEdit(BuildContext context, {
    required String mac,
    required PetInfoModel pet,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BindPetSheet(deviceMac: mac, currentPet: pet),
    );
    return result == true;
  }
}

class _SourceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.primary, size: 26),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        ]),
      ),
    );
  }
}
