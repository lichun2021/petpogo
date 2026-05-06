/// ════════════════════════════════════════════════════════════
///  宠物数据模型 — PetModel
///
///  使用普通 Dart 类（immutable + copyWith）
///  注意：Freezed 需要 build_runner 代码生成，
///        接入真实 API 时可以改为 @freezed，
///        现阶段先用手写 copyWith 保持可编译。
/// ════════════════════════════════════════════════════════════
class PetModel {
  /// 宠物唯一 ID（由服务端生成，本地新建时传空字符串）
  final String id;

  /// 宠物名字（用户填写）
  final String name;

  /// 宠物类型：'cat' | 'dog' | 'rabbit' | 'hamster' | 'bird' | 'fish' | 'reptile' | 'other'
  final String type;

  /// 品种（选填）
  final String breed;

  /// 生日，格式 'YYYY-MM-DD'（选填）
  final String birthday;

  /// 性别：'male' | 'female' | 'unknown'
  final String gender;

  /// 显示用 Emoji（根据 type 自动设置）
  final String emoji;

  /// 是否已接种疫苗
  final bool vaccinated;

  /// 头像 URL
  final String avatar;

  /// 体重 (kg)
  final double weight;

  /// 简介
  final String bio;

  /// 关联的设备 ID（KeyTracker / PetPhone）
  final String linkedDeviceId;

  const PetModel({
    required this.id,
    required this.name,
    required this.type,
    this.breed = '',
    this.birthday = '',
    this.gender = 'unknown',
    this.emoji = '🐾',
    this.avatar = '',
    this.weight = 0,
    this.bio = '',
    this.vaccinated = false,
    this.linkedDeviceId = '',
  });

  // ── JSON 序列化 ───────────────────────────────────────

  /// 从服务端响应 JSON 创建 PetModel
  factory PetModel.fromJson(Map<String, dynamic> json) {
    // 后端返回的是 species 字段（字符串）
    final species = (json['species'] as String?)?.toLowerCase() ?? 'other';
    // id / device_id 后端返回 int（大雪花 ID），需转 String
    final id       = json['id']?.toString() ?? '';
    final deviceId = json['device_id']?.toString() ?? '';
    // birthday 可能带 T00:00:00.000Z，只取日期部分
    final rawBirthday = json['birthday']?.toString() ?? '';
    final birthday = rawBirthday.length >= 10 ? rawBirthday.substring(0, 10) : rawBirthday;
    // gender 后端存 int：1=公 2=母 0=未知
    final genderInt = json['gender'] as int? ?? 0;
    final gender = genderInt == 1 ? 'male' : genderInt == 2 ? 'female' : 'unknown';

    return PetModel(
      id:             id,
      name:           (json['name'] as String?) ?? '',
      type:           species,
      breed:          (json['breed'] as String?) ?? '',
      birthday:       birthday,
      gender:         gender,
      emoji:          _emojiForSpecies(species),
      avatar:         (json['avatar'] as String?) ?? '',
      weight:         (json['weight'] as num?)?.toDouble() ?? 0,
      bio:            (json['bio'] as String?) ?? '',
      linkedDeviceId: deviceId,
    );
  }

  static String _emojiForSpecies(String s) {
    switch (s) {
      case 'cat':     return '🐱';
      case 'dog':     return '🐶';
      case 'rabbit':  return '🐰';
      case 'hamster': return '🐹';
      case 'bird':    return '🐦';
      case 'fish':    return '🐟';
      default:        return '🐾';
    }
  }

  /// 转为 JSON，用于 POST/PUT 请求体
  Map<String, dynamic> toJson() => {
    'id':             id,
    'name':           name,
    'type':           type,
    'breed':          breed,
    'birthday':       birthday,
    'gender':         gender,
    'emoji':          emoji,
    'vaccinated':     vaccinated,
    'linkedDeviceId': linkedDeviceId,
  };

  /// 不可变更新：生成新的 PetModel（只改需要改的字段）
  PetModel copyWith({
    String? id,
    String? name,
    String? type,
    String? breed,
    String? birthday,
    String? gender,
    String? emoji,
    bool? vaccinated,
    String? linkedDeviceId,
  }) =>
      PetModel(
        id:             id ?? this.id,
        name:           name ?? this.name,
        type:           type ?? this.type,
        breed:          breed ?? this.breed,
        birthday:       birthday ?? this.birthday,
        gender:         gender ?? this.gender,
        emoji:          emoji ?? this.emoji,
        vaccinated:     vaccinated ?? this.vaccinated,
        linkedDeviceId: linkedDeviceId ?? this.linkedDeviceId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PetModel(id: $id, name: $name, type: $type)';
}
