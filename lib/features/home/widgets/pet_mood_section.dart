import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/theme/app_colors.dart';
import '../../auth/controller/auth_controller.dart';
import '../../pet/controller/pet_controller.dart';
import '../../pet/data/models/pet_model.dart';
import '../data/ai_image_result_provider.dart';
import '../data/models/ai_image_model.dart';

/// 首页宠物情绪卡片区
/// - 监听 auth 状态：登录后自动加载宠物，解决首次打开不显示问题
/// - 全宽 PageView + 圆点指示，与其他组件等宽
class PetMoodSection extends ConsumerStatefulWidget {
  const PetMoodSection({super.key});

  @override
  ConsumerState<PetMoodSection> createState() => _PetMoodSectionState();
}

class _PetMoodSectionState extends ConsumerState<PetMoodSection> {
  int _page = 0;
  late final PageController _ctrl;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authControllerProvider).isLoggedIn;
    final petState   = ref.watch(petControllerProvider);
    final lastResult = ref.watch(aiImageResultProvider);

    // 登录后首次加载（auth 就绪时再调，避免 token 未准备报错）
    if (isLoggedIn && !_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(petControllerProvider.notifier).loadPets();
      });
    }

    if (!isLoggedIn) return const SizedBox.shrink();

    if (petState.isLoading) {
      return const SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (petState.pets.isEmpty) return const SizedBox.shrink();

    final pets = petState.pets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 标题行 ──────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('我的宠物',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20, fontWeight: FontWeight.w700,
                    letterSpacing: -0.3, color: AppColors.onSurface)),
            if (lastResult != null)
              _EmotionBadge(emotion: lastResult.primaryEmotion),
          ],
        ),
        const SizedBox(height: 12),

        // ── 全宽 PageView ────────────────────────────────
        SizedBox(
          height: 88,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: pets.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _HomePetCard(
              pet: pets[i],
              result: lastResult,
            ),
          ),
        ),

        // ── 圆点指示（多宠物时显示）─────────────────────
        if (pets.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pets.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width:  i == _page ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _page
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant.withOpacity(0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            )),
          ),
        ],

        // ── AI 情绪建议横幅 ──────────────────────────────
        if (lastResult != null) ...[
          const SizedBox(height: 12),
          _EmotionAdviceBanner(result: lastResult),
        ],
      ],
    );
  }
}

// ── 首页宠物卡 ────────────────────────────────────────────
class _HomePetCard extends StatelessWidget {
  final PetModel pet;
  final PetImageAnalysisResult? result;
  const _HomePetCard({required this.pet, this.result});

  List<Color> get _gradients => pet.type == 'cat'
      ? [const Color(0xFF6EC6F5), const Color(0xFF4A90D9)]
      : [const Color(0xFFFFB347), const Color(0xFFE07B39)];

  String _ageText() {
    if (pet.birthday.isEmpty) return '';
    try {
      final birth = DateTime.parse(pet.birthday);
      final now   = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) age--;
      if (age <= 0) {
        final months = (now.year - birth.year) * 12 + now.month - birth.month;
        return months <= 0 ? '刚出生' : '$months个月';
      }
      return '$age岁';
    } catch (_) { return ''; }
  }

  Future<void> _openAmap() async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(
      'https://uri.amap.com/search?q=${Uri.encodeComponent("宠物公园")}'
      '&t=0&src=petpogo&callnative=1',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(
        Uri.parse('https://www.amap.com/search?query=${Uri.encodeComponent("宠物公园")}'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final age     = _ageText();
    final emotion = result?.primaryEmotion;
    final isMale  = pet.gender == 'male';
    final isFemale = pet.gender == 'female';
    final gLabel  = isMale ? '♂ 公' : isFemale ? '♀ 母' : '';
    final gBg     = isMale ? const Color(0xFFDCEEFF) : const Color(0xFFFFDCEE);
    final gColor  = isMale ? const Color(0xFF1A6BB5) : const Color(0xFFB51A6B);

    // 年龄行：情绪 chip 或年龄，右侧加位置按钮
    final ageLabel = emotion != null
        ? '${emotion.emoji} ${emotion.displayName}'
        : age;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: _gradients,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _gradients.first.withOpacity(0.40),
            blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 装饰圆
          Positioned(
            right: -14, top: -14,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.09),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                // ── 左：emoji 圆 + 情绪角标 ──────────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58, height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.30),
                            blurRadius: 10, spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(pet.emoji,
                            style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                    if (emotion != null)
                      Positioned(
                        bottom: -2, right: -2,
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: Color(emotion.colorHex),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text(emotion.emoji,
                                style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // ── 右：名字 / 信息行 ────────────────────
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名字 + 性别
                      Row(
                        children: [
                          Expanded(
                            child: Text(pet.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 14, fontWeight: FontWeight.w900,
                                    color: Colors.white, letterSpacing: -0.2)),
                          ),
                          if (gLabel.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: gBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(gLabel,
                                    style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 10, fontWeight: FontWeight.w800,
                                        color: gColor)),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 5),

                      // 年龄 chip + 位置（同一行）
                      Row(
                        children: [
                          if (ageLabel.isNotEmpty) ...[
                            _WChip(label: ageLabel),
                            const SizedBox(width: 8),
                          ],
                          GestureDetector(
                            onTap: _openAmap,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 11, color: Colors.white),
                                const SizedBox(width: 2),
                                Text('查看位置',
                                    style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 10, fontWeight: FontWeight.w700,
                                        color: Colors.white.withOpacity(0.85))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 白色半透明小标签
class _WChip extends StatelessWidget {
  final String label;
  const _WChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.22),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label,
        style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 10, fontWeight: FontWeight.w700,
            color: Colors.white)),
  );
}

// ── 情绪标签（标题右侧）────────────────────────────────────
class _EmotionBadge extends StatelessWidget {
  final PetEmotion emotion;
  const _EmotionBadge({required this.emotion});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Color(emotion.colorHex).withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Color(emotion.colorHex).withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emotion.emoji, style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 4),
      Text(emotion.displayName,
          style: TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 11, fontWeight: FontWeight.w700,
              color: Color(emotion.colorHex))),
    ]),
  );
}

// ── AI 情绪建议横幅 ───────────────────────────────────────
class _EmotionAdviceBanner extends StatelessWidget {
  final PetImageAnalysisResult result;
  const _EmotionAdviceBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final emotion = result.primaryEmotion;
    final color   = Color(emotion.colorHex);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emotion.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 情绪分析 · ${emotion.displayName}',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12, fontWeight: FontWeight.w800,
                        color: color, letterSpacing: 0.3)),
                const SizedBox(height: 3),
                Text(result.advice,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12, color: AppColors.onSurfaceVariant,
                        height: 1.5)),
                const SizedBox(height: 8),
                ...result.top3.take(3).map((p) {
                  final e = PetEmotion.fromLabel(p.label);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      SizedBox(width: 36,
                          child: Text(p.labelZh,
                              style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant))),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: p.confidence, minHeight: 5,
                            backgroundColor:
                                AppColors.outlineVariant.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(e.colorHex).withOpacity(0.7)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(p.percentText,
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: color)),
                    ]),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
