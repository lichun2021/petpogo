// 宠物分享相关数据模型

/// 宠物分享记录
class PetShareModel {
  final int petShareId;
  final String petName;
  final String? toUserEmail;
  final String state; // pending / accept / refuse
  final String para; // 分享口令
  final DateTime? createTime;
  final DateTime? disableTime;

  const PetShareModel({
    required this.petShareId,
    required this.petName,
    this.toUserEmail,
    required this.state,
    required this.para,
    this.createTime,
    this.disableTime,
  });

  factory PetShareModel.fromJson(Map<String, dynamic> json) {
    return PetShareModel(
      petShareId: _asInt(json['petShareId']),
      petName: json['petName']?.toString() ?? '',
      toUserEmail: json['toUserEmail']?.toString(),
      state: json['state']?.toString() ?? 'pending',
      para: json['para']?.toString() ?? '',
      createTime: _parseDateTime(json['createTime']),
      disableTime: _parseDateTime(json['disableTime']),
    );
  }

  bool get isPending => state == 'pending';
  bool get isAccepted => state == 'accept';
  bool get isRefused => state == 'refuse';

  String get stateLabel {
    switch (state) {
      case 'pending':
        return '待接受';
      case 'accept':
        return '已接受';
      case 'refuse':
        return '已拒绝';
      default:
        return state;
    }
  }
}

/// 宠物成员模型（接受分享后的成员）
class PetMemberModel {
  final String userId;
  final String userName;
  final String? userEmail;
  final String type; // 1=owner, 2=管理员, 3=成员
  final DateTime? joinTime;

  const PetMemberModel({
    required this.userId,
    required this.userName,
    this.userEmail,
    required this.type,
    this.joinTime,
  });

  factory PetMemberModel.fromJson(Map<String, dynamic> json) {
    return PetMemberModel(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? json['name']?.toString() ?? '',
      userEmail: json['userEmail']?.toString() ?? json['account']?.toString(),
      type: json['type']?.toString() ?? json['permission']?.toString() ?? '3',
      joinTime: _parseDateTime(json['joinTime']),
    );
  }

  bool get isOwner => type == '1';
  bool get isAdmin => type == '2';
  bool get isMember => type == '3';

  String get roleLabel {
    switch (type) {
      case '1':
        return '主人';
      case '2':
        return '管理员';
      case '3':
        return '成员';
      default:
        return '成员';
    }
  }

  String get displayName => userName.isNotEmpty ? userName : '用户';

  String get displayAccount {
    if (userEmail != null && userEmail!.isNotEmpty) {
      return userEmail!;
    }
    return userId.isNotEmpty ? 'ID: $userId' : '未知账号';
  }
}

/// 分页信息
class PetSharePageTurn {
  final int totalCount;
  final int pageNo;
  final int totalPage;

  const PetSharePageTurn({
    required this.totalCount,
    required this.pageNo,
    required this.totalPage,
  });

  factory PetSharePageTurn.fromJson(Map<String, dynamic> json) {
    return PetSharePageTurn(
      totalCount: _asInt(json['totalCount']),
      pageNo: _asInt(json['pageNo']),
      totalPage: _asInt(json['totalPage']),
    );
  }
}

// 辅助函数
int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final str = value.toString();
  if (str.isEmpty) return null;
  return DateTime.tryParse(str);
}
