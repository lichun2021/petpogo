/// 医疗检测方案 — 详情页
///
/// 入参：ConsultationReport（来自 GoRouter extra）
///
/// 数据来源：
///   - 顶部：report.primaryDisease（主要疑似疾病）+ symptomSummary
///   - 主体：report.medicalSolutions（markdown 风格的检测方案列表）
///   - 底部：diseaseCards[].diagnosis 汇总（每张卡的诊断方法）

import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import 'data/models/consultation_models.dart';

class ReportMedicalPage extends StatelessWidget {
  final ConsultationReport report;
  const ReportMedicalPage({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final items = _parseSolutions(report.medicalSolutions);

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
          '医疗检测方案',
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
          _HeaderCard(
            disease: report.primaryDisease,
            symptom: report.symptomSummary,
          ),
          const SizedBox(height: 18),
          if (items.isNotEmpty) ...[
            const _SectionLabel(
                icon: Icons.science_outlined, text: '建议检测项目'),
            const SizedBox(height: 8),
            for (var i = 0; i < items.length; i++) ...[
              _MedicalItemCard(item: items[i], index: i + 1),
              if (i < items.length - 1) const SizedBox(height: 10),
            ],
            const SizedBox(height: 18),
          ] else if (report.medicalSolutions.isNotEmpty) ...[
            const _SectionLabel(
                icon: Icons.science_outlined, text: '建议检测项目'),
            const SizedBox(height: 8),
            _PlainTextCard(text: report.medicalSolutions),
            const SizedBox(height: 18),
          ],
          if (report.diseaseCards.any((c) => c.diagnosis.isNotEmpty)) ...[
            const _SectionLabel(
                icon: Icons.biotech_outlined, text: '诊断思路（按疾病）'),
            const SizedBox(height: 8),
            for (final card in report.diseaseCards)
              if (card.diagnosis.isNotEmpty) ...[
                _DiagnosisHintCard(name: card.name, diagnosis: card.diagnosis),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 8),
          ],
          const _FooterNote(),
        ],
      ),
    );
  }

  /// 解析后端返回的 markdown 文本：
  ///   ```
  ///   - **耳道细菌培养**: 用于确定致病菌种类...
  ///   - **耳镜检查**: 直接观察外耳道情况...
  ///   ```
  /// 拆出 (title, desc) 元组。当不带粗体冒号时，title 留空、desc 取整行。
  static List<_MedicalItem> _parseSolutions(String raw) {
    if (raw.trim().isEmpty) return const [];
    final out = <_MedicalItem>[];

    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (final line in lines) {
      // 去掉行首的 - * 数字编号
      var s = line.replaceFirst(RegExp(r'^[\-\*]\s*'), '');
      s = s.replaceFirst(RegExp(r'^\d+[\.\)、]\s*'), '');

      // 尝试匹配 "**标题**: 内容" 或 "**标题**：内容"
      final bold = RegExp(r'^\*\*(.+?)\*\*\s*[:：]\s*(.*)$').firstMatch(s);
      if (bold != null) {
        out.add(_MedicalItem(
          title: bold.group(1)!.trim(),
          desc: bold.group(2)!.trim(),
        ));
        continue;
      }

      // 兼容无加粗：直接按冒号切
      final colon = RegExp(r'^(.+?)\s*[:：]\s*(.+)$').firstMatch(s);
      if (colon != null) {
        out.add(_MedicalItem(
          title: colon.group(1)!.trim(),
          desc: colon.group(2)!.trim(),
        ));
        continue;
      }

      out.add(_MedicalItem(title: '', desc: s));
    }
    return out;
  }
}

class _MedicalItem {
  final String title;
  final String desc;
  const _MedicalItem({required this.title, required this.desc});
}

// ── 顶部摘要 ──────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  final String disease;
  final String symptom;
  const _HeaderCard({required this.disease, required this.symptom});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary,
            AppColors.secondary.withOpacity(0.7),
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
              Icon(Icons.local_hospital_outlined,
                  size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text(
                '建议前往宠物医院进一步确诊',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            disease.isEmpty ? '尚未明确主要疾病' : disease,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          if (symptom.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                symptom,
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

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionLabel({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 6),
        Text(
          text,
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

// ── 检测项目卡片 ──────────────────────────────────────────
class _MedicalItemCard extends StatelessWidget {
  final _MedicalItem item;
  final int index;
  const _MedicalItemCard({required this.item, required this.index});

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.title.isNotEmpty)
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                if (item.title.isNotEmpty && item.desc.isNotEmpty)
                  const SizedBox(height: 4),
                if (item.desc.isNotEmpty)
                  Text(
                    item.desc,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: AppColors.onSurface,
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

// ── 兜底：medicalSolutions 解析失败时直接展示原文 ─────────
class _PlainTextCard extends StatelessWidget {
  final String text;
  const _PlainTextCard({required this.text});
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
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.6,
          color: AppColors.onSurface,
        ),
      ),
    );
  }
}

// ── 诊断思路卡片（按疾病）─────────────────────────────────
class _DiagnosisHintCard extends StatelessWidget {
  final String name;
  final String diagnosis;
  const _DiagnosisHintCard({required this.name, required this.diagnosis});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined,
                  size: 14, color: AppColors.secondary),
              const SizedBox(width: 4),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            diagnosis,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer.withOpacity(0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.tertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '本方案由 AI 综合判断生成，仅供参考。实际检测项目以接诊兽医建议为准。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
