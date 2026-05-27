/// ════════════════════════════════════════════════════════════
///  宠小伊 AI 问诊 — 数据模型
///
///  后端：http://49.234.39.11:8007 (v0.4+)
///  API 统一响应格式：{ code: int, info: object|null, tip: string }
///  Repository 层负责解包，Model 只处理 info 内的业务字段。
///
///  v0.4 主要变化：
///    - /session/new 改为 POST，pet_info 字段精简
///    - disease_card 改为英文 key，probability 为 int(0-100)，新增 risk_level
///    - 新增历史记录模型：ConsultationSessionSummary / HistoryTurn / SessionHistory
/// ════════════════════════════════════════════════════════════

import 'dart:convert';

// ── 1. Session ────────────────────────────────────────────

/// `/session/new` 返回的会话信息（从 info 字段解析）
class ConsultationSession {
  final String sessionId;
  final String petId;
  final PetInfoSnapshot petInfo;

  const ConsultationSession({
    required this.sessionId,
    required this.petId,
    required this.petInfo,
  });

  factory ConsultationSession.fromJson(Map<String, dynamic> json) {
    return ConsultationSession(
      sessionId: (json['session_id'] as String?) ?? '',
      petId:     (json['pet_id'] as String?) ?? '',
      petInfo:   PetInfoSnapshot.fromJson(
        (json['pet_info'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

/// 宠物档案快照（v0.4 精简字段：name/breed/age/gender/weight，均为可选字符串）
///
/// 真实示例：
/// ```json
/// { "name":"帕奇", "breed":"英短", "age":"2岁", "weight":"4.5", "gender":"公" }
/// ```
class PetInfoSnapshot {
  final String name;
  final String breed;
  final String age;
  final String gender;
  final String weight;

  const PetInfoSnapshot({
    required this.name,
    required this.breed,
    required this.age,
    required this.gender,
    required this.weight,
  });

  factory PetInfoSnapshot.fromJson(Map<String, dynamic> json) {
    return PetInfoSnapshot(
      name:   (json['name'] as String?) ?? '',
      breed:  (json['breed'] as String?) ?? '',
      age:    (json['age'] as String?) ?? '',
      gender: (json['gender'] as String?) ?? '',
      weight: (json['weight'] as String?) ?? '',
    );
  }
}

// ── 2. 对话消息 ───────────────────────────────────────────

enum ChatRole { user, assistant }

/// 一条聊天消息（前端展示用，不直接对应后端字段）
class ChatMessage {
  final ChatRole role;

  /// 文本内容；assistant 流式输出期间会持续追加
  final String content;

  /// 是否处于流式接收中（true 时显示打字机光标，禁用输入框）
  final bool isStreaming;

  final DateTime createdAt;

  const ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
    required this.createdAt,
  });

  ChatMessage copyWith({String? content, bool? isStreaming}) => ChatMessage(
        role: role,
        content: content ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
        createdAt: createdAt,
      );
}

// ── 3. SSE 流式事件 ───────────────────────────────────────

sealed class ConsultationStreamEvent {
  const ConsultationStreamEvent();
}

class StreamStart extends ConsultationStreamEvent {
  final String userInput;
  const StreamStart(this.userInput);
}

class StreamDelta extends ConsultationStreamEvent {
  final String text;
  const StreamDelta(this.text);
}

class StreamDone extends ConsultationStreamEvent {
  final String fullText;
  const StreamDone(this.fullText);
}

/// 兜底：未识别的事件名（容错，方便调试）
class StreamUnknown extends ConsultationStreamEvent {
  final String event;
  final String data;
  const StreamUnknown(this.event, this.data);
}

// ── 4. 同步问诊响应（/messages，降级/调试用）─────────────

/// `POST /messages` → info 字段内容
class ConsultationTurn {
  final String userInput;
  final String consultation;

  const ConsultationTurn({
    required this.userInput,
    required this.consultation,
  });

  factory ConsultationTurn.fromJson(Map<String, dynamic> json) {
    return ConsultationTurn(
      userInput:    (json['user_input'] as String?) ?? '',
      consultation: (json['consultation'] as String?) ?? '',
    );
  }
}

// ── 5. 诊断报告 ───────────────────────────────────────────

/// `POST /report` → info 字段内容
class ConsultationReport {
  final String report;
  final String primaryDisease;
  final String symptomSummary;
  final String medicalSolutions;
  final List<DiseaseCard> diseaseCards;

  const ConsultationReport({
    required this.report,
    required this.primaryDisease,
    required this.symptomSummary,
    required this.medicalSolutions,
    required this.diseaseCards,
  });

  factory ConsultationReport.fromJson(Map<String, dynamic> json) {
    final cards = (json['disease_card'] as List?) ?? const [];
    return ConsultationReport(
      report:           (json['report'] as String?) ?? '',
      primaryDisease:   (json['primary_disease'] as String?) ?? '',
      symptomSummary:   (json['symptom_summary'] as String?) ?? '',
      medicalSolutions: (json['medical_solutions'] as String?) ?? '',
      diseaseCards: cards
          .whereType<Map>()
          .map((e) => DiseaseCard.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// 单个疾病卡片（v0.4：英文 key，probability 为 int 0-100，新增 riskLevel）
///
/// 兼容旧版中文 key（fromJson 同时尝试两套 key）
class DiseaseCard {
  /// 疾病名称（如 "猫上呼吸道感染"）
  final String name;

  /// 患病概率 0-100（整数，不带 %）
  final int probability;

  /// 风险等级：高 / 中 / 低（v0.4 新增）
  final String riskLevel;

  final String definition;
  final String cause;
  final String symptoms;
  final String diagnosis;
  final String treatment;

  const DiseaseCard({
    required this.name,
    required this.probability,
    required this.riskLevel,
    required this.definition,
    required this.cause,
    required this.symptoms,
    required this.diagnosis,
    required this.treatment,
  });

  factory DiseaseCard.fromJson(Map<String, dynamic> json) {
    // probability：v0.4 是 int（55），旧版是 String（"65%"）
    final probRaw = json['probability'];
    int probInt;
    if (probRaw is int) {
      probInt = probRaw;
    } else if (probRaw is double) {
      probInt = probRaw.round();
    } else if (probRaw is String) {
      final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(probRaw);
      probInt = m != null ? (double.tryParse(m.group(1)!) ?? 0).round() : 0;
    } else {
      // 旧版中文 key 回退
      final legacyStr = json['患病概率'] as String? ?? '';
      final m = RegExp(r'(\d+)').firstMatch(legacyStr);
      probInt = m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
    }

    return DiseaseCard(
      // 英文 key 优先，兼容旧版中文 key
      name:       (json['name'] as String?)      ?? (json['疾病名称'] as String?) ?? '',
      probability: probInt,
      riskLevel:  (json['risk_level'] as String?) ?? (json['疾病类型'] as String?) ?? '',
      definition: (json['definition'] as String?) ?? (json['定义'] as String?)    ?? '',
      cause:      (json['cause'] as String?)      ?? (json['病因'] as String?)     ?? '',
      symptoms:   (json['symptoms'] as String?)   ?? (json['临床表现'] as String?)  ?? '',
      diagnosis:  (json['diagnosis'] as String?)  ?? (json['诊断'] as String?)     ?? '',
      treatment:  (json['treatment'] as String?)  ?? (json['治疗方向'] as String?)  ?? '',
    );
  }

  /// 把 probability（0-100 int）转为 0.0-1.0，用于进度条
  double get probabilityRatio => (probability / 100).clamp(0.0, 1.0);
}

// ── 6. 历史记录模型 ───────────────────────────────────────

/// `/session/by-pet` 返回的 sessions[] 中的单条摘要
class ConsultationSessionSummary {
  final String sessionId;

  /// 会话名称（取自首条用户输入，旧数据可能为 null）
  final String? title;
  final String createdAt;
  final String updatedAt;

  const ConsultationSessionSummary({
    required this.sessionId,
    this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConsultationSessionSummary.fromJson(Map<String, dynamic> json) {
    return ConsultationSessionSummary(
      sessionId: (json['session_id'] as String?) ?? '',
      title:     json['title'] as String?,
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: (json['updated_at'] as String?) ?? '',
    );
  }

  /// 显示标题：有则显示，无则用日期
  String get displayTitle => title?.isNotEmpty == true ? title! : '问诊记录';

  /// 只取日期部分（"2026-05-25 14:30:00" → "2026-05-25"）
  String get dateOnly {
    if (createdAt.length >= 10) return createdAt.substring(0, 10);
    return createdAt;
  }
}

/// `/session/messages` → turns[] 中的单条对话
class HistoryTurn {
  final int turnIndex;
  final String userInput;
  final String consultation;
  final String createdAt;

  const HistoryTurn({
    required this.turnIndex,
    required this.userInput,
    required this.consultation,
    required this.createdAt,
  });

  factory HistoryTurn.fromJson(Map<String, dynamic> json) {
    return HistoryTurn(
      turnIndex:    (json['turn_index'] as int?) ?? 0,
      userInput:    (json['user_input'] as String?) ?? '',
      consultation: (json['consultation'] as String?) ?? '',
      createdAt:    (json['created_at'] as String?) ?? '',
    );
  }
}

/// `/session/messages` 返回的完整历史会话
class SessionHistory {
  final String sessionId;
  final String petId;
  final String? title;
  final String createdAt;
  final String updatedAt;
  final List<HistoryTurn> turns;

  const SessionHistory({
    required this.sessionId,
    required this.petId,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.turns,
  });

  factory SessionHistory.fromJson(Map<String, dynamic> json) {
    final turns = (json['turns'] as List?) ?? const [];
    return SessionHistory(
      sessionId: (json['session_id'] as String?) ?? '',
      petId:     (json['pet_id'] as String?) ?? '',
      title:     json['title'] as String?,
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: (json['updated_at'] as String?) ?? '',
      turns: turns
          .whereType<Map>()
          .map((e) => HistoryTurn.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

// ── 7. AI 输出标签解析工具 ────────────────────────────────

class AiOutputParser {
  AiOutputParser._();

  // 已知的结构化标签列表（顺序影响优先级）
  static const _knownTags = [
    '整体思考',
    'RelationRAG分析',
    '诊断',
    '追问',
  ];

  // ── 完整解析（流式结束后使用）────────────────────────────
  static List<TaggedSegment> parse(String input) {
    if (input.isEmpty) return const [];
    final segments = <TaggedSegment>[];
    final pattern = RegExp(r'<([^/>\s]+)>([\s\S]*?)</\1>', multiLine: true);

    int cursor = 0;
    for (final m in pattern.allMatches(input)) {
      if (m.start > cursor) {
        final plain = input.substring(cursor, m.start);
        if (plain.trim().isNotEmpty) {
          segments.add(TaggedSegment(tag: null, content: plain));
        }
      }
      segments.add(TaggedSegment(tag: m.group(1), content: m.group(2) ?? ''));
      cursor = m.end;
    }
    if (cursor < input.length) {
      final tail = input.substring(cursor);
      if (tail.trim().isNotEmpty) {
        segments.add(TaggedSegment(tag: null, content: tail));
      }
    }
    return segments;
  }

  // ── 流式解析（边流边渲染）────────────────────────────────
  //
  // 与 parse() 相比额外处理了「未闭合标签」：
  // 当 AI 正在输出 <整体思考>... 但 </整体思考> 还没到时，
  // parse() 会把 <整体思考>... 当成普通文本（裸露 XML 标签），
  // 而 parseStreaming() 会把开标签后的内容视为该标签的 content，
  // 从而在流式中也能正确渲染 ThinkingSection / MedicalAnalysis 等。
  static List<TaggedSegment> parseStreaming(String input) {
    if (input.isEmpty) return const [];

    // 先用完整解析拿到所有已闭合的段
    final base = parse(input);

    // 检查最后一个段是否是 plain-text（tag == null），
    // 且其内容里含有某个已知标签的开标签但没有对应闭标签
    // → 说明该标签的内容正在流式输出中，尚未闭合
    if (base.isNotEmpty && base.last.tag == null) {
      final lastPlain = base.last.content;
      for (final tag in _knownTags) {
        final openTag  = '<$tag>';
        final closeTag = '</$tag>';
        final oi = lastPlain.indexOf(openTag);
        if (oi >= 0 && !lastPlain.substring(oi).contains(closeTag)) {
          // 把 plain 段拆成 [before] + [incomplete tag content]
          final before     = lastPlain.substring(0, oi);
          final tagContent = lastPlain.substring(oi + openTag.length);
          final result     = base.sublist(0, base.length - 1);
          if (before.trim().isNotEmpty) {
            result.add(TaggedSegment(tag: null, content: before));
          }
          result.add(TaggedSegment(tag: tag, content: tagContent));
          return result;
        }
      }
    }

    return base;
  }

  static bool hasDiagnosis(String input) {
    return input.contains('<诊断>') && input.contains('</诊断>');
  }
}


class TaggedSegment {
  final String? tag;
  final String content;
  const TaggedSegment({required this.tag, required this.content});
}

/// SSE `data:` 字段的容错解析
String decodeSseData(String raw) {
  if (raw.isEmpty) return raw;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is String) return decoded;
    if (decoded is Map) {
      for (final k in const [
        'text',       // delta 事件
        'full_text',  // done 事件
        'user_input', // start 事件
        'data',
        'message',
        'content',
        'full',
      ]) {
        final v = decoded[k];
        if (v is String) return v;
      }
      return raw;
    }
    return raw;
  } catch (_) {
    return raw;
  }
}
