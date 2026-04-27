/// ════════════════════════════════════════════════════════════
///  AI 语音分析结果模型
///
///  对应接口：POST http://49.234.39.11:8002/analyze
///
///  返回结构：
///    - species       → 识别出的物种（猫 / 狗）
///    - emotions      → Top-3 情绪列表（置信度从高到低）
///    - primary_emotion → 最高置信度情绪（= emotions[0]）
///    - advice        → AI 照顾建议（中文字符串）
///    - duration_seconds → 音频时长
/// ════════════════════════════════════════════════════════════

// ── 支持的物种 ────────────────────────────────────────────
/// 接口只返回猫和狗两种，其他物种不在识别范围内
enum PetSpecies {
  cat,  // label: 'cat'  / label_zh: '猫'
  dog,  // label: 'dog'  / label_zh: '狗'
  unknown;

  /// 从接口返回的 label 字符串解析
  static PetSpecies fromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'cat': return PetSpecies.cat;
      case 'dog': return PetSpecies.dog;
      default:    return PetSpecies.unknown;
    }
  }

  /// 显示名称（中文）
  String get displayName {
    switch (this) {
      case PetSpecies.cat: return '猫咪';
      case PetSpecies.dog: return '狗狗';
      case PetSpecies.unknown: return '未知';
    }
  }

  /// 对应 emoji
  String get emoji {
    switch (this) {
      case PetSpecies.cat: return '🐱';
      case PetSpecies.dog: return '🐶';
      case PetSpecies.unknown: return '🐾';
    }
  }
}

// ── 支持的 6 种情绪 ───────────────────────────────────────
/// 固定 6 种，服务端不会返回其他情绪
enum PetEmotion {
  relaxed,    // 放松
  excited,    // 兴奋
  anxious,    // 焦虑
  alert,      // 警觉
  aggressive, // 攻击性
  pain;       // 疼痛

  /// 从接口返回的 label 字符串解析
  static PetEmotion fromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'relaxed':    return PetEmotion.relaxed;
      case 'excited':    return PetEmotion.excited;
      case 'anxious':    return PetEmotion.anxious;
      case 'alert':      return PetEmotion.alert;
      case 'aggressive': return PetEmotion.aggressive;
      case 'pain':       return PetEmotion.pain;
      default:           return PetEmotion.relaxed;
    }
  }

  /// 中文显示名称
  String get displayName {
    const names = {
      PetEmotion.relaxed:    '放松',
      PetEmotion.excited:    '兴奋',
      PetEmotion.anxious:    '焦虑',
      PetEmotion.alert:      '警觉',
      PetEmotion.aggressive: '攻击性',
      PetEmotion.pain:       '疼痛',
    };
    return names[this] ?? '未知';
  }

  /// 情绪对应 emoji
  String get emoji {
    const emojis = {
      PetEmotion.relaxed:    '😌',
      PetEmotion.excited:    '🤩',
      PetEmotion.anxious:    '😰',
      PetEmotion.alert:      '👀',
      PetEmotion.aggressive: '😾',
      PetEmotion.pain:       '😿',
    };
    return emojis[this] ?? '🐾';
  }

  /// 情绪对应颜色（用于进度条 / 标签背景）
  int get colorHex {
    const colors = {
      PetEmotion.relaxed:    0xFF4CAF50, // 绿色 — 积极
      PetEmotion.excited:    0xFFFF9800, // 橙色 — 活跃
      PetEmotion.anxious:    0xFF9C27B0, // 紫色 — 需关注
      PetEmotion.alert:      0xFF2196F3, // 蓝色 — 专注
      PetEmotion.aggressive: 0xFFF44336, // 红色 — 危险
      PetEmotion.pain:       0xFFE91E63, // 粉红 — 紧急
    };
    return colors[this] ?? 0xFF9E9E9E;
  }

  /// 给主人的简短行动建议（UI 提示条用）
  String get quickTip {
    const tips = {
      PetEmotion.relaxed:    '状态很好，继续保持！',
      PetEmotion.excited:    '它很兴奋，可以一起玩耍！',
      PetEmotion.anxious:    '它有些焦虑，给予安慰吧',
      PetEmotion.alert:      '它在警戒，检查周围环境',
      PetEmotion.aggressive: '它有攻击倾向，保持距离',
      PetEmotion.pain:       '⚠️ 可能感到疼痛，请及时就医',
    };
    return tips[this] ?? '';
  }
}

