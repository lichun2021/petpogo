/// ════════════════════════════════════════════════════════════
///  认证数据模型
///
///  登录接口返回格式：
///  {
///    "code": 0,
///    "msg": "success",
///    "info": {
///      "token": "granwin_aws_admin_user_info_hash:...",
///      "account": "admin",
///      "name": "系统管理员",
///      "merchantId": 1
///    }
///  }
/// ════════════════════════════════════════════════════════════

class LoginResponse {
  final String token;
  final String account;
  final String name;
  final int merchantId;

  const LoginResponse({
    required this.token,
    required this.account,
    required this.name,
    required this.merchantId,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>;
    return LoginResponse(
      token:      (info['token']      as String?) ?? '',
      account:    (info['account']    as String?) ?? '',
      name:       (info['name']       as String?) ?? '',
      merchantId: (info['merchantId'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 用户信息（登录成功后持久化到本地）
class UserInfo {
  final String token;
  final String account;
  final String name;
  final int merchantId;

  const UserInfo({
    required this.token,
    required this.account,
    required this.name,
    required this.merchantId,
  });

  factory UserInfo.fromLoginResponse(LoginResponse res) => UserInfo(
    token:      res.token,
    account:    res.account,
    name:       res.name,
    merchantId: res.merchantId,
  );

  /// 序列化到 Map（用于 SecureStorage 持久化）
  Map<String, String> toStorageMap() => {
    'token':      token,
    'account':    account,
    'name':       name,
    'merchantId': merchantId.toString(),
  };

  /// 从 SecureStorage 读出后还原
  factory UserInfo.fromStorageMap(Map<String, String?> map) => UserInfo(
    token:      map['token']      ?? '',
    account:    map['account']    ?? '',
    name:       map['name']       ?? '',
    merchantId: int.tryParse(map['merchantId'] ?? '0') ?? 0,
  );
}
