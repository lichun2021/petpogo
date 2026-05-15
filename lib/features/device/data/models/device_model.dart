/// 设备模型 — 对应 iPet POST /user/device/list 返回的单条设备
class DeviceModel {
  final String deviceId;
  final String mac;
  final String productKey;
  final String deviceNickname;   // 用户自定义昵称
  final bool   connect;          // true=在线
  final String uType;            // '1'=主人 '2'=共享
  final String sharer;
  final int    createTime;
  final int    updateTime;

  const DeviceModel({
    required this.deviceId,
    this.mac             = '',
    this.productKey      = '',
    this.deviceNickname  = '',
    this.connect         = false,
    this.uType           = '1',
    this.sharer          = '0',
    this.createTime      = 0,
    this.updateTime      = 0,
  });

  String get displayName =>
      deviceNickname.isNotEmpty ? deviceNickname : (mac.isNotEmpty ? mac : deviceId);

  bool get isOnline => connect;
  bool get isOwner  => uType == '1';

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
    deviceId:       (json['deviceId']       as String?) ?? '',
    mac:            (json['mac']            as String?) ?? '',
    productKey:     (json['productKey']     as String?) ?? '',
    deviceNickname: (json['deviceNickname'] as String?) ?? '',
    connect:        (json['connect']        as bool?)   ?? false,
    uType:          (json['uType']          as String?) ?? '1',
    sharer:         (json['sharer']         as String?) ?? '0',
    createTime:     (json['createTime']     as int?)    ?? 0,
    updateTime:     (json['updateTime']     as int?)    ?? 0,
  );

  @override
  String toString() => 'DeviceModel(id=$deviceId, name=$displayName, online=$connect)';
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
