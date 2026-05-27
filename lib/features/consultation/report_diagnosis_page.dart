import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import 'data/models/consultation_models.dart';

class ReportDiagnosisPage extends StatelessWidget {
  final ConsultationReport report;
  final PetInfoSnapshot? petInfo;
  final String petAvatar;
  const ReportDiagnosisPage({
    super.key,
    required this.report,
    this.petInfo,
    this.petAvatar = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          '宠小伊问诊报告',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── 宠物信息 Hero 卡──
          if (petInfo != null) ...[
            _PetHeroCard(pet: petInfo!, avatarUrl: petAvatar),
            const SizedBox(height: 16),
          ],
          _SummaryCard(report: report),
          const SizedBox(height: 16),
          _SectionTitle(icon: Icons.description_outlined, title: '综合描述'),
          const SizedBox(height: 8),
          _PlainCard(
            child: Text(
              report.report,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            icon: Icons.local_hospital_outlined,
            title: '可能的疾病 (${report.diseaseCards.length})',
          ),
          const SizedBox(height: 8),
          for (final card in report.diseaseCards) ...[
            _DiseaseCardWidget(card: card),
            const SizedBox(height: 12),
          ],
          if (report.diseaseCards.isEmpty)
            _PlainCard(
              child: Text(
                '本次问诊未给出可能的疾病列表',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          // ── 诊断依据 ───────────────────────────────────────
          if (report.diagnosticBasis.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionTitle(
              icon: Icons.fact_check_outlined,
              title: '诊断依据',
            ),
            const SizedBox(height: 8),
            _DiagnosticBasisCard(basis: report.diagnosticBasis),
          ],
        ],
      ),
    );
  }
}

// ── 宠物信息 Hero 卡（报告顶部）─────────────────────────────
class _PetHeroCard extends StatelessWidget {
  final PetInfoSnapshot pet;
  final String avatarUrl;
  const _PetHeroCard({required this.pet, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final chips = <({String label, String value, Color color})>[
      if (pet.breed.isNotEmpty)
        (label: '品种', value: pet.breed, color: const Color(0xFF6366F1)),
      if (pet.age.isNotEmpty)
        (label: '年龄', value: pet.age, color: const Color(0xFF0EA5E9)),
      if (pet.weight.isNotEmpty)
        (label: '体重', value: '${pet.weight} kg', color: const Color(0xFF10B981)),
      if (pet.gender.isNotEmpty)
        (label: '性别', value: _genderLabel(pet.gender), color: const Color(0xFFF59E0B)),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE9FE), Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── 头像 ───────────────────────────
            _Avatar(avatarUrl: avatarUrl, name: pet.name, gender: pet.gender),
            const SizedBox(width: 16),
            // ── 名字 + 信息标签 ────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          pet.name.isEmpty ? '宠物' : pet.name,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E1B4B),
                            height: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '问诊报告',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 信息标签 Wrap
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: chips.map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: c.color.withOpacity(0.12),
                              blurRadius: 6,
                              spreadRadius: -2,
                            ),
                          ],
                          border: Border.all(
                            color: c.color.withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: RichText(
                          text: TextSpan(children: [
                            TextSpan(
                              text: '${c.label} ',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: c.color,
                              ),
                            ),
                            TextSpan(
                              text: c.value,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E1B4B),
                              ),
                            ),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _genderLabel(String gender) {
    switch (gender.toLowerCase()) {
      case 'gg':
      case '公':
      case 'male':
        return '♂ 公';
      case 'mm':
      case '母':
      case 'female':
        return '♀ 母';
      default:
        return gender;
    }
  }
}

// ── 宠物头像 ──────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String avatarUrl;
  final String name;
  final String gender;
  const _Avatar({
    required this.avatarUrl,
    required this.name,
    required this.gender,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = name.contains('猫') ||
            gender.toLowerCase().contains('cat')
        ? '🐱'
        : name.contains('狗') || gender.toLowerCase().contains('dog')
            ? '🐶'
            : '🐾';

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white,
          width: 2.5,
        ),
      ),
      child: ClipOval(
        child: avatarUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _EmojiAvatar(emoji: emoji),
              )
            : _EmojiAvatar(emoji: emoji),
      ),
    );
  }
}

class _EmojiAvatar extends StatelessWidget {
  final String emoji;
  const _EmojiAvatar({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF6366F1).withOpacity(0.08),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 34)),
      ),
    );
  }
}

// ── 顶部摘要卡 ────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final ConsultationReport report;
  const _SummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary,
            AppColors.secondary.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.medical_information_outlined,
                  size: 16, color: Colors.white70),
              SizedBox(width: 6),
              Text(
                '主要疑似疾病',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            report.primaryDisease.isEmpty ? '—' : report.primaryDisease,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          if (report.symptomSummary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                report.symptomSummary,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _PlainCard extends StatelessWidget {
  final Widget child;
  const _PlainCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            spreadRadius: -4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── 疾病卡片 ──────────────────────────────────────────────
class _DiseaseCardWidget extends StatelessWidget {
  final DiseaseCard card;
  const _DiseaseCardWidget({required this.card});

  Color _probColor(double ratio) {
    if (ratio >= 0.55) return AppColors.error;
    if (ratio >= 0.3) return AppColors.tertiary;
    return AppColors.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = card.probabilityRatio;
    final probColor = _probColor(ratio);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            spreadRadius: -4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      card.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: probColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '患病概率 ${card.probability}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: probColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (card.riskLevel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '风险等级：${card.riskLevel}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: probColor.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(probColor),
                ),
              ),
            ],
          ),
          children: [
            // 字段列表：左侧固定宽度标签列，右侧文本列
            _DiseaseField(label: '定义', value: card.definition),
            _DiseaseField(label: '病因', value: card.cause),
            _DiseaseField(label: '临床表现', value: card.symptoms),
            _DiseaseField(label: '诊断', value: card.diagnosis),
            _DiseaseField(
                label: '治疗方向', value: card.treatment, highlight: true),
          ],
        ),
      ),
    );
  }
}

// ── 疾病字段行（标签固定宽度 + 值列）────────────────────
class _DiseaseField extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _DiseaseField({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();

    final labelColor =
        highlight ? AppColors.secondary : AppColors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧标签（固定宽度，保证对齐）
          SizedBox(
            width: 52,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: labelColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 右侧内容
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 诊断依据卡片 ──────────────────────────────────────────
class _DiagnosticBasisCard extends StatelessWidget {
  final String basis;
  const _DiagnosticBasisCard({required this.basis});

  @override
  Widget build(BuildContext context) {
    // 按换行分段，去除空段
    final paragraphs = basis
        .split(RegExp(r'\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            spreadRadius: -4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左色条
            Container(
              width: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            // 内容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < paragraphs.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 编号标记（多段时显示）
                          if (paragraphs.length > 1) ...[
                            Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.only(top: 1, right: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              paragraphs[i],
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.6,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
