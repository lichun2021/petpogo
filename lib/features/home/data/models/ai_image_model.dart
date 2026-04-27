/// ════════════════════════════════════════════════════════════
///  AI 狗图像情绪分析结果模型
///
///  对应接口：POST http://49.234.39.11:8002/dog/analyze
///
///  返回结构：
///    - primary_emotion  → 主情绪（13类）
///    - top3             → Top-3 情绪列表
///    - all_predictions  → 全部 13 类置信度 map
///    - advice           → 照顾建议（中文）
///    - ensemble_size    → 集成模型数量
///    - processing_time_ms → 服务端耗时
/// ════════════════════════════════════════════════════════════

// ── 13 类狗情绪 ───────────────────────────────────────────
enum DogEmotion {
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

  static DogEmotion fromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'alert':        return DogEmotion.alert;
      case 'angry':        return DogEmotion.angry;
      case 'anticipation': return DogEmotion.anticipation;
      case 'anxiety':      return DogEmotion.anxiety;
      case 'appeasement':  return DogEmotion.appeasement;
      case 'caution':      return DogEmotion.caution;
      case 'confident':    return DogEmotion.confident;
      case 'curiosity':    return DogEmotion.curiosity;
      case 'fear':         return DogEmotion.fear;
      case 'happy':        return DogEmotion.happy;
      case 'relaxed':      return DogEmotion.relaxed;
      case 'sad':          return DogEmotion.sad;
      case 'sleepy':       return DogEmotion.sleepy;
      default:             return DogEmotion.relaxed;
    }
  }

  String get displayName {
    const names = {
      DogEmotion.alert:        '警觉',
      DogEmotion.angry:        '愤怒',
      DogEmotion.anticipation: '期待',
      DogEmotion.anxiety:      '焦虑',
      DogEmotion.appeasement:  '顺从',
      DogEmotion.caution:      '谨慎',
      DogEmotion.confident:    '自信',
      DogEmotion.curiosity:    '好奇',
      DogEmotion.fear:         '恐惧',
      DogEmotion.happy:        '快乐',
      DogEmotion.relaxed:      '放松',
      DogEmotion.sad:          '悲伤',
      DogEmotion.sleepy:       '困倦',
    };
    return names[this] ?? '未知';
  }

  String get emoji {
    const emojis = {
      DogEmotion.alert:        '👀',
      DogEmotion.angry:        '😠',
      DogEmotion.anticipation: '🤩',
      DogEmotion.anxiety:      '😰',
      DogEmotion.appeasement:  '🙏',
      DogEmotion.caution:      '⚠️',
      DogEmotion.confident:    '😎',
      DogEmotion.curiosity:    '🔍',
      DogEmotion.fear:         '😨',
      DogEmotion.happy:        '😄',
      DogEmotion.relaxed:      '😌',
      DogEmotion.sad:          '😢',
      DogEmotion.sleepy:       '😴',
    };
    return emojis[this] ?? '🐾';
  }

  int get colorHex {
    const colors = {
      DogEmotion.alert:        0xFF2196F3, // 蓝
      DogEmotion.angry:        0xFFF44336, // 红
      DogEmotion.anticipation: 0xFFFF9800, // 橙
      DogEmotion.anxiety:      0xFF9C27B0, // 紫
      DogEmotion.appeasement:  0xFF607D8B, // 灰蓝
      DogEmotion.caution:      0xFFFF5722, // 深橙
      DogEmotion.confident:    0xFF009688, // 青
      DogEmotion.curiosity:    0xFF03A9F4, // 浅蓝
      DogEmotion.fear:         0xFF673AB7, // 深紫
      DogEmotion.happy:        0xFF4CAF50, // 绿
      DogEmotion.relaxed:      0xFF8BC34A, // 浅绿
      DogEmotion.sad:          0xFF78909C, // 蓝灰
      DogEmotion.sleepy:       0xFF9E9E9E, // 灰
    };
    return colors[this] ?? 0xFF9E9E9E;
  }
}

// ── 单个情绪预测项 ─────────────────────────────────────────
class DogEmotionPrediction {
  final String label;
  final String labelZh;
  final double confidence;

  const DogEmotionPrediction({
    required this.label,
    required this.labelZh,
    required this.confidence,
  });

  factory DogEmotionPrediction.fromJson(Map<String, dynamic> json) =>
      DogEmotionPrediction(
        label:      (json['label']      as String?) ?? 'unknown',
        labelZh:    (json['label_zh']   as String?) ?? '未知',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      );

  String get percentText => '${(confidence * 100).toStringAsFixed(0)}%';
}

// ── 完整图像分析结果 ──────────────────────────────────────
/// 对应 POST /dog-image/analyze 的返回体
class DogImageAnalysisResult {
  final DogEmotion primaryEmotion;
  final DogEmotionPrediction primaryPrediction;
  final List<DogEmotionPrediction> top3;
  /// 全部 13 类情绪，按置信度从高到低排列（来自 all_predictions）
  final List<DogEmotionPrediction> allPredictions;
  final String advice;
  final int ensembleSize;
  final double processingTimeMs;

  const DogImageAnalysisResult({
    required this.primaryEmotion,
    required this.primaryPrediction,
    required this.top3,
    required this.allPredictions,
    required this.advice,
    required this.ensembleSize,
    required this.processingTimeMs,
  });

  factory DogImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    final primaryRaw = json['primary_emotion'] as Map<String, dynamic>? ?? {};
    final primaryPred = DogEmotionPrediction.fromJson(primaryRaw);

    final top3Raw = json['top3'] as List? ?? [];
    final top3List = top3Raw
        .whereType<Map<String, dynamic>>()
        .map(DogEmotionPrediction.fromJson)
        .toList();

    // 解析 all_predictions map → 列表（按置信度降序）
    final allRaw = json['all_predictions'] as Map<String, dynamic>? ?? {};
    final allList = allRaw.entries.map((e) {
      final label = e.key;
      final conf  = (e.value as num?)?.toDouble() ?? 0.0;
      return DogEmotionPrediction(
        label:      label,
        labelZh:    DogEmotion.fromLabel(label).displayName,
        confidence: conf,
      );
    }).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return DogImageAnalysisResult(
      primaryEmotion:    DogEmotion.fromLabel(primaryPred.label),
      primaryPrediction: primaryPred,
      top3:              top3List,
      allPredictions:    allList,
      advice:            (json['advice'] as String?) ?? '请继续观察狗狗的状态。',
      ensembleSize:      (json['ensemble_size'] as int?) ?? 0,
      processingTimeMs:  (json['processing_time_ms'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
