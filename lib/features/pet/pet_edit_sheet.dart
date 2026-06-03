import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/image_pick_helper.dart';
import '../community/data/post_repository.dart';
import 'controller/pet_controller.dart';
import 'data/models/pet_model.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

/// 宠物编辑底部弹窗：支持修改头像 / 名字 / 品种
class PetEditSheet extends ConsumerStatefulWidget {
  final PetModel pet;
  const PetEditSheet({super.key, required this.pet});

  @override
  ConsumerState<PetEditSheet> createState() => _PetEditSheetState();
}

class _PetEditSheetState extends ConsumerState<PetEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _breedCtrl;

  String  _avatarUrl = '';
  bool    _uploadingAvatar = false;
  bool    _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.pet.name);
    _breedCtrl = TextEditingController(text: widget.pet.breed);
    _avatarUrl = widget.pet.avatar;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    super.dispose();
  }

  // ── 选图 + 裁剪 + 上传头像 ─────────────────────────────
  Future<void> _pickAvatar() async {
    final file = await ImagePickHelper.pickAndCropAvatar(context);
    if (file == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final repo = ref.read(postRepositoryProvider);
      final sign = await repo.getOssSign(fileType: 'image', folder: 'pet_avatars');
      await repo.uploadToOss(uploadUrl: sign.uploadUrl, file: file, contentType: 'image/jpeg');
      if (mounted) setState(() => _avatarUrl = sign.cdnUrl ?? '');
    } catch (e) {
      if (mounted) setState(() => _error = '头像上传失败：$e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ── 保存 ──────────────────────────────────────────────
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = '名字不能为空'); return; }
    setState(() { _saving = true; _error = null; });

    final updated = widget.pet.copyWith(
      name:   name,
      breed:  _breedCtrl.text.trim(),
      avatar: _avatarUrl,
    );
    final result = await ref.read(petControllerProvider.notifier).updatePet(updated);
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.pop(context, true),
      failure: (e) => setState(() { _saving = false; _error = e.toString().replaceAll('Exception: ', ''); }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 拖拽条
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(999)))),
        const SizedBox(height: 20),

        // 标题
        const Align(alignment: Alignment.centerLeft,
            child: Text('编辑宠物信息',
                style: TextStyle(fontFamily: AppFonts.primary,
                    fontSize: 18, fontWeight: FontWeight.w800))),
        const SizedBox(height: 20),

        // 头像选择
        Center(
          child: GestureDetector(
            onTap: _uploadingAvatar ? null : _pickAvatar,
            child: Stack(alignment: Alignment.bottomRight, children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHigh,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12)],
                ),
                child: ClipOval(child: _uploadingAvatar
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                    : _avatarUrl.isNotEmpty
                        ? CachedNetworkImage(imageUrl: _avatarUrl, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const Center(child: Text('🐾', style: TextStyle(fontSize: 42))))
                        : const Center(child: Text('🐾', style: TextStyle(fontSize: 42)))),
              ),
              if (!_uploadingAvatar)
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text('点击更换头像', style: TextStyle(fontFamily: AppFonts.primary,
            fontSize: 12, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 20),

        // 名字输入
        _Field(controller: _nameCtrl, hint: '宠物名字', icon: Icons.pets_rounded),
        const SizedBox(height: 12),
        // 品种输入
        _Field(controller: _breedCtrl, hint: '品种（选填）', icon: Icons.category_rounded),

        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: AppColors.error, fontSize: 13)),
        ],
        const SizedBox(height: 20),

        // 保存按钮
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('保存', style: TextStyle(fontFamily: AppFonts.primary,
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  const _Field({required this.controller, required this.hint, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14)),
    child: TextField(
      controller: controller,
      style: const TextStyle(fontFamily: AppFonts.primary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.onSurfaceVariant,
            fontFamily: AppFonts.primary, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  );
}
