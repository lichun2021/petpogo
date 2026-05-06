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

  const LoginResponse({
    required this.token,
    required this.phone,
    required this.nickname,
    required this.id,
    this.avatar = '',
    this.imUserSig = '',
    this.imUserId = '',
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    final im = json['im'] as Map<String, dynamic>? ?? {};
    return LoginResponse(
      token:     (json['token'] as String?) ?? '',
      phone:     (user['phone'] as String?) ?? '',
      nickname:  (user['nickname'] as String?) ?? '',
      id:        (user['id'] as String?) ?? '',
      avatar:    (user['avatar'] as String?) ?? '',
      imUserSig: (im['userSig'] as String?) ?? '',
      imUserId:  (im['userId'] as String?) ?? '',
    );
  }
}

/// 用户信息（登录成功后持久化到本地）
class UserInfo {
  final String token;
  final String account; // mapped to phone
  final String name; // mapped to nickname
  final int    merchantId; // mapped to id parsed as int or just handle string
  final String id; // string id
  final String avatar;
  final String imUserSig;

  const UserInfo({
    required this.token,
    required this.account,
    required this.name,
    required this.merchantId,
    required this.id,
    this.avatar = '',
    this.imUserSig = '',
  });

  factory UserInfo.fromLoginResponse(LoginResponse res) => UserInfo(
    token:      res.token,
    account:    res.phone,
    name:       res.nickname,
    merchantId: int.tryParse(res.id) ?? 0,
    id:         res.id,
    avatar:     res.avatar,
    imUserSig:  res.imUserSig,
  );

  /// 序列化到 Map（用于 SecureStorage 持久化）
  Map<String, String> toStorageMap() => {
    'token':      token,
    'account':    account,
    'name':       name,
    'merchantId': merchantId.toString(),
    'id':         id,
    'avatar':     avatar,
    'imUserSig':  imUserSig,
  };

  /// 从 SecureStorage 读出后还原
  factory UserInfo.fromStorageMap(Map<String, String?> map) => UserInfo(
    token:      map['token']      ?? '',
    account:    map['account']    ?? '',
    name:       map['name']       ?? '',
    merchantId: int.tryParse(map['merchantId'] ?? '0') ?? 0,
    id:         map['id']         ?? '',
    avatar:     map['avatar']     ?? '',
    imUserSig:  map['imUserSig']  ?? '',
  );

  /// 用于 IM 的 userID
  String get imUserId => id.isNotEmpty ? id : merchantId.toString();

  UserInfo copyWith({
    String? name,
    String? avatar,
    String? token,
    String? imUserSig,
  }) => UserInfo(
    token:      token      ?? this.token,
    account:    account,
    name:       name       ?? this.name,
    merchantId: merchantId,
    id:         id,
    avatar:     avatar     ?? this.avatar,
    imUserSig:  imUserSig  ?? this.imUserSig,
  );
}
