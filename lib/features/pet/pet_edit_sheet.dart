import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../community/data/post_repository.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/data/repository/pet_peer_repository.dart';

/// 宠物编辑底部弹窗（基于 PeerApi）
/// 接受 [PetInfoModel]，保存时调用 POST /pet/info/update
class PetEditSheet extends ConsumerStatefulWidget {
  final PetInfoModel pet;
  const PetEditSheet({super.key, required this.pet});

  @override
  ConsumerState<PetEditSheet> createState() => _PetEditSheetState();
}

class _PetEditSheetState extends ConsumerState<PetEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _breedCtrl;
  late final TextEditingController _weightCtrl;

  String  _avatarUrl = '';
  bool    _uploadingAvatar = false;
  bool    _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl   = TextEditingController(text: widget.pet.petName);
    _breedCtrl  = TextEditingController(text: widget.pet.breed);
    _weightCtrl = TextEditingController(text: widget.pet.weight);
    _avatarUrl  = widget.pet.avatar;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // ── 选图 + 裁剪 + 上传头像 ─────────────────────────────
  // 注意：使用 showDialog 而非嵌套 BottomSheet，避免 iOS 上
  //       ViewController 层级错乱导致 ImageCropper 崩溃
  Future<void> _pickAvatar() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('选择图片来源',
            style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w700)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
            title: Text('拍照', style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library_rounded, color: AppColors.primary),
            title: Text('从相册选择', style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    // 选图（限制尺寸，image_picker 内部会压缩）
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null || !mounted) return;

    // 直接上传，UI 层用 ClipOval 圆形显示
    setState(() => _uploadingAvatar = true);
    try {
      final repo = ref.read(postRepositoryProvider);
      final sign = await repo.getOssSign(fileType: 'image', folder: 'pet_avatars');
      await repo.uploadToOss(
        uploadUrl: sign.uploadUrl,
        file: File(picked.path),
        contentType: 'image/jpeg',
      );
      if (mounted) setState(() => _avatarUrl = sign.cdnUrl ?? '');
    } catch (e) {
      if (mounted) setState(() => _error = '头像上传失败：$e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ── 保存（调 PeerApi /pet/info/update）───────────────────
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '名字不能为空');
      return;
    }
    setState(() { _saving = true; _error = null; });

    try {
      await ref.read(petPeerRepositoryProvider).updatePet(
        petId:   widget.pet.petId,
        petName: name,
        breed:   _breedCtrl.text.trim().isNotEmpty  ? _breedCtrl.text.trim()  : null,
        weight:  _weightCtrl.text.trim().isNotEmpty ? _weightCtrl.text.trim() : null,
        avatar:  _avatarUrl.isNotEmpty ? _avatarUrl : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error  = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
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
        Align(
          alignment: Alignment.centerLeft,
          child: Text('编辑宠物信息',
              style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 18, fontWeight: FontWeight.w800)),
        ),
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

        // 名字
        _Field(controller: _nameCtrl,   hint: '宠物名字', icon: Icons.pets_rounded),
        const SizedBox(height: 12),
        // 品种
        _Field(controller: _breedCtrl,  hint: '品种（选填）', icon: Icons.category_rounded),
        const SizedBox(height: 12),
        // 体重
        _Field(controller: _weightCtrl, hint: '体重 kg（选填）', icon: Icons.monitor_weight_outlined,
            keyboardType: TextInputType.number),

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
                : Text('保存', style: TextStyle(fontFamily: AppFonts.primary,
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
  final TextInputType keyboardType;
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14)),
    child: TextField(
      controller:   controller,
      keyboardType: keyboardType,
      style: TextStyle(fontFamily: AppFonts.primary, fontSize: 15),
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
