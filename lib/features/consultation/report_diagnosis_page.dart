/// ════════════════════════════════════════════════════════════
///  智能医生问诊报告 — 详情页
/// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import 'data/models/consultation_models.dart';

class ReportDiagnosisPage extends StatelessWidget {
  final ConsultationReport report;
  const ReportDiagnosisPage({super.key, required this.report});

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
          '智能医生问诊报告',
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
        ],
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
