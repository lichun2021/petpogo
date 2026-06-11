/// 抓拍 & 打招呼事件数据模型
library;

// ── AI 情绪单条 ─────────────────────────────────────────────
class AiEmotion {
  final String name; // 中文名，如"开心"
  final String emoji; // 如"😊"
  final double confidence; // 0.0~1.0

  const AiEmotion({
    required this.name,
    required this.emoji,
    required this.confidence,
  });

  factory AiEmotion.fromJson(Map<String, dynamic> j) => AiEmotion(
        // 兼容两种格式：
        // 格式A: {name, emoji, confidence}
        // 格式B: {label, label_zh, confidence}  ← 后端实际格式
        name: (j['label_zh'] as String?) ??
            (j['name'] as String?) ??
            (j['emotion'] as String?) ??
            '未知',
        emoji: (j['emoji'] as String?) ?? '🐾',
        confidence: ((j['confidence'] ?? j['score'] ?? 0) as num).toDouble(),
      );
}

// ── AI 情绪分析结果 ──────────────────────────────────────────
class AiEmotionResult {
  final List<AiEmotion> emotions;
  final String captureUrl; // ai_result.capture_url（实际抓拍图片）

  AiEmotion? get top => emotions.isEmpty
      ? null
      : emotions.reduce((a, b) => a.confidence >= b.confidence ? a : b);

  const AiEmotionResult({required this.emotions, this.captureUrl = ''});

  factory AiEmotionResult.fromJson(dynamic raw) {
    if (raw == null) return const AiEmotionResult(emotions: []);
    try {
      final map = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
      // 提取 capture_url
      final captureUrl = (map['capture_url'] as String?) ?? '';
      // 格式1: { emotions: [{label/label_zh/name, confidence},...] }  ← 后端实际
      if (map['emotions'] is List) {
        final list = (map['emotions'] as List)
            .map((e) => AiEmotion.fromJson(e as Map<String, dynamic>))
            .toList();
        return AiEmotionResult(emotions: list, captureUrl: captureUrl);
      }
      // 格式2: { happy: 0.82, calm: 0.35, ... }（直接 key-value）
      const emojiMap = {
        'happy': ('开心', '😊'),
        'calm': ('平静', '😴'),
        'sad': ('伤心', '😢'),
        'excited': ('兴奋', '🎉'),
        'angry': ('生气', '😡'),
        'scared': ('害怕', '😨'),
        'neutral': ('普通', '😐'),
        'curious': ('好奇', '🔍'),
      };
      final list = map.entries.where((e) => e.value is num).map((e) {
        final info = emojiMap[e.key] ?? (e.key, '🐾');
        return AiEmotion(
          name: info.$1,
          emoji: info.$2,
          confidence: (e.value as num).toDouble(),
        );
      }).toList()
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      return AiEmotionResult(
          emotions: list.take(5).toList(), captureUrl: captureUrl);
    } catch (_) {
      return const AiEmotionResult(emotions: []);
    }
  }
}

// ── 自动抓拍单条记录 ─────────────────────────────────────────
class CaptureItem {
  final int id;
  final String deviceId;
  final String eventType; // auto_capture / motion / scheduled
  final String resourceUrl; // 视频/图片 URL
  final String coverUrl; // 封面缩略图
  final AiEmotionResult? aiResult;
  final DateTime createdAt;

  const CaptureItem({
    required this.id,
    required this.deviceId,
    required this.eventType,
    required this.resourceUrl,
    required this.coverUrl,
    this.aiResult,
    required this.createdAt,
  });

  bool get isVideo =>
      resourceUrl.contains('.mp4') ||
      resourceUrl.contains('.mov') ||
      resourceUrl.contains('.avi');

  String get eventTypeLabel {
    switch (eventType) {
      case 'motion':
        return '移动检测';
      case 'scheduled':
        return '定时抓拍';
      default:
        return '自动抓拍';
    }
  }

