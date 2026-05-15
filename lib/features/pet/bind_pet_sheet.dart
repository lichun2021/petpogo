import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import 'data/repository/pet_peer_repository.dart';

// ── 绑定宠物 BottomSheet ──────────────────────────────────
// 用法：showModalBottomSheet(..., builder: (_) => BindPetSheet(mac: mac))
class BindPetSheet extends ConsumerStatefulWidget {
  final String deviceMac;
  /// 如果传入 petInfo，则为编辑模式
  final _PetFormData? initialData;
  final String? petId;

  const BindPetSheet({
    super.key,
    required this.deviceMac,
    this.initialData,
    this.petId,
  });

  bool get isEdit => initialData != null;

  @override
  ConsumerState<BindPetSheet> createState() => _BindPetSheetState();
}

class _BindPetSheetState extends ConsumerState<BindPetSheet> {
  final _nameCtrl   = TextEditingController();
  final _breedCtrl  = TextEditingController();
  final _ageCtrl    = TextEditingController();
  final _weightCtrl = TextEditingController();

  String _sex = 'GG';
  bool   _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _nameCtrl.text   = d.petName;
      _breedCtrl.text  = d.breed;
      _ageCtrl.text    = d.age > 0 ? d.age.toString() : '';
      _weightCtrl.text = d.weight;
      _sex             = d.sex.isNotEmpty ? d.sex : 'GG';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _breedCtrl.dispose();
    _ageCtrl.dispose();  _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      PetToast.warning(context, '请输入宠物名字');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(petPeerRepositoryProvider);
      final name   = _nameCtrl.text.trim();
      final breed  = _breedCtrl.text.trim();
      final age    = int.tryParse(_ageCtrl.text.trim());
      final weight = _weightCtrl.text.trim();

      if (widget.isEdit && widget.petId != null) {
        await repo.updatePet(
          petId:   widget.petId!,
          petName: name,
          breed:   breed.isNotEmpty ? breed : null,
          age:     age,
          weight:  weight.isNotEmpty ? weight : null,
          sex:     _sex,
        );
      } else {
        await repo.addPet(
          petName: name,
          mac:     widget.deviceMac,
          breed:   breed.isNotEmpty ? breed : null,
          age:     age,
          weight:  weight.isNotEmpty ? weight : null,
          sex:     _sex,
        );
      }
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true); // 返回 true 表示需要刷新
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 拖拽指示条
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.onSurfaceVariant.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),

          // 标题
          Row(children: [
            Container(width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.25), shape: BoxShape.circle),
                child: const Icon(Icons.pets_rounded, color: AppColors.primary, size: 22)),
            const SizedBox(width: 12),
            Text(widget.isEdit ? '编辑宠物信息' : '绑定宠物',
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.onSurface)),
          ]),
          const SizedBox(height: 20),

          // 名字 *
          _label('宠物名字 *'),
          const SizedBox(height: 6),
          _field(controller: _nameCtrl, hint: '例：Lucky、小饼干', icon: Icons.badge_rounded),
          const SizedBox(height: 14),

          // 品种
          _label('品种（选填）'),
          const SizedBox(height: 6),
          _field(controller: _breedCtrl, hint: '金毛、英短、哈士奇...', icon: Icons.category_rounded),
          const SizedBox(height: 14),

          // 年龄 + 体重
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

          // 性别
          _label('性别'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _SexChip(label: '♂ 公',      value: 'GG',               current: _sex, onTap: (v) => setState(() => _sex = v)),
            _SexChip(label: '♀ 母',      value: 'MM',               current: _sex, onTap: (v) => setState(() => _sex = v)),
            _SexChip(label: '♂ 公(绝育)', value: 'GG_sterilization', current: _sex, onTap: (v) => setState(() => _sex = v)),
            _SexChip(label: '♀ 母(绝育)', value: 'MM_sterilization', current: _sex, onTap: (v) => setState(() => _sex = v)),
          ]),
          const SizedBox(height: 22),

          // 保存按钮
          SizedBox(width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.isEdit ? '保存修改' : '绑定宠物',
                      style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w700)),
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
          border: Border.all(color: sel ? AppColors.primary : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
            fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.onSurfaceVariant)),
      ),
    );
  }
}

// ── 内部数据传递模型 ──────────────────────────────────────
class _PetFormData {
  final String petName, breed, weight, sex;
  final int age;
  const _PetFormData({required this.petName, required this.breed, required this.weight,
      required this.sex, required this.age});
}

// ── 对外静态入口 ──────────────────────────────────────────
class PetBindHelper {
  /// 打开「绑定宠物」Sheet，返回是否成功
  static Future<bool> showAdd(BuildContext context, {required String mac}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BindPetSheet(deviceMac: mac),
    );
    return result == true;
  }

  /// 打开「编辑宠物」Sheet，返回是否成功
  static Future<bool> showEdit(BuildContext context, {
    required String mac,
    required String petId,
    required String petName,
    required String breed,
    required int    age,
    required String weight,
    required String sex,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BindPetSheet(
        deviceMac: mac,
        petId:     petId,
        initialData: _PetFormData(
          petName: petName, breed: breed,
          age: age, weight: weight, sex: sex,
        ),
      ),
    );
    return result == true;
  }
}
