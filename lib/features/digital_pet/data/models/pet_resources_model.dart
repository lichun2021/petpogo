/// ════════════════════════════════════════════════════════════
///  数字宠资源清单模型 — 对应 GET /sdkapi/pet/resources
///
///  一次性获取可用背景/形象/动作标识码/互动类型，供 App 渲染
///  背景选择器、形象选择器、互动按钮。
/// ════════════════════════════════════════════════════════════
library;

import 'pet_status_model.dart';

/// 动作标识码条目（对应模型内置动画片段名，不含文件本身）
class PetGlbAction {
  final String id;
  final String code;
  final String name;

  const PetGlbAction({
    required this.id,
    required this.code,
    required this.name,
  });

  factory PetGlbAction.fromJson(Map<String, dynamic> json) => PetGlbAction(
        id: json['id']?.toString() ?? '',
        code: (json['code'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
      );
}

/// 互动类型（喂食/逗猫/清洁等，后台可增删）
class InteractionType {
  final String id;
  final String code;
  final String name;
  final String iconUrl;
  final int satietyDelta;
  final int moodDelta;
  final int cleanlinessDelta;

  /// 该互动当前映射的动作标识码；未配置映射时为 null
  final String? clipCode;

  const InteractionType({
    required this.id,
    required this.code,
    required this.name,
    this.iconUrl = '',
    this.satietyDelta = 0,
    this.moodDelta = 0,
    this.cleanlinessDelta = 0,
    this.clipCode,
  });

  factory InteractionType.fromJson(Map<String, dynamic> json) =>
      InteractionType(
        id: json['id']?.toString() ?? '',
        code: (json['code'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        iconUrl: (json['icon_url'] as String?) ?? '',
        satietyDelta: (json['satiety_delta'] as num?)?.toInt() ?? 0,
        moodDelta: (json['mood_delta'] as num?)?.toInt() ?? 0,
        cleanlinessDelta: (json['cleanliness_delta'] as num?)?.toInt() ?? 0,
        clipCode: json['clipCode'] as String?,
      );
}

class PetResourcesModel {
  final List<PetBackgroundResource> backgrounds;
  final List<PetModelResource> models;
  final List<PetGlbAction> glbActions;
  final List<InteractionType> interactionTypes;

  const PetResourcesModel({
    this.backgrounds = const [],
    this.models = const [],
    this.glbActions = const [],
    this.interactionTypes = const [],
  });

  factory PetResourcesModel.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    }

    return PetResourcesModel(
      backgrounds:
          parseList(json['backgrounds'], PetBackgroundResource.fromJson),
      models: parseList(json['models'], PetModelResource.fromJson),
      glbActions: parseList(json['glbActions'], PetGlbAction.fromJson),
      interactionTypes:
          parseList(json['interactionTypes'], InteractionType.fromJson),
    );
  }
}

/// 执行互动后的返回值 — 对应 POST /sdkapi/pet/:id/interact
class InteractResult {
  final int satiety;
  final int mood;
  final int cleanliness;

  /// 该互动类型当前映射的动作标识码；未配置映射时为 null
  final String? clipCode;

  const InteractResult({
    required this.satiety,
    required this.mood,
    required this.cleanliness,
    this.clipCode,
  });

  factory InteractResult.fromJson(Map<String, dynamic> json) =>
      InteractResult(
        satiety: (json['satiety'] as num?)?.toInt() ?? 0,
        mood: (json['mood'] as num?)?.toInt() ?? 0,
        cleanliness: (json['cleanliness'] as num?)?.toInt() ?? 0,
        clipCode: json['clipCode'] as String?,
      );
}

/// 硬件动作轮询结果 — 对应 GET /sdkapi/pet/:id/action
class PetActionModel {
  /// 硬件最近上报的状态码；从未上报或宠物未关联设备时为 null
  final String? code;

  /// 上报时间（ISO8601 字符串）；无上报记录时为 null
  final String? reportedAt;

  /// 该状态码当前映射的动作标识码；未配置映射时为 null
  final String? clipCode;

  const PetActionModel({this.code, this.reportedAt, this.clipCode});

  factory PetActionModel.fromJson(Map<String, dynamic> json) =>
      PetActionModel(
        code: json['code'] as String?,
        reportedAt: json['reportedAt'] as String?,
        clipCode: json['clipCode'] as String?,
      );
}
