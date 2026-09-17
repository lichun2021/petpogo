/// ════════════════════════════════════════════════════════════
///  数字宠状态模型 — 对应 GET /sdkapi/pet/:id/status
///
///  一次调用返回宠物基本信息 + 养成属性 + 当前配置的背景/形象，
///  供数字宠首页一次性渲染，不需要再拼 detail + resources。
/// ════════════════════════════════════════════════════════════
library;

/// 背景资源（既出现在 status 里，也出现在 resources 列表里）
class PetBackgroundResource {
  final String id;
  final String name;
  final String imageUrl;

  const PetBackgroundResource({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  factory PetBackgroundResource.fromJson(Map<String, dynamic> json) =>
      PetBackgroundResource(
        id: json['id']?.toString() ?? '',
        name: (json['name'] as String?) ?? '',
        imageUrl: (json['image_url'] as String?) ?? '',
      );
}

/// 形象（GLB 模型）资源（既出现在 status 里，也出现在 resources 列表里）
class PetModelResource {
  final String id;
  final String name;
  final String glbUrl;
  final String thumbnailUrl;

  const PetModelResource({
    required this.id,
    required this.name,
    required this.glbUrl,
    required this.thumbnailUrl,
  });

  factory PetModelResource.fromJson(Map<String, dynamic> json) =>
      PetModelResource(
        id: json['id']?.toString() ?? '',
        name: (json['name'] as String?) ?? '',
        glbUrl: (json['glb_url'] as String?) ?? '',
        thumbnailUrl: (json['thumbnail_url'] as String?) ?? '',
      );
}

class PetStatusModel {
  final String id;
  final String name;
  final String? avatar;
  final String? species;
  final String? breed;
  final int gender;
  final String? birthday;
  final double? weight;
  final String? bio;
  final int satiety;
  final int mood;
  final int cleanliness;

  /// 未配置背景时为 null（也覆盖"曾配置但资源已停用/删除"的情况）
  final PetBackgroundResource? background;

  /// 未配置形象时为 null
  final PetModelResource? model;

  const PetStatusModel({
    required this.id,
    required this.name,
    this.avatar,
    this.species,
    this.breed,
    this.gender = 0,
    this.birthday,
    this.weight,
    this.bio,
    required this.satiety,
    required this.mood,
    required this.cleanliness,
    this.background,
    this.model,
  });

  factory PetStatusModel.fromJson(Map<String, dynamic> json) {
    final backgroundJson = json['background'];
    final modelJson = json['model'];
    return PetStatusModel(
      id: json['id']?.toString() ?? '',
      name: (json['name'] as String?) ?? '',
      avatar: json['avatar'] as String?,
      species: json['species'] as String?,
      breed: json['breed'] as String?,
      gender: (json['gender'] as num?)?.toInt() ?? 0,
      birthday: json['birthday'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      bio: json['bio'] as String?,
      satiety: (json['satiety'] as num?)?.toInt() ?? 0,
      mood: (json['mood'] as num?)?.toInt() ?? 0,
      cleanliness: (json['cleanliness'] as num?)?.toInt() ?? 0,
      background: backgroundJson is Map<String, dynamic>
          ? PetBackgroundResource.fromJson(backgroundJson)
          : null,
      model: modelJson is Map<String, dynamic>
          ? PetModelResource.fromJson(modelJson)
          : null,
    );
  }

  /// 用互动/资源选择的局部返回值就地更新状态，不必重新拉取整份 status。
  ///
  /// [clearBackground]/[clearModel] 用于显式清空（目前接口不会返回这种
  /// 需求，保留是为了未来若后端支持"取消选择"时不必再改这个方法签名）。
  PetStatusModel copyWith({
    int? satiety,
    int? mood,
    int? cleanliness,
    PetBackgroundResource? background,
    PetModelResource? model,
    bool clearBackground = false,
    bool clearModel = false,
  }) =>
      PetStatusModel(
        id: id,
        name: name,
        avatar: avatar,
        species: species,
        breed: breed,
        gender: gender,
        birthday: birthday,
        weight: weight,
        bio: bio,
        satiety: satiety ?? this.satiety,
        mood: mood ?? this.mood,
        cleanliness: cleanliness ?? this.cleanliness,
        background: clearBackground ? null : (background ?? this.background),
        model: clearModel ? null : (model ?? this.model),
      );
}