// ── API 响应的单个预测项 ──────────────────────────────────
/// 对应 Prediction schema：{ label, label_zh, confidence }
class AiPrediction {
  /// 英文标签（如 'cat', 'relaxed'）
  final String label;

  /// 中文标签（如 '猫', '放松'）—— 直接来自服务端
  final String labelZh;

  /// 置信度 0.0 ~ 1.0
  final double confidence;

  const AiPrediction({
    required this.label,
    required this.labelZh,
    required this.confidence,
  });

  factory AiPrediction.fromJson(Map<String, dynamic> json) => AiPrediction(
    label:      (json['label']      as String?)  ?? 'unknown',
    labelZh:    (json['label_zh']   as String?)  ?? '未知',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
  );

  /// 置信度百分比（用于 UI 显示，如 "87%"）
  String get percentText => '${(confidence * 100).toStringAsFixed(0)}%';
}

// ── 完整分析结果 ─────────────────────────────────────────
/// 对应 POST /analyze 的返回体
class AiAnalysisResult {
  /// 物种识别结果（枚举 + 原始预测）
  final PetSpecies species;
  final AiPrediction speciesPrediction;

  /// Top-3 情绪列表（置信度从高到低）
  final List<AiPrediction> emotions;

  /// 主情绪（= emotions.first，单独解析方便 UI 使用）
  final PetEmotion primaryEmotion;
  final AiPrediction primaryEmotionPrediction;

  /// AI 照顾建议（中文，直接显示给用户）
  final String advice;

  /// 音频时长（秒）
  final double durationSeconds;

  /// 服务端处理耗时（毫秒，用于调试）
  final double processingTimeMs;

  const AiAnalysisResult({
    required this.species,
    required this.speciesPrediction,
    required this.emotions,
    required this.primaryEmotion,
    required this.primaryEmotionPrediction,
    required this.advice,
    required this.durationSeconds,
    required this.processingTimeMs,
  });

  /// 默认/空白预测项（字段为 null 时的兜底）
  static AiPrediction _emptyPred(String label) => AiPrediction(
    label: label, labelZh: '未知', confidence: 0.0,
  );

  factory AiAnalysisResult.fromJson(Map<String, dynamic> json) {
    // ── 物种（服务端偶尔返回 null，录音太短或无法识别时）
    final speciesRaw = json['species'];
    final speciesPred = speciesRaw is Map<String, dynamic>
        ? AiPrediction.fromJson(speciesRaw)
        : _emptyPred('unknown');

    // ── 主情绪
    final primaryRaw = json['primary_emotion'];
    final primaryPred = primaryRaw is Map<String, dynamic>
        ? AiPrediction.fromJson(primaryRaw)
        : _emptyPred('relaxed');

    // ── 情绪列表
    final emotionsRaw = json['emotions'];
    final emotionList = emotionsRaw is List
        ? emotionsRaw
            .whereType<Map<String, dynamic>>()
            .map(AiPrediction.fromJson)
            .toList()
        : <AiPrediction>[];

    return AiAnalysisResult(
      species:                  PetSpecies.fromLabel(speciesPred.label),
      speciesPrediction:        speciesPred,
      emotions:                 emotionList,
      primaryEmotion:           PetEmotion.fromLabel(primaryPred.label),
      primaryEmotionPrediction: primaryPred,
      advice:           (json['advice'] as String?) ?? '录音时间过短，请重新录制 2 秒以上',
      durationSeconds:  (json['duration_seconds'] as num?)?.toDouble() ?? 0.0,
      processingTimeMs: (json['processing_time_ms'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
