/// 治疗养护建议 — 详情页
///
/// 入参：ConsultationReport（来自 GoRouter extra）
///
/// 数据来源：
///   - 顶部：report.symptomSummary（一句话症状归纳）
///   - 综合建议：report.report
///   - 在家护理：把 diseaseCards[].treatment 拆条 → 给主人能上手做的建议
///
/// 后端目前没有专门的 care_suggestions 字段，这里以"宠小伊小助手"风格
/// 把治疗方向重新组织成"家长可以做什么"的口吻。

import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import 'data/models/consultation_models.dart';

class ReportCarePage extends StatelessWidget {
  final ConsultationReport report;
  const ReportCarePage({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final careItems = _extractCareItems(report);

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
          '治疗养护建议',
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
          _AssistantHeader(symptom: report.symptomSummary),
          const SizedBox(height: 16),
          if (report.report.isNotEmpty) ...[
            const _SectionLabel(icon: Icons.spa_outlined, text: '综合养护建议'),
            const SizedBox(height: 8),
            _ChatBubble(text: report.report),
            const SizedBox(height: 20),
          ],
          if (careItems.isNotEmpty) ...[
            const _SectionLabel(
                icon: Icons.checklist_rounded, text: '家长可以这样做'),
            const SizedBox(height: 8),
            _CareList(items: careItems),
            const SizedBox(height: 20),
          ],
          _FooterNote(),
        ],
      ),
    );
  }

  /// 把每张疾病卡片的 "治疗方向" 拆成可执行的小条目
  static List<_CareItem> _extractCareItems(ConsultationReport r) {
    final out = <_CareItem>[];
    for (final card in r.diseaseCards) {
      if (card.treatment.trim().isEmpty) continue;
      out.add(_CareItem(
        disease: card.name,
        bullets: _splitBullets(card.treatment),
      ));
    }
    return out;
  }

  /// 把"治疗方向"段拆成 bullet 列表
  ///
  /// 兼容三种形态：
  ///   - 已经是 `- xxx` / `* xxx` markdown 列表
  ///   - 用 1. 2. 3. 编号
  ///   - 单段大白话 → 按句号/分号拆
  static List<String> _splitBullets(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return const [];

    final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    final bulleted = lines
        .map((l) => l.replaceFirst(RegExp(r'^[\-\*]\s*'), ''))
        .map((l) => l.replaceFirst(RegExp(r'^\d+[\.\)、]\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();

    if (bulleted.length > 1) return bulleted;

    // 兜底：按中文标点切
    return raw
        .split(RegExp(r'[。；;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

// ── 顶部宠小伊助手气泡 ────────────────────────────────────
class _AssistantHeader extends StatelessWidget {
  final String symptom;
  const _AssistantHeader({required this.symptom});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.secondaryContainer,
          backgroundImage: const AssetImage('assets/images/chongxiaoyi.png'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '我是宠小伊 🐾',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  symptom.isEmpty
                      ? '根据您和我的多轮交流，我整理了一些在家护理的建议，希望对你和它都有帮助。'
                      : '根据「$symptom」的情况，下面是几条在家可以做起来的护理建议。',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

class _ChatBubble extends StatelessWidget {
  final String text;
  const _ChatBubble({required this.text});
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
          fontSize: 14,
          height: 1.6,
          color: AppColors.onSurface,
        ),
      ),
    );
  }
}

// ── 在家护理清单 ──────────────────────────────────────────
class _CareItem {
  final String disease;
  final List<String> bullets;
  const _CareItem({required this.disease, required this.bullets});
}

class _CareList extends StatelessWidget {
  final List<_CareItem> items;
  const _CareList({required this.items});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _DiseaseCareCard(item: items[i]),
          if (i < items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DiseaseCareCard extends StatelessWidget {
  final _CareItem item;
  const _DiseaseCareCard({required this.item});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.disease,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final b in item.bullets) _BulletLine(text: b),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  const _BulletLine({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
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
              '本页内容仅供参考，若症状持续或加重，请尽快前往线下宠物医院进一步检查。',
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
