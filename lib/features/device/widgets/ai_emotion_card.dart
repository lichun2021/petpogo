/// AI 情绪分析卡片 — 共用组件
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../shared/theme/app_fonts.dart';
import '../data/models/capture_model.dart';

class AiEmotionCard extends StatelessWidget {
  final AiEmotionResult result;
  final DateTime time;

  const AiEmotionCard({
    super.key,
    required this.result,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final emotions = result.emotions.take(5).toList();
    final maxConf = emotions.isEmpty
        ? 1.0
        : emotions.map((e) => e.confidence).reduce(math.max);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF43E97B).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🎭', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text('AI 情绪分析',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
            const Spacer(),
            Text(_relativeTime(time),
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                color: Colors.grey.shade500,
              )),
          ]),
          const SizedBox(height: 14),
          ...emotions.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(children: [
              Row(children: [
                Text(e.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(e.name,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
                const Spacer(),
                Text('${(e.confidence * 100).round()}%',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  )),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maxConf > 0 ? e.confidence / maxConf : 0,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    e == result.top
                        ? const Color(0xFF43E97B)
                        : const Color(0xFF43E97B).withOpacity(0.4),
                  ),
                ),
              ),
            ]),
          )),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours   < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}
