import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_centered_modal.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/pet_toast.dart';
import '../community/data/post_repository.dart';
import 'breed_picker_page.dart';
import 'data/repository/pet_peer_repository.dart';
import 'data/models/pet_peer_models.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

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

  /// 'cat' | 'dog' | null（未选）
  String? _species;

  bool _saving = false;

  // ── 头像──
  File? _avatarFile;
  String? _avatarUrl;
  bool _avatarUploading = false;
  bool _avatarChanged = false; // true = 用户主动上传了新头像

  @override
  void initState() {
    super.initState();
    final p = widget.currentPet;
    _nameCtrl = TextEditingController(text: p?.petName ?? '');
    _breedCtrl = TextEditingController(text: p?.breed ?? '');
    _ageCtrl = TextEditingController(
        text: p != null && p.age > 0 ? p.age.toString() : '');
    _weightCtrl = TextEditingController(text: p?.weight ?? '');
    _sex = (p?.sex.isNotEmpty == true) ? p!.sex : 'GG';
    // 编辑模式：预填现有头像 URL
    _avatarUrl = (p?.avatar.isNotEmpty == true) ? p!.avatar : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // ── 绑定（新建宠物信息）────────────────────────────────────
  // ── 选头像 + 上传 OSS ──────────────────────────────
  Future<void> _pickAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, imageQuality: 85, maxWidth: 512, maxHeight: 512);
    if (picked == null || !mounted) return;
    setState(() => _avatarUploading = true);
    try {
      final file = File(picked.path);
      final repo = ref.read(postRepositoryProvider);
      final sign =
          await repo.getOssSign(fileType: 'image', folder: 'pet_avatars');
      await repo.uploadToOss(
          uploadUrl: sign.uploadUrl, file: file, contentType: 'image/jpeg');
      if (mounted)
        setState(() {
          _avatarFile = file;
          _avatarUrl = sign.cdnUrl;
          _avatarChanged = true; // 标记头像已更换
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
    final src = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('选择头像来源',
            style: TextStyle(
                fontFamily: AppFonts.primary, fontWeight: FontWeight.w700)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
            title: Text('拍照',
                style: TextStyle(
                    fontFamily: AppFonts.primary, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading:
                Icon(Icons.photo_library_rounded, color: AppColors.primary),
            title: Text('从相册选择',
                style: TextStyle(
                    fontFamily: AppFonts.primary, fontWeight: FontWeight.w600)),
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
        mac: widget.deviceMac,
        breed:
            _breedCtrl.text.trim().isNotEmpty ? _breedCtrl.text.trim() : null,
        age: int.tryParse(_ageCtrl.text.trim()),
        weight:
            _weightCtrl.text.trim().isNotEmpty ? _weightCtrl.text.trim() : null,
        sex: _sex,
        avatar: _avatarUrl,
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
      final repo = ref.read(petPeerRepositoryProvider);
      final petId = widget.currentPet!.petId;
      await repo.updatePet(
        petId: petId,
        petName: _nameCtrl.text.trim(),
        breed:
            _breedCtrl.text.trim().isNotEmpty ? _breedCtrl.text.trim() : null,
        age: int.tryParse(_ageCtrl.text.trim()),
        weight:
            _weightCtrl.text.trim().isNotEmpty ? _weightCtrl.text.trim() : null,
        sex: _sex,
        avatar: _avatarChanged ? _avatarUrl : null, // 只有用户主动换头像时才传
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

  @override
  Widget build(BuildContext context) {
    return AppCenteredModalCard(
      child: widget.isEdit ? _buildEditMode() : _buildSelectMode(),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  绑定模式 UI（填写宠物信息，调 PeerApi addPet）
  // ══════════════════════════════════════════════════════════
  Widget _buildSelectMode() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.25),
                        shape: BoxShape.circle),
                    child: Icon(Icons.pets_rounded,
                        color: AppColors.primary, size: 22)),
                SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('绑定宠物',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface)),
                      SizedBox(height: 2),
                      Text('填写宠物信息并绑定到此设备',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant)),
                    ])),
              ]),
              SizedBox(height: 20),

              // ── 头像选择 ──
              Center(
                child: GestureDetector(
                  onTap: _avatarUploading ? null : _showAvatarPicker,
                  child: Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceContainerLow,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.cardShadow,
                                blurRadius: 16,
                                spreadRadius: -4)
                          ],
                        ),
                        child: ClipOval(
                          child: _avatarUploading
                              ? Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.primary))
                              : _avatarFile != null
                                  ? Image.file(_avatarFile!, fit: BoxFit.cover)
                                  : PetAvatar(imageUrl: _avatarUrl, size: 88),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _avatarUrl != null
                                ? Color(0xFF4ADE80)
                                : AppColors.primary,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.surface, width: 2),
                          ),
                          child: Icon(
                              _avatarUrl != null
                                  ? Icons.check_rounded
                                  : Icons.camera_alt_rounded,
                              size: 13,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 4),
              Center(
                child: Text(
                  _avatarUrl != null ? '头像已上传 ✓' : '点击选择头像（选填）',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 11,
                    color: _avatarUrl != null
                        ? Color(0xFF4ADE80)
                        : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 20),

              _label('宠物名字 *'),
              SizedBox(height: 6),
              _field(
                  controller: _nameCtrl,
                  hint: '例：Lucky、小饼干',
                  icon: Icons.badge_rounded),
              SizedBox(height: 14),

              // ── 宠物种类（决定品种列表）──
              _label('宠物种类'),
              SizedBox(height: 8),
              Row(children: [
                _SpeciesChip(
                    label: '🐱 猫',
                    value: 'cat',
                    current: _species,
                    onTap: (v) => setState(() {
                          _species = v;
                          _breedCtrl.clear();
                        })),
                SizedBox(width: 10),
                _SpeciesChip(
                    label: '🐶 狗',
                    value: 'dog',
                    current: _species,
                    onTap: (v) => setState(() {
                          _species = v;
                          _breedCtrl.clear();
                        })),
              ]),
              SizedBox(height: 14),

              _label('品种（选填）'),
              SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  if (_species == null) {
                    PetToast.warning(context, '请先选择宠物种类（猫/狗）');
                    return;
                  }
                  final breed = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BreedPickerPage(species: _species!),
                    ),
                  );
                  if (breed != null) setState(() => _breedCtrl.text = breed);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.category_rounded,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _breedCtrl.text.isEmpty ? '点击选择品种' : _breedCtrl.text,
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 14,
                          color: _breedCtrl.text.isEmpty
                              ? AppColors.onSurfaceVariant.withOpacity(0.5)
                              : AppColors.onSurface,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.onSurfaceVariant, size: 18),
                  ]),
                ),
              ),
              SizedBox(height: 14),

              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _label('年龄（岁）'),
                      SizedBox(height: 6),
                      _field(
                          controller: _ageCtrl,
                          hint: '3',
                          icon: Icons.cake_rounded,
                          inputType: TextInputType.number),
                    ])),
                SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _label('体重（kg）'),
                      SizedBox(height: 6),
                      _field(
                          controller: _weightCtrl,
                          hint: '25.5',
                          icon: Icons.monitor_weight_rounded,
                          inputType: const TextInputType.numberWithOptions(
                              decimal: true)),
                    ])),
              ]),
              SizedBox(height: 14),

              _label('性别'),
              SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _SexChip(
                    label: '♂ 公',
                    value: 'GG',
                    current: _sex,
                    onTap: (v) => setState(() => _sex = v)),
                _SexChip(
                    label: '♀ 母',
                    value: 'MM',
                    current: _sex,
                    onTap: (v) => setState(() => _sex = v)),
                _SexChip(
                    label: '♂ 公(绝育)',
                    value: 'GG_sterilization',
                    current: _sex,
                    onTap: (v) => setState(() => _sex = v)),
                _SexChip(
                    label: '♀ 母(绝育)',
                    value: 'MM_sterilization',
                    current: _sex,
                    onTap: (v) => setState(() => _sex = v)),
              ]),
              SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _saveBind,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('绑定宠物',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  编辑模式 UI（修改已绑定宠物的信息）
  // ══════════════════════════════════════════════════════════
  Widget _buildEditMode() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.25),
                        shape: BoxShape.circle),
                    child: Icon(Icons.edit_rounded,
                        color: AppColors.primary, size: 20)),
                SizedBox(width: 12),
                Text('编辑宠物信息',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
              ]),
              SizedBox(height: 20),

              // ── 头像选择（编辑模式同样支持）──
              Center(
                child: GestureDetector(
                  onTap: _avatarUploading ? null : _showAvatarPicker,
                  child: Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceContainerLow,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.cardShadow,
                                blurRadius: 16,
                                spreadRadius: -4)
                          ],
                        ),
                        child: ClipOval(
                          child: _avatarUploading
                              ? Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.primary))
                              : _avatarFile != null
                                  ? Image.file(_avatarFile!, fit: BoxFit.cover)
                                  : PetAvatar(imageUrl: _avatarUrl, size: 88),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.surface, width: 2),
                          ),
                          child: Icon(Icons.camera_alt_rounded,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 4),
              Center(
                child: Text(
                  _avatarFile != null ? '头像已上传 ✓' : '点击更换头像',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 11,
                    color: _avatarFile != null
                        ? Color(0xFF4ADE80)
                        : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 20),

              _label('宠物名字 *'),
              SizedBox(height: 6),
              _field(
                  controller: _nameCtrl,
                  hint: '例：Lucky',
                  icon: Icons.badge_rounded),
              SizedBox(height: 14),

              // ── 宠物种类 ──
              _label('宠物种类'),
              SizedBox(height: 8),
              Row(children: [
                _SpeciesChip(
                    label: '🐱 猫',
                    value: 'cat',
                    current: _species,
                    onTap: (v) => setState(() {
                          _species = v;
                          _breedCtrl.clear();
                        })),
                SizedBox(width: 10),
                _SpeciesChip(
                    label: '🐶 狗',
                    value: 'dog',
                    current: _species,
                    onTap: (v) => setState(() {
                          _species = v;
                          _breedCtrl.clear();
                        })),
              ]),
              SizedBox(height: 14),

              _label('品种（选填）'),
              SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  if (_species == null) {
                    PetToast.warning(context, '请先选择宠物种类（猫/狗）');
                    return;
                  }
                  final breed = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BreedPickerPage(species: _species!),
                    ),
                  );
                  if (breed != null) setState(() => _breedCtrl.text = breed);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.category_rounded,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _breedCtrl.text.isEmpty ? '点击选择品种' : _breedCtrl.text,
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 14,
                          color: _breedCtrl.text.isEmpty
                              ? AppColors.onSurfaceVariant.withOpacity(0.5)
                              : AppColors.onSurface,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.onSurfaceVariant, size: 18),
                  ]),
                ),
              ),
              SizedBox(height: 14),

              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _label('年龄（岁）'),
                      SizedBox(height: 6),
                      _field(
                          controller: _ageCtrl,
                          hint: '3',
                          icon: Icons.cake_rounded,
                          inputType: TextInputType.number),
                    ])),
                SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _label('体重（kg）'),
                      SizedBox(height: 6),
                      _field(
                          controller: _weightCtrl,
                          hint: '25.5',
                          icon: Icons.monitor_weight_rounded,
                          inputType: const TextInputType.numberWithOptions(
                              decimal: true)),
                    ])),
              ]),
              SizedBox(height: 14),

              _label('性别'),
              SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _SexChip(
                    label: '♂ 公',
                    value: 'GG',
                    current: _sex,
                    onTap: (v) => setState(() => _sex = v)),
                _SexChip(
                    label: '♀ 母',
                    value: 'MM',
                    current: _sex,
                    onTap: (v) => setState(() => _sex = v)),
                _SexChip(
                    label: '♂ 公(绝育)',
                    value: 'GG_sterilization',
                    current: _sex,
                    onTap: (v) => setState(() => _sex = v)),
                _SexChip(
                    label: '♀ 母(绝育)',
                    value: 'MM_sterilization',
                    current: _sex,
                    onTap: (v) => setState(() => _sex = v)),
              ]),
              SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _saveEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('保存修改',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          fontFamily: AppFonts.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurfaceVariant));

  Widget _field(
      {required TextEditingController controller,
      required String hint,
      required IconData icon,
      TextInputType? inputType}) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      style: TextStyle(
          fontFamily: AppFonts.primary,
          fontSize: 14,
          color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: AppColors.onSurfaceVariant.withOpacity(0.5),
            fontFamily: AppFonts.primary),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
        filled: true,
        fillColor: AppColors.surfaceContainer,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ── 种类选项（猫/狗）────────────────────────────────────────
class _SpeciesChip extends StatelessWidget {
  final String label, value;
  final String? current;
  final void Function(String) onTap;
  const _SpeciesChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap(value);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: sel
              ? null
              : Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.4), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: sel ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── 性别选项 ──────────────────────────────────────────────
class _SexChip extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;
  const _SexChip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap(value);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : AppColors.onSurfaceVariant)),
      ),
    );
  }
}

// ── 对外静态入口（保持不变）──────────────────────────────
class PetBindHelper {
  /// 打开「选择绑定宠物」Sheet
  static Future<bool> showAdd(BuildContext context,
      {required String mac}) async {
    final result = await showAppCenteredModal<bool>(
      context: context,
      builder: (_) => BindPetSheet(deviceMac: mac),
    );
    return result == true;
  }

  /// 打开「编辑已绑定宠物」Sheet
  static Future<bool> showEdit(
    BuildContext context, {
    required String mac,
    required PetInfoModel pet,
  }) async {
    final result = await showAppCenteredModal<bool>(
      context: context,
      builder: (_) => BindPetSheet(deviceMac: mac, currentPet: pet),
    );
    return result == true;
  }
}
