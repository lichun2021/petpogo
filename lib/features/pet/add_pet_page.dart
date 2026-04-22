import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pressable.dart';
import '../../app.dart' show AppL10nX;

/// 添加宠物页 — 三步流程：选类型 → 填信息 → 完成
class AddPetPage extends StatefulWidget {
  const AddPetPage({super.key});

  @override
  State<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage>
    with SingleTickerProviderStateMixin {
  int _step = 0; // 0=选类型 1=填信息 2=完成

  // 选择的宠物类型
  int _selectedType = 0;
  final _petTypes = [
    {'emoji': '🐱', 'label': '猫', 'labelEn': 'Cat'},
    {'emoji': '🐶', 'label': '狗', 'labelEn': 'Dog'},
    {'emoji': '🐰', 'label': '兔子', 'labelEn': 'Rabbit'},
    {'emoji': '🐹', 'label': '仓鼠', 'labelEn': 'Hamster'},
    {'emoji': '🐦', 'label': '鸟', 'labelEn': 'Bird'},
    {'emoji': '🐟', 'label': '鱼', 'labelEn': 'Fish'},
    {'emoji': '🦎', 'label': '爬行', 'labelEn': 'Reptile'},
    {'emoji': '🐾', 'label': '其他', 'labelEn': 'Other'},
  ];

  // 步骤2表单
  final _nameCtrl    = TextEditingController();
  final _breedCtrl   = TextEditingController();
  String? _birthday;
  String _gender = '男';
  bool _isLoading = false;

  late AnimationController _successCtrl;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0) {
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (_nameCtrl.text.trim().isEmpty) return;
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() { _isLoading = false; _step = 2; });
    _successCtrl.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _step < 2
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () {
                  if (_step > 0) setState(() => _step--);
                  else context.pop();
                },
              )
            : null,
        title: Text(
          _step == 0 ? '选择宠物类型' : _step == 1 ? '宠物信息' : '添加成功',
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: _step == 0
            ? _buildStep0(l10n)
            : _step == 1
                ? _buildStep1(l10n)
                : _buildStep2(l10n),
      ),
    );
  }

  // ── Step 0: 选宠物类型 ─────────────────────────────
  Widget _buildStep0(dynamic l10n) {
    return Column(
      key: const ValueKey(0),
      children: [
        // 步骤指示器
        _StepIndicator(current: 0, total: 2),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('你的宠物是哪种？',
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 26,
                  fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: -0.5)),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.9,
              ),
              itemCount: _petTypes.length,
              itemBuilder: (_, i) {
                final t = _petTypes[i];
                final selected = _selectedType == i;
                return GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedType = i); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primaryContainer.withOpacity(0.25) : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, spreadRadius: -4)],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t['emoji']!, style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: 6),
                        Text(t['label']!, style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w700,
                          color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
                        )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          child: PrimaryButton(label: '下一步', icon: Icons.arrow_forward_rounded, onPressed: _nextStep),
        ),
      ],
    );
  }

  // ── Step 1: 填写宠物信息 ──────────────────────────
  Widget _buildStep1(dynamic l10n) {
    final selected = _petTypes[_selectedType];
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIndicator(current: 1, total: 2),
          const SizedBox(height: 8),

          // 宠物头像（emoji 大图）
          Center(
            child: Stack(
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 20, spreadRadius: -4)],
                  ),
                  child: Center(child: Text(selected['emoji']!, style: const TextStyle(fontSize: 52))),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2)),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 名字
          _FieldLabel('宠物名字 *'),
          const SizedBox(height: 8),
          _InputField(controller: _nameCtrl, hint: '给宠物起个名字吧', icon: Icons.badge_rounded),
          const SizedBox(height: 20),

          // 品种
          _FieldLabel('品种'),
          const SizedBox(height: 8),
          _InputField(controller: _breedCtrl, hint: '英短 / 金毛 / 不知道', icon: Icons.category_rounded),
          const SizedBox(height: 20),

          // 性别
          _FieldLabel('性别'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10, runSpacing: 8,
            children: ['男', '女', '未知'].map((g) {
              final sel = _gender == g;
              return GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); setState(() => _gender = g); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, spreadRadius: -4)],
                  ),
                  child: Text(g == '男' ? '♂ 男' : g == '女' ? '♀ 女' : '❓ 未知',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : AppColors.onSurfaceVariant)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // 生日
          _FieldLabel('生日（选填）'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365)),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _birthday = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, spreadRadius: -4)],
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(_birthday ?? '选择生日',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                          color: _birthday != null ? AppColors.onSurface : AppColors.onSurfaceVariant)),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          PrimaryButton(
            label: '完成添加',
            icon: Icons.check_rounded,
            isLoading: _isLoading,
            onPressed: _step == 1 ? _nextStep : null,
          ),
        ],
      ),
    );
  }

  // ── Step 2: 成功动画 ──────────────────────────────
  Widget _buildStep2(dynamic l10n) {
    final selected = _petTypes[_selectedType];
    return Center(
      key: const ValueKey(2),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _successScale,
              child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 40, spreadRadius: -4)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(selected['emoji']!, style: const TextStyle(fontSize: 48)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('${_nameCtrl.text} 已添加！',
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 28,
                    fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: -0.5)),
            const SizedBox(height: 12),
            Text('在「我的」页面可以查看和管理你的宠物',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                    color: AppColors.onSurfaceVariant, height: 1.5)),
            const SizedBox(height: 40),

            // 下一步：绑定设备
            PressableButton(
              onTap: () => context.go('/bind-device'),
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary, borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sensors_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('绑定定位设备', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16,
                        fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/profile'),
              child: Text('稍后再说', style: TextStyle(color: AppColors.onSurfaceVariant,
                  fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 步骤指示器 ────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current, total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(total, (i) => Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: i <= current ? AppColors.primary : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        )),
      ),
    );
  }
}

// ── 表单输入框 ────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  const _InputField({required this.controller, required this.hint, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, spreadRadius: -4)],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, color: AppColors.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.onSurfaceVariant, fontFamily: 'Plus Jakarta Sans'),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
        fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant));
  }
}
