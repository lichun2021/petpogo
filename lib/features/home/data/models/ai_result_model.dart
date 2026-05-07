/// ════════════════════════════════════════════════════════════
///  AI 分析结果统一模型
///
///  对应后端接口：
///    POST /sdkapi/ai/voice-analyze  → 语音分析
///    POST /sdkapi/ai/image-analyze  → 图像分析
///
///  两个接口返回结构相同，共用此模型。
///  后端在 AI 调用成功后才扣减配额，返回 _quota 字段。
/// ════════════════════════════════════════════════════════════

// ── 情绪预测项 ────────────────────────────────────────────
class AiEmotionItem {
  final String label;
  final String labelZh;
  final double confidence;

  const AiEmotionItem({
    required this.label,
    required this.labelZh,
    required this.confidence,
  });

  factory AiEmotionItem.fromJson(Map<String, dynamic> json) => AiEmotionItem(
    label:      (json['label']      as String?) ?? 'unknown',
    labelZh:    (json['label_zh']   as String?) ?? '未知',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
  );

  String get percentText => '${(confidence * 100).toStringAsFixed(0)}%';
}

// ── AI 配额（随每次分析结果一起返回）─────────────────────
class AiQuotaInfo {
  final int used;
  final int limit;      // -1 = VIP 无限
  final int remaining;  // -1 = VIP 无限

  const AiQuotaInfo({
    required this.used,
    required this.limit,
    required this.remaining,
  });

  bool get isUnlimited => limit == -1;

  factory AiQuotaInfo.fromJson(Map<String, dynamic> json) => AiQuotaInfo(
    used:      (json['used']      as int?) ?? 0,
    limit:     (json['limit']     as int?) ?? 10,
    remaining: (json['remaining'] as int?) ?? 0,
  );
}

// ── 统一 AI 分析结果 ──────────────────────────────────────
/// 语音和图像接口共用的结果结构
class AiAnalysisResult {
  /// 分析记录 ID（服务端生成，用于查询历史）
  final String id;

  /// 主情绪
  final AiEmotionItem primaryEmotion;

  /// Top-3 情绪列表
  final List<AiEmotionItem> top3;

  /// AI 照顾建议
  final String advice;

  /// 集成模型数量（图像用，语音为 0）
  final int ensembleSize;

  /// AI 服务处理耗时（毫秒）
  final int processingMs;

  /// 本次分析后剩余配额
  final AiQuotaInfo quota;

  const AiAnalysisResult({
    required this.id,
    required this.primaryEmotion,
    required this.top3,
    required this.advice,
    required this.ensembleSize,
    required this.processingMs,
    required this.quota,
  });

  factory AiAnalysisResult.fromJson(Map<String, dynamic> json) {
    // 主情绪
    final emotionRaw = json['emotion'] as Map<String, dynamic>? ?? {};
    final primary = AiEmotionItem.fromJson(emotionRaw);

    // Top-3
    final top3Raw = json['top3'] as List? ?? [];
    final top3 = top3Raw
        .whereType<Map<String, dynamic>>()
        .map(AiEmotionItem.fromJson)
        .toList();

    // 配额
    final quotaRaw = json['_quota'] as Map<String, dynamic>? ?? {};

    return AiAnalysisResult(
      id:             (json['id']          as String?) ?? '',
      primaryEmotion: primary,
      top3:           top3,
      advice:         (json['advice']      as String?) ?? '',
      ensembleSize:   (json['ensembleSize'] as int?)   ?? 0,
      processingMs:   (json['processingMs'] as int?)   ?? 0,
      quota:          AiQuotaInfo.fromJson(quotaRaw),
    );
  }

  /// 主情绪对应 emoji
  String get primaryEmoji => _emojiMap[primaryEmotion.label] ?? '🐾';

  /// 主情绪颜色值
  int get primaryColorHex => _colorMap[primaryEmotion.label] ?? 0xFF9E9E9E;

  static const _emojiMap = <String, String>{
    'alert':        '👀',
    'angry':        '😠',
    'anticipation': '🤩',
    'anxiety':      '😰',
    'appeasement':  '🙏',
    'caution':      '⚠️',
    'confident':    '😎',
    'curiosity':    '🔍',
    'fear':         '😨',
    'happy':        '😄',
    'relaxed':      '😌',
    'sad':          '😢',
    'sleepy':       '😴',
    'excited':      '🥳',
    'anxious':      '😰',
    'aggressive':   '😡',
    'pain':         '😣',
  };

  static const _colorMap = <String, int>{
    'alert':        0xFF2196F3,
    'angry':        0xFFF44336,
    'anticipation': 0xFFFF9800,
    'anxiety':      0xFF9C27B0,
    'appeasement':  0xFF607D8B,
    'caution':      0xFFFF5722,
    'confident':    0xFF009688,
    'curiosity':    0xFF03A9F4,
    'fear':         0xFF673AB7,
    'happy':        0xFF4CAF50,
    'relaxed':      0xFF8BC34A,
    'sad':          0xFF78909C,
    'sleepy':       0xFF9E9E9E,
    'excited':      0xFFFF6B35,
    'anxious':      0xFF9C27B0,
    'aggressive':   0xFFF44336,
    'pain':         0xFFE91E63,
  };
}
