/// ════════════════════════════════════════════════════════════
///  AI 宠物图像情绪分析结果模型（猫 + 狗）
///
///  对应接口：POST /pet-image/analyze  (dog-image / cat-image 均适用)
///
///  返回结构：
///    - primary_emotion  → 主情绪
///    - top3             → Top-3 情绪列表
///    - all_predictions  → 全部类别置信度 map
///    - advice           → 照顾建议（中文）
///    - ensemble_size    → 集成模型数量
///    - processing_time_ms → 服务端耗时
/// ════════════════════════════════════════════════════════════

// ── 情绪类别（狗 13 类 / 猫 7 类共用标签集） ─────────────────
enum PetEmotion {
  alert,        // 警觉
  angry,        // 愤怒
  anticipation, // 期待
  anxiety,      // 焦虑
  appeasement,  // 顺从
  caution,      // 谨慎
  confident,    // 自信
  curiosity,    // 好奇
  fear,         // 恐惧
  happy,        // 快乐
  relaxed,      // 放松
  sad,          // 悲伤
  sleepy;       // 困倦

  static PetEmotion fromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'alert':        return PetEmotion.alert;
      case 'angry':        return PetEmotion.angry;
      case 'anticipation': return PetEmotion.anticipation;
      case 'anxiety':      return PetEmotion.anxiety;
      case 'appeasement':  return PetEmotion.appeasement;
      case 'caution':      return PetEmotion.caution;
      case 'confident':    return PetEmotion.confident;
      case 'curiosity':    return PetEmotion.curiosity;
      case 'fear':         return PetEmotion.fear;
      case 'happy':        return PetEmotion.happy;
      case 'relaxed':      return PetEmotion.relaxed;
      case 'sad':          return PetEmotion.sad;
      case 'sleepy':       return PetEmotion.sleepy;
      default:             return PetEmotion.relaxed;
    }
  }

  String get displayName {
    const names = {
      PetEmotion.alert:        '警觉',
      PetEmotion.angry:        '愤怒',
      PetEmotion.anticipation: '期待',
      PetEmotion.anxiety:      '焦虑',
      PetEmotion.appeasement:  '顺从',
      PetEmotion.caution:      '谨慎',
      PetEmotion.confident:    '自信',
      PetEmotion.curiosity:    '好奇',
      PetEmotion.fear:         '恐惧',
      PetEmotion.happy:        '快乐',
      PetEmotion.relaxed:      '放松',
      PetEmotion.sad:          '悲伤',
      PetEmotion.sleepy:       '困倦',
    };
    return names[this] ?? '未知';
  }

  String get emoji {
    const emojis = {
      PetEmotion.alert:        '👀',
      PetEmotion.angry:        '😠',
      PetEmotion.anticipation: '🤩',
      PetEmotion.anxiety:      '😰',
      PetEmotion.appeasement:  '🙏',
      PetEmotion.caution:      '⚠️',
      PetEmotion.confident:    '😎',
      PetEmotion.curiosity:    '🔍',
      PetEmotion.fear:         '😨',
      PetEmotion.happy:        '😄',
      PetEmotion.relaxed:      '😌',
      PetEmotion.sad:          '😢',
      PetEmotion.sleepy:       '😴',
    };
    return emojis[this] ?? '🐾';
  }

  int get colorHex {
    const colors = {
      PetEmotion.alert:        0xFF2196F3, // 蓝
      PetEmotion.angry:        0xFFF44336, // 红
      PetEmotion.anticipation: 0xFFFF9800, // 橙
      PetEmotion.anxiety:      0xFF9C27B0, // 紫
      PetEmotion.appeasement:  0xFF607D8B, // 灰蓝
      PetEmotion.caution:      0xFFFF5722, // 深橙
      PetEmotion.confident:    0xFF009688, // 青
      PetEmotion.curiosity:    0xFF03A9F4, // 浅蓝
      PetEmotion.fear:         0xFF673AB7, // 深紫
      PetEmotion.happy:        0xFF4CAF50, // 绿
      PetEmotion.relaxed:      0xFF8BC34A, // 浅绿
      PetEmotion.sad:          0xFF78909C, // 蓝灰
      PetEmotion.sleepy:       0xFF9E9E9E, // 灰
    };
    return colors[this] ?? 0xFF9E9E9E;
  }
}

// ── 单个情绪预测项 ─────────────────────────────────────────
class PetEmotionPrediction {
  final String label;
  final String labelZh;
  final double confidence;

  const PetEmotionPrediction({
    required this.label,
    required this.labelZh,
    required this.confidence,
  });

  factory PetEmotionPrediction.fromJson(Map<String, dynamic> json) =>
      PetEmotionPrediction(
        label:      (json['label']      as String?) ?? 'unknown',
        labelZh:    (json['label_zh']   as String?) ?? '未知',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      );

  String get percentText => '${(confidence * 100).toStringAsFixed(0)}%';
}

// ── 完整图像分析结果 ──────────────────────────────────────
/// 对应 POST /dog-image/analyze 或 /cat-image/analyze 的返回体
class PetImageAnalysisResult {
  final PetEmotion primaryEmotion;
  final PetEmotionPrediction primaryPrediction;
  final List<PetEmotionPrediction> top3;
  /// 全部情绪类别，按置信度从高到低排列（来自 all_predictions）
  final List<PetEmotionPrediction> allPredictions;
  final String advice;
  final int ensembleSize;
  final double processingTimeMs;

  const PetImageAnalysisResult({
    required this.primaryEmotion,
    required this.primaryPrediction,
    required this.top3,
    required this.allPredictions,
    required this.advice,
    required this.ensembleSize,
    required this.processingTimeMs,
  });

  factory PetImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    final primaryRaw = json['primary_emotion'] as Map<String, dynamic>? ?? {};
    final primaryPred = PetEmotionPrediction.fromJson(primaryRaw);

    final top3Raw = json['top3'] as List? ?? [];
    final top3List = top3Raw
        .whereType<Map<String, dynamic>>()
        .map(PetEmotionPrediction.fromJson)
        .toList();

    // 解析 all_predictions map → 列表（按置信度降序）
    final allRaw = json['all_predictions'] as Map<String, dynamic>? ?? {};
    final allList = allRaw.entries.map((e) {
      final label = e.key;
      final conf  = (e.value as num?)?.toDouble() ?? 0.0;
      return PetEmotionPrediction(
        label:      label,
        labelZh:    PetEmotion.fromLabel(label).displayName,
        confidence: conf,
      );
    }).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return PetImageAnalysisResult(
      primaryEmotion:    PetEmotion.fromLabel(primaryPred.label),
      primaryPrediction: primaryPred,
      top3:              top3List,
      allPredictions:    allList,
      advice:            (json['advice'] as String?) ?? '请继续观察宠物的状态。',
      ensembleSize:      (json['ensemble_size'] as int?) ?? 0,
      processingTimeMs:  (json['processing_time_ms'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
