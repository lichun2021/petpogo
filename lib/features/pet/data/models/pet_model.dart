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
    this.vaccinated = false,
    this.linkedDeviceId = '',
  });

  // ── JSON 序列化 ───────────────────────────────────────

  /// 从服务端响应 JSON 创建 PetModel
  factory PetModel.fromJson(Map<String, dynamic> json) => PetModel(
    id:             json['id'] as String? ?? '',
    name:           json['name'] as String? ?? '',
    type:           json['type'] as String? ?? 'other',
    breed:          json['breed'] as String? ?? '',
    birthday:       json['birthday'] as String? ?? '',
    gender:         json['gender'] as String? ?? 'unknown',
    emoji:          json['emoji'] as String? ?? '🐾',
    vaccinated:     json['vaccinated'] as bool? ?? false,
    linkedDeviceId: json['linkedDeviceId'] as String? ?? '',
  );

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
