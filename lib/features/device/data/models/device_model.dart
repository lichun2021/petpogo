/// 设备模型 — 对应 iPet POST /user/device/list 返回的单条设备
///
/// uType 取值：
///   1 = OWNER  — 主人（首绑者，可分享）
///   2 = ADMIN  — 管理员（有分享权限）
///   3 = MEMBER — 普通成员（被分享者，不可再分享）
/// sharer：
///   '0'  → 自有设备
///   其他 → 分享者的 userId
class DeviceModel {
  final String deviceId;
  final String mac;
  final String productKey;
  final String name;             // 设备名（用户改过的）
  final String deviceNickname;   // 用户自定义昵称（旧字段，兼容）
  final bool   connect;          // true=在线
  final String uType;            // '1'=OWNER '2'=ADMIN '3'=MEMBER
  final String sharer;           // '0'=自有  其他=分享者 userId
  final int    createTime;
  final int    updateTime;

  const DeviceModel({
    required this.deviceId,
    this.mac             = '',
    this.productKey      = '',
    this.name            = '',
    this.deviceNickname  = '',
    this.connect         = false,
    this.uType           = '1',
    this.sharer          = '0',
    this.createTime      = 0,
    this.updateTime      = 0,
  });

  /// 优先 name → deviceNickname → mac → deviceId
  String get displayName {
    if (name.isNotEmpty)           return name;
    if (deviceNickname.isNotEmpty) return deviceNickname;
    if (mac.isNotEmpty)            return mac;
    return deviceId;
  }

  bool get isOnline  => connect;
  bool get isOwner   => uType == '1';                            // OWNER
  bool get isAdmin   => uType == '2';                            // ADMIN
  bool get isMember  => uType == '3';                            // MEMBER
  bool get isShared  => sharer != '0' && sharer.isNotEmpty;     // 别人分享给我的
  bool get canShare  => uType == '1';                            // 只有主人可分享

  /// 用于 UI 显示的角色标签
  String get roleLabel {
    if (!isShared) return '我的';     // sharer == '0' 自有设备
    switch (uType) {
      case '2': return '管理员';
      case '3': return '共享设备';
      default:  return '共享设备';
    }
  }

  /// 解析 uType：后端可能返回 int 或 String
  static String _parseUType(dynamic v) {
    if (v == null) return '1';
    return v.toString();
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
    deviceId:       (json['deviceId']       as String?) ?? '',
    mac:            (json['mac']            as String?) ?? '',
    productKey:     (json['productKey']     as String?) ?? '',
    name:           (json['name']           as String?) ?? '',
    deviceNickname: (json['deviceNickname'] as String?) ?? '',
    connect:        (json['connect']        as bool?)   ?? false,
    uType:          _parseUType(json['uType']),
    sharer:         (json['sharer']         as String?) ?? '0',
    createTime:     (json['createTime']     as int?)    ?? 0,
    updateTime:     (json['updateTime']     as int?)    ?? 0,
  );

  @override
  String toString() => 'DeviceModel(id=$deviceId, name=$displayName, online=$connect, role=$roleLabel)';
}

// ── 设备详情模型 ─────────────────────────────────────────
class DeviceDetailModel {
  final int    id;
  final String name;
  final String mac;
  final int    productId;
  final String productKey;
  final String productName;
  final bool   onlineStatus;
  final String deviceNickName;
  final int    merchantId;
  final String merchantName;
  final int    lastOnlineTime;
  final int    status;

  const DeviceDetailModel({
    this.id             = 0,
    this.name           = '',
    this.mac            = '',
    this.productId      = 0,
    this.productKey     = '',
    this.productName    = '',
    this.onlineStatus   = false,
    this.deviceNickName = '',
    this.merchantId     = 0,
    this.merchantName   = '',
    this.lastOnlineTime = 0,
    this.status         = 0,
  });

  String get displayName => deviceNickName.isNotEmpty ? deviceNickName : name;

  String get lastOnlineDisplay {
    if (lastOnlineTime == 0) return '未知';
    final dt = DateTime.fromMillisecondsSinceEpoch(lastOnlineTime);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours   < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  factory DeviceDetailModel.fromJson(Map<String, dynamic> json) => DeviceDetailModel(
    id:             (json['id']             as int?)    ?? 0,
    name:           (json['name']           as String?) ?? '',
    mac:            (json['mac']            as String?) ?? '',
    productId:      (json['productId']      as int?)    ?? 0,
    productKey:     (json['productKey']     as String?) ?? '',
    productName:    (json['productName']    as String?) ?? '',
    onlineStatus:   (json['onlineStatus']   as bool?)   ?? false,
    deviceNickName: (json['deviceNickName'] as String?) ?? '',
    merchantId:     (json['merchantId']     as int?)    ?? 0,
    merchantName:   (json['merchantName']   as String?) ?? '',
    lastOnlineTime: (json['lastOnlineTime'] as int?)    ?? 0,
    status:         (json['status']         as int?)    ?? 0,
  );
}

// ── OTA 信息模型 ─────────────────────────────────────────
class OtaInfoModel {
  final bool   isUpgrade;
  final String currentVersion;
  final String msg;
  final String msgCode;

  const OtaInfoModel({
    this.isUpgrade      = false,
    this.currentVersion = '',
    this.msg            = '',
    this.msgCode        = '',
  });

  factory OtaInfoModel.fromJson(Map<String, dynamic> json) => OtaInfoModel(
    isUpgrade:      (json['isUpgrade']      as bool?)   ?? false,
    currentVersion: (json['currentVersion'] as String?) ?? '',
    msg:            (json['msg']            as String?) ?? '',
    msgCode:        (json['msgCode']        as String?) ?? '',
  );
}

// ── 设备共享成员模型 ──────────────────────────────────────
/// 对应 POST /user/device/member/query 返回列表中的单条成员
///
/// type 取值与 uType 一致：
///   '1' = OWNER（主人，通常不出现在此列表）
///   '2' = ADMIN（管理员）
///   '3' = MEMBER（普通成员/被分享者）
class DeviceMemberModel {
  final String userId;   // 成员 userId（用于 removeMember）
  final String account;  // 邮箱/手机号
  final String username; // 昵称
  final String mac;
  final String type;     // '1'=OWNER '2'=ADMIN '3'=MEMBER
  final int    createTime;

  const DeviceMemberModel({
    required this.userId,
    this.account    = '',
    this.username   = '',
    this.mac        = '',
    this.type       = '3',
    this.createTime = 0,
  });

  /// 显示名：优先 username，否则 account
  String get displayName => username.isNotEmpty ? username : account;

  String get roleLabel {
    switch (type) {
      case '1': return '主人';
      case '2': return '管理员';
      default:  return '成员';
    }
  }

  /// userId 后端有时返回 int，兼容两种格式
  static String _str(dynamic v) => v?.toString() ?? '';

  factory DeviceMemberModel.fromJson(Map<String, dynamic> json) =>
      DeviceMemberModel(
        userId:     _str(json['userId']),
        account:    (json['account']    as String?) ?? '',
        username:   (json['username']   as String?) ?? '',
        mac:        (json['mac']        as String?) ?? '',
        type:       _str(json['type']).isEmpty ? '3' : _str(json['type']),
        createTime: (json['createTime'] as int?)    ?? 0,
      );
}
