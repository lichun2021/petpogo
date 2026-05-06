import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pressable.dart';
import '../../app.dart' show AppL10nX;
import '../pet/controller/pet_controller.dart';


/// 添加宠物页 — 三步流程：选类型 → 填信息 → 完成
class AddPetPage extends ConsumerStatefulWidget {
  const AddPetPage({super.key});

  @override
  ConsumerState<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends ConsumerState<AddPetPage>
    with SingleTickerProviderStateMixin {
  int _step = 0; // 0=选类型 1=填信息 2=完成

  // 目前只支持猫和狗
  int _selectedType = 0;
  final _petTypes = <Map<String, dynamic>>[
    {'emoji': '🐱', 'label': '猫', 'labelEn': 'Cat',  'species': 'cat',
     'desc': '英短、舓斯、无毛、波斯、缅因...', 'color': 0xFFE8F4FD},
    {'emoji': '🐶', 'label': '狗', 'labelEn': 'Dog',  'species': 'dog',
     'desc': '金毛、柯基、法斗、和山、哈士奇...', 'color': 0xFFFFF3E0},
  ];

  // 步骤2表单
  final _nameCtrl    = TextEditingController();
  final _breedCtrl   = TextEditingController();
  String? _birthday;
  String _gender = '公';
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

    final selected = _petTypes[_selectedType];
    final species  = selected['species'] as String;
    // 后端 gender: 1=男 2=女 0=未知
    final genderInt = _gender == '公' ? 1 : 2;

    try {
      final client = ref.read(apiClientProvider);
      await client.post<Map<String, dynamic>>(
        '/sdkapi/pet/create',
        data: {
          'name':     _nameCtrl.text.trim(),
          'species':  species,
          'breed':    _breedCtrl.text.trim(),
          'gender':   genderInt,
          if (_birthday != null) 'birthday': _birthday,
        },
      );

      // 刷新宠物列表（让 profile 页实时更新）
      await ref.read(petControllerProvider.notifier).loadPets();

      if (!mounted) return;
      setState(() { _isLoading = false; _step = 2; });
      _successCtrl.forward();
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加失败：$e',
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _step == 0 ? '选择宠物类型' : _step == 1 ? '宠物信息' : '添加成功',
            key: ValueKey(_step),
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── 进度条：固定不动，仅颜色变化 ─────────────────────
          if (_step < 2) _StepIndicator(current: _step, total: 2),

          // ── 内容区：仅淡入淡出，无位移 ─────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: _step == 0
                  ? _buildStep0(l10n)
                  : _step == 1
                      ? _buildStep1(l10n)
                      : _buildStep2(l10n),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 0: 选宠物类型 ─────────────────────────────
  Widget _buildStep0(dynamic l10n) {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('你的宠物是哪种？',
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 24,
                      fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('目前支持猫和狗的健康监测与AI分析',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                      color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 260,
            child: Row(
              children: List.generate(_petTypes.length, (i) {
                final t = _petTypes[i];
                final selected = _selectedType == i;
                final cardColor = Color(t['color'] as int);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left:  i == 0 ? 0 : 8,
                      right: i == _petTypes.length - 1 ? 0 : 8,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedType = i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: selected ? cardColor : AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: selected ? AppColors.primary : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: selected
                                  ? AppColors.primaryGlow.withOpacity(0.22)
                                  : AppColors.cardShadow,
                              blurRadius: selected ? 20 : 10,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: selected ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 220),
                              // 缩小 emoji 避免卡片太满
                              child: Text(t['emoji']!,
                                  style: const TextStyle(fontSize: 54)),
                            ),
                            const SizedBox(height: 10),
                            Text(t['label']!,
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans', fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? AppColors.primary : AppColors.onSurface,
                                )),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(t['desc']!,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                                    color: AppColors.onSurfaceVariant, height: 1.5,
                                  )),
                            ),
                            // 固定高度占位——避免卡片高度随选择状态变化
                            const SizedBox(height: 12),
                            AnimatedOpacity(
                              opacity: selected ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('✓ 已选择',
                                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 10, fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: PrimaryButton(
              label: '下一步', icon: Icons.arrow_forward_rounded, onPressed: _nextStep),
        ),
      ],
    );
  }

  // ── Step 1: 填写宠物信息 ──────────────────────────
  Widget _buildStep1(dynamic l10n) {
    final selected = _petTypes[_selectedType];
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            spacing: 12, runSpacing: 8,
            children: ['公', '母'].map((g) {
              final sel = _gender == g;
              return GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); setState(() => _gender = g); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, spreadRadius: -4)],
                  ),
                  child: Text(g == '公' ? '♂ 公' : '♀ 母',
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
              onTap: () => context.push('/bind-device'),
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
