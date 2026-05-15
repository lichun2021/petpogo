/// 围栏模型 — 对应 iPet POST /pet/fence/list 返回的单条围栏
class FenceModel {
  final String fenceId;
  final String fenceName;
  final String longitude;
  final String latitude;
  final String radius;
  final String address;
  final String street;
  final int    createTime;

  const FenceModel({
    this.fenceId    = '',
    this.fenceName  = '',
    this.longitude  = '',
    this.latitude   = '',
    this.radius     = '',
    this.address    = '',
    this.street     = '',
    this.createTime = 0,
  });

  String get displayRadius => '${radius}m';

  factory FenceModel.fromJson(Map<String, dynamic> json) => FenceModel(
    fenceId:    json['fenceId']?.toString()  ?? '',
    fenceName:  (json['fenceName']  as String?) ?? '',
    longitude:  (json['longitude']  as String?) ?? '',
    latitude:   (json['latitude']   as String?) ?? '',
    radius:     (json['radius']     as String?) ?? '',
    address:    (json['address']    as String?) ?? '',
    street:     (json['street']     as String?) ?? '',
    createTime: (json['createTime'] as int?)    ?? 0,
  );
}

/// 宠物位置模型 — 对应 iPet POST /pet/position
class PetPositionModel {
  final String latitude;
  final String longitude;
  final String address;
  final int    time;
  final int    reportTime;

  const PetPositionModel({
    this.latitude   = '',
    this.longitude  = '',
    this.address    = '',
    this.time       = 0,
    this.reportTime = 0,
  });

  bool get hasLocation => latitude.isNotEmpty && longitude.isNotEmpty;

  double get lat => double.tryParse(latitude) ?? 0;
  double get lng => double.tryParse(longitude) ?? 0;

  String get updateDisplay {
    if (reportTime == 0) return '未知';
    final dt = DateTime.fromMillisecondsSinceEpoch(reportTime);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours   < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  factory PetPositionModel.fromJson(Map<String, dynamic> json) => PetPositionModel(
    latitude:   (json['latitude']   as String?) ?? '',
    longitude:  (json['longitude']  as String?) ?? '',
    address:    (json['address']    as String?) ?? '',
    time:       (json['time']       as int?)    ?? 0,
    reportTime: (json['reportTime'] as int?)    ?? 0,
  );
}

/// 宠物信息模型 — 对应 iPet POST /pet/info/get
class PetInfoModel {
  final String petId;
  final String petName;
  final String breed;
  final int    age;
  final String weight;
  final String sex;      // GG/MM/GG_sterilization/MM_sterilization
  final String deviceId;
  final int    createTime;
  final String avatar;

  const PetInfoModel({
    this.petId      = '',
    this.petName    = '',
    this.breed      = '',
    this.age        = 0,
    this.weight     = '',
    this.sex        = '',
    this.deviceId   = '',
    this.createTime = 0,
    this.avatar     = '',
  });

  String get sexDisplay {
    switch (sex) {
      case 'GG':               return '公';
      case 'MM':               return '母';
      case 'GG_sterilization': return '公(绝育)';
      case 'MM_sterilization': return '母(绝育)';
      default:                 return sex;
    }
  }

  factory PetInfoModel.fromJson(Map<String, dynamic> json) => PetInfoModel(
    petId:      json['petId']?.toString()    ?? '',
    petName:    (json['petName']    as String?) ?? '',
    breed:      (json['breed']      as String?) ?? '',
    age:        (json['age']        as int?)    ?? 0,
    weight:     (json['weight']     as String?) ?? '',
    sex:        (json['sex']        as String?) ?? '',
    deviceId:   json['deviceId']?.toString()  ?? '',
    createTime: (json['createTime'] as int?)   ?? 0,
    avatar:     (json['avatar']     as String?) ?? '',
  );
}
