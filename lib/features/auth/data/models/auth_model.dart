/// ════════════════════════════════════════════════════════════
///  认证数据模型
///
///  登录接口返回格式（期望）：
///  {
///    "code": 0,
///    "msg": "success",
///    "info": {
///      "token":      "granwin_aws_admin_user_info_hash:...",
///      "account":    "admin",
///      "name":       "系统管理员",
///      "merchantId": 1,
///      "imUserSig":  "xxxx"   ← 后端用腾讯 SecretKey 生成，供 IM SDK 登录
///    }
///  }
///
///  ⚠️ imUserSig 必须由后端生成，客户端不持有 SecretKey
/// ════════════════════════════════════════════════════════════

class LoginResponse {
  final String token;
  final String phone;
  final String nickname;
  final String id;
  final String avatar;
  final String imUserSig;
  final String imUserId;
  final bool   isVip;
  final String? vipExpireAt;
  final AiQuota aiQuota;
  final String peerGatewayUrl; // iPet 硬件网关公网地址

  const LoginResponse({
    required this.token,
    required this.phone,
    required this.nickname,
    required this.id,
    this.avatar = '',
    this.imUserSig = '',
    this.imUserId = '',
    this.isVip = false,
    this.vipExpireAt,
    this.aiQuota = const AiQuota(),
    this.peerGatewayUrl = '',
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    final im   = json['im']   as Map<String, dynamic>? ?? {};
    final peer = json['peer'] as Map<String, dynamic>? ?? {};
    final q    = user['aiQuota'] as Map<String, dynamic>? ?? {};
    return LoginResponse(
      token:          (json['token']          as String?) ?? '',
      phone:          (user['phone']          as String?) ?? '',
      nickname:       (user['nickname']       as String?) ?? '',
      id:             (user['id']             as String?) ?? '',
      avatar:         (user['avatar']         as String?) ?? '',
      imUserSig:      (im['userSig']          as String?) ?? '',
      imUserId:       (im['userId']           as String?) ?? '',
      isVip:          (user['isVip']          as bool?)   ?? false,
      vipExpireAt:    user['vipExpireAt']     as String?,
      aiQuota:        AiQuota.fromJson(q),
      peerGatewayUrl: (peer['gatewayUrl']     as String?) ?? '',
    );
  }
}

// ── AI 配额 ──────────────────────────────────────────────
class AiQuota {
  final int used;
  final int limit;      // -1 = VIP 无限
  final int remaining;  // -1 = VIP 无限

  const AiQuota({
    this.used      = 0,
    this.limit     = 10,
    this.remaining = 10,
  });

  bool get isUnlimited => limit == -1;

  factory AiQuota.fromJson(Map<String, dynamic> json) => AiQuota(
    used:      (json['used']      as int?) ?? 0,
    limit:     (json['limit']     as int?) ?? 10,
    remaining: (json['remaining'] as int?) ?? 10,
  );

  Map<String, String> toStorageMap() => {
    'aiQuota_used':      used.toString(),
    'aiQuota_limit':     limit.toString(),
    'aiQuota_remaining': remaining.toString(),
  };

  factory AiQuota.fromStorageMap(Map<String, String?> map) => AiQuota(
    used:      int.tryParse(map['aiQuota_used']      ?? '') ?? 0,
    limit:     int.tryParse(map['aiQuota_limit']     ?? '') ?? 10,
    remaining: int.tryParse(map['aiQuota_remaining'] ?? '') ?? 10,
  );
}

/// 用户信息（登录成功后持久化到本地）
class UserInfo {
  final String token;
  final String account;        // mapped to phone
  final String name;           // mapped to nickname
  final int    merchantId;     // mapped to id parsed as int
  final String id;             // string id
  final String avatar;
  final String imUserSig;
  final String? vipLevel;      // null/'free' = 非会员，'pro'/'pro_max' = 会员
  final String? vipExpireAt;
  final AiQuota aiQuota;
  final String peerGatewayUrl; // iPet 硬件网关地址
  // ── 积分（后端 /sdkapi/points/summary 提供，本地缓存最近一次）──
  final int points;            // 总可用余额 = permanent + gifted
  final int permanentPoints;   // 永久积分（不过期）
  final int giftedPoints;      // 赠送积分（有到期）

  const UserInfo({
    required this.token,
    required this.account,
    required this.name,
    required this.merchantId,
    required this.id,
    this.avatar = '',
    this.imUserSig = '',
    this.vipLevel,
    this.vipExpireAt,
    this.aiQuota = const AiQuota(),
    this.peerGatewayUrl = '',
    this.points = 0,
    this.permanentPoints = 0,
    this.giftedPoints = 0,
  });

  /// 是否为付费会员（vipLevel 为 pro / pro_max）
  bool get isVip => vipLevel == 'pro' || vipLevel == 'pro_max';