  factory CaptureItem.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
    final rawAi = j['ai_result'] ?? j['aiResult'];
    final aiResult = rawAi != null ? AiEmotionResult.fromJson(rawAi) : null;
    // resource_url 可能为 null，用 ai_result.capture_url 作为 fallback
    final resourceUrl = (j['resource_url'] as String?) ??
        (j['resourceUrl'] as String?) ??
        aiResult?.captureUrl ??
        '';
    final coverUrl =
        (j['cover_url'] as String?) ?? (j['coverUrl'] as String?) ?? '';
    return CaptureItem(
      id: asInt(j['id']),
      deviceId: j['device_id']?.toString() ?? j['deviceId']?.toString() ?? '',
      eventType: (j['event_type'] as String?) ??
          (j['eventType'] as String?) ??
          'auto_capture',
      resourceUrl: resourceUrl,
      coverUrl: coverUrl,
      aiResult: aiResult,
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// ── 抓拍列表分页结果 ─────────────────────────────────────────
class CaptureListResult {
  final int total;
  final int page;
  final int pageSize;
  final List<CaptureItem> list;

  const CaptureListResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.list,
  });

  bool get hasMore => list.length >= pageSize && (page * pageSize) < total;

  factory CaptureListResult.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
    return CaptureListResult(
      total: asInt(j['total']),
      page: asInt(j['page']),
      pageSize: asInt(j['pageSize']),
      list: ((j['list'] as List?) ?? [])
          .map((e) => CaptureItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── 打招呼单条记录 ───────────────────────────────────────────
class GreetingItem {
  final int id;
  final String deviceId;
  final String resourceUrl; // 招呼音频（用户发给设备的）
  final String responseUrl; // 宠物响应视频（设备录制的）
  final String coverUrl;
  final AiEmotionResult? aiResult;
  final DateTime createdAt;

  const GreetingItem({
    required this.id,
    required this.deviceId,
    required this.resourceUrl,
    required this.responseUrl,
    required this.coverUrl,
    this.aiResult,
    required this.createdAt,
  });

  factory GreetingItem.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
    final rawAi = j['ai_result'] ?? j['aiResult'];
    return GreetingItem(
      id: asInt(j['id']),
      deviceId: j['device_id']?.toString() ?? j['deviceId']?.toString() ?? '',
      resourceUrl:
          (j['resource_url'] as String?) ?? (j['resourceUrl'] as String?) ?? '',
      responseUrl:
          (j['response_url'] as String?) ?? (j['responseUrl'] as String?) ?? '',
      coverUrl: (j['cover_url'] as String?) ?? (j['coverUrl'] as String?) ?? '',
      aiResult: rawAi != null ? AiEmotionResult.fromJson(rawAi) : null,
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// ── 打招呼列表分页结果 ────────────────────────────────────────
class GreetingListResult {
  final int total;
  final int page;
  final int pageSize;
  final List<GreetingItem> list;

  const GreetingListResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.list,
  });

  bool get hasMore => list.length >= pageSize && (page * pageSize) < total;

  factory GreetingListResult.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
    return GreetingListResult(
      total: asInt(j['total']),
      page: asInt(j['page']),
      pageSize: asInt(j['pageSize']),
      list: ((j['list'] as List?) ?? [])
          .map((e) => GreetingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── 声音预设（预设 + 用户自定义合并）────────────────────────
class SoundPreset {
  final int id;
  final String
      emotion; // happy / calm / sad / excited / angry / scared / neutral
  final String name; // 显示名称
  final String url; // 播放地址
  final String petType; // cat / dog
  final String source; // 'preset' | 'user'

  const SoundPreset({
    required this.id,
    required this.emotion,
    required this.name,
    required this.url,
    required this.petType,
    required this.source,
  });

  bool get isUserCustom => source == 'user';

  factory SoundPreset.fromJson(
    Map<String, dynamic> j, {
    String source = 'preset',
    String fallbackPetType = '',
  }) {
    int asInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
    return SoundPreset(
      id: asInt(j['id']),
      emotion: (j['emotion'] as String?) ?? 'neutral',
      name: (j['name'] as String?) ?? '未命名',
      url: (j['url'] as String?) ?? '',
      petType: (j['pet_type'] as String?) ??
          (j['petType'] as String?) ??
          fallbackPetType,
      source: (j['source'] as String?) ?? source,
    );
  }
}
