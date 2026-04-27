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
  final String account;
  final String name;
  final int    merchantId;
  /// 腾讯 IM UserSig — 后端用 SecretKey 生成，客户端直接用于 IM 登录
  /// 若后端暂未返回此字段则为空字符串，IM 登录将跳过
  final String imUserSig;

  const LoginResponse({
    required this.token,
    required this.account,
    required this.name,
    required this.merchantId,
    this.imUserSig = '',
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>;
    return LoginResponse(
      token:      (info['token']      as String?) ?? '',
      account:    (info['account']    as String?) ?? '',
      name:       (info['name']       as String?) ?? '',
      merchantId: (info['merchantId'] as num?)?.toInt() ?? 0,
      imUserSig:  (info['imUserSig']  as String?) ?? '', // 后端暂未返回时为空
    );
  }
}

/// 用户信息（登录成功后持久化到本地）
class UserInfo {
  final String token;
  final String account;
  final String name;
  final int    merchantId;
  /// 腾讯 IM UserSig（随登录响应获取，持久化用于 App 重启后恢复 IM 会话）
  final String imUserSig;

  const UserInfo({
    required this.token,
    required this.account,
    required this.name,
    required this.merchantId,
    this.imUserSig = '',
  });

  factory UserInfo.fromLoginResponse(LoginResponse res) => UserInfo(
    token:      res.token,
    account:    res.account,
    name:       res.name,
    merchantId: res.merchantId,
    imUserSig:  res.imUserSig,
  );

  /// 序列化到 Map（用于 SecureStorage 持久化）
  Map<String, String> toStorageMap() => {
    'token':      token,
    'account':    account,
    'name':       name,
    'merchantId': merchantId.toString(),
    'imUserSig':  imUserSig,
  };

  /// 从 SecureStorage 读出后还原
  factory UserInfo.fromStorageMap(Map<String, String?> map) => UserInfo(
    token:      map['token']      ?? '',
    account:    map['account']    ?? '',
    name:       map['name']       ?? '',
    merchantId: int.tryParse(map['merchantId'] ?? '0') ?? 0,
    imUserSig:  map['imUserSig']  ?? '',
  );

  /// 用于 IM 的 userID（使用 merchantId 转字符串，全平台唯一）
  String get imUserId => merchantId.toString();
}
