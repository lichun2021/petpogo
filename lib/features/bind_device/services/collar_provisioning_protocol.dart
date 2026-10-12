import 'dart:convert';

class CollarProvisioningException implements Exception {
  final String message;
  const CollarProvisioningException(this.message);
  @override
  String toString() => message;
}

class CollarSaveUnconfirmedException extends CollarProvisioningException {
  const CollarSaveUnconfirmedException() : super('保存时蓝牙断开，尚未收到确认，将查询账号绑定结果');
}

/// The firmware accepts single, acknowledged ATT writes only.
abstract interface class CollarProvisioningTransport {
  Future<int> negotiatedMtu(int minimum);
  Future<void> write(String uuid, List<int> value);
}

abstract final class CollarProvisioningProtocol {
  static const deviceName = 'PetCollar07-PROV';
  static const service = '6e5d0001-c3a7-4f11-9b2e-1a2b3c4d5e6f';
  static const ssid = '6e5d0002-c3a7-4f11-9b2e-1a2b3c4d5e6f';
  static const password = '6e5d0003-c3a7-4f11-9b2e-1a2b3c4d5e6f';
  static const bindToken = '6e5d0005-c3a7-4f11-9b2e-1a2b3c4d5e6f';
  static const control = '6e5d0004-c3a7-4f11-9b2e-1a2b3c4d5e6f';

  static String? validateSsid(String value) {
    final length = utf8.encode(value).length;
    return length == 0 || length > 32 ? 'WiFi 名称需为 1–32 字节，中文通常占 3 字节' : null;
  }

  static String? validatePassword(String value) =>
      utf8.encode(value).length > 63 ? 'WiFi 密码不能超过 63 字节' : null;

  static Future<void> send(
    CollarProvisioningTransport transport,
    String networkName,
    String networkPassword, {
    Future<String> Function()? acquireBindToken,
  }) async {
    final error =
        validateSsid(networkName) ?? validatePassword(networkPassword);
    if (error != null) throw CollarProvisioningException(error);
    final ssidBytes = utf8.encode(networkName);
    final passwordBytes = utf8.encode(networkPassword);
    final longest = [
      ssidBytes.length,
      passwordBytes.length,
    ].reduce((a, b) => a > b ? a : b);
    final minimumMtu = longest + 3;
    if (await transport.negotiatedMtu(minimumMtu) < minimumMtu) {
      throw const CollarProvisioningException('蓝牙连接的数据容量不足，请重新连接或更换手机');
    }
    await transport.write(ssid, ssidBytes);
    await transport.write(password, passwordBytes);
    if (acquireBindToken != null) {
      // Fetch just before writing; never cache a short-lived, one-use token.
      final token = await acquireBindToken();
      if (!RegExp(r'^[A-Za-z0-9]{1,64}$').hasMatch(token)) {
        throw const CollarProvisioningException('绑定凭证格式无效，请重新获取后配网');
      }
      final tokenBytes = utf8.encode(token);
      if (await transport.negotiatedMtu(tokenBytes.length + 3) <
          tokenBytes.length + 3) {
        throw const CollarProvisioningException('蓝牙连接无法完整发送绑定凭证，请重新连接或更换手机');
      }
      await transport.write(bindToken, tokenBytes);
    }
    // Only a successful response confirms acceptance. A disconnect alone can
    // also mean power loss, so never turn an unacknowledged write into success.
    await transport.write(control, [0x01]);
  }
}