  factory UserInfo.fromLoginResponse(LoginResponse res) => UserInfo(
    token:          res.token,
    account:        res.phone,
    name:           res.nickname,
    merchantId:     int.tryParse(res.id) ?? 0,
    id:             res.id,
    avatar:         res.avatar,
    imUserSig:      res.imUserSig,
    // 兼容旧登录响应：isVip=true 视为 pro 会员
    vipLevel:       res.isVip ? 'pro' : null,
    vipExpireAt:    res.vipExpireAt,
    aiQuota:        res.aiQuota,
    peerGatewayUrl: res.peerGatewayUrl,
  );

  /// 序列化到 Map（用于 SecureStorage 持久化）
  Map<String, String> toStorageMap() => {
    'token':           token,
    'account':         account,
    'name':            name,
    'merchantId':      merchantId.toString(),
    'id':              id,
    'avatar':          avatar,
    'imUserSig':       imUserSig,
    'vipLevel':        vipLevel ?? '',
    'vipExpireAt':     vipExpireAt ?? '',
    'peerGatewayUrl':  peerGatewayUrl,
    'points':          points.toString(),
    'permanentPoints': permanentPoints.toString(),
    'giftedPoints':    giftedPoints.toString(),
    ...aiQuota.toStorageMap(),
  };

  /// 从 SecureStorage 读出后还原
  factory UserInfo.fromStorageMap(Map<String, String?> map) => UserInfo(
    token:          map['token']           ?? '',
    account:        map['account']         ?? '',
    name:           map['name']            ?? '',
    merchantId:     int.tryParse(map['merchantId'] ?? '0') ?? 0,
    id:             map['id']              ?? '',
    avatar:         map['avatar']          ?? '',
    imUserSig:      map['imUserSig']       ?? '',
    vipLevel:       (map['vipLevel']?.isNotEmpty ?? false) ? map['vipLevel'] : null,
    vipExpireAt:    (map['vipExpireAt']?.isNotEmpty ?? false) ? map['vipExpireAt'] : null,
    aiQuota:        AiQuota.fromStorageMap(map),
    peerGatewayUrl: map['peerGatewayUrl']  ?? '',
    points:          int.tryParse(map['points'] ?? '0') ?? 0,
    permanentPoints: int.tryParse(map['permanentPoints'] ?? '0') ?? 0,
    giftedPoints:    int.tryParse(map['giftedPoints'] ?? '0') ?? 0,
  );

  /// 从 profile 接口返回的 JSON 更新（不改 token / imUserSig）
  factory UserInfo.fromProfileJson(UserInfo current, Map<String, dynamic> json) {
    final qJson = json['aiQuota'] as Map<String, dynamic>? ?? {};
    // vipLevel：后端可能返回 vipLevel 字符串；兼容旧的 isVip bool
    final rawLevel = json['vipLevel'] as String?;
    final boolFromOld = json['isVip'] as bool? ?? current.isVip;
    return UserInfo(
      token:       current.token,
      account:     current.account,
      merchantId:  current.merchantId,
      id:          current.id,
      imUserSig:   current.imUserSig,
      name:        (json['nickname'] as String?) ?? current.name,
      avatar:      (json['avatar']   as String?) ?? current.avatar,
      vipLevel:    rawLevel ?? (boolFromOld ? 'pro' : current.vipLevel),
      vipExpireAt: json['vipExpireAt'] as String? ?? current.vipExpireAt,
      aiQuota:     qJson.isNotEmpty ? AiQuota.fromJson(qJson) : current.aiQuota,
      points:          (json['points'] as num?)?.toInt() ?? current.points,
      permanentPoints: (json['permanentPoints'] as num?)?.toInt() ?? current.permanentPoints,
      giftedPoints:    (json['giftedPoints'] as num?)?.toInt() ?? current.giftedPoints,
    );
  }

  /// 用于 IM 的 userID
  String get imUserId => id.isNotEmpty ? id : merchantId.toString();

  UserInfo copyWith({
    String?   name,
    String?   avatar,
    String?   token,
    String?   imUserSig,
    String?   vipLevel,
    String?   vipExpireAt,
    AiQuota?  aiQuota,
    String?   peerGatewayUrl,
    int?      points,
    int?      permanentPoints,
    int?      giftedPoints,
  }) => UserInfo(
    token:          token          ?? this.token,
    account:        account,
    name:           name           ?? this.name,
    merchantId:     merchantId,
    id:             id,
    avatar:         avatar         ?? this.avatar,
    imUserSig:      imUserSig      ?? this.imUserSig,
    vipLevel:       vipLevel       ?? this.vipLevel,
    vipExpireAt:    vipExpireAt    ?? this.vipExpireAt,
    aiQuota:        aiQuota        ?? this.aiQuota,
    peerGatewayUrl: peerGatewayUrl ?? this.peerGatewayUrl,
    points:          points          ?? this.points,
    permanentPoints: permanentPoints ?? this.permanentPoints,
    giftedPoints:    giftedPoints    ?? this.giftedPoints,
  );
}
