/// ════════════════════════════════════════════════════════════
///  [仅开发测试] 本地 UserSig 生成工具
///
///  ⚠️ 警告：
///    - 此文件仅用于开发/联调阶段
///    - SecretKey 不得出现在生产包中
///    - 生产环境必须由后端服务器生成 UserSig 并下发给客户端
///    - 上线前应将 AppConfig.timSecretKey 清空
///
///  算法：TLS 2.0 (HMAC-SHA256 + ZLib + Base64)
/// ════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';

abstract class DebugUserSig {
  /// [仅 Debug] 用本地 SecretKey 生成 UserSig（有效期 180 天）
  ///
  /// - Release 构建返回 null（不暴露 SecretKey）
  /// - timSecretKey 为空时返回 null
  static String? generate(String userId) {
    if (kReleaseMode) {
      debugPrint('[DebugUserSig] ⛔ Release 模式，禁止本地生成 UserSig');
      return null;
    }
    if (AppConfig.timSecretKey.isEmpty) {
      debugPrint('[DebugUserSig] ⚠️ timSecretKey 为空');
      return null;
    }

    try {
      const expireSeconds = 180 * 24 * 60 * 60; // 180 天
      final currTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final sdkAppId = AppConfig.timSdkAppId;
      final key = AppConfig.timSecretKey;

      // 1. HMAC-SHA256 签名
      final content =
          'TLS.identifier:$userId\nTLS.sdkappid:$sdkAppId\nTLS.time:$currTime\nTLS.expire:$expireSeconds\n';
      final hmac = Hmac(sha256, utf8.encode(key));
      final sig = base64.encode(hmac.convert(utf8.encode(content)).bytes);

      // 2. 拼装 JSON
      final sigDoc = {
        'TLS.ver': '2.0',
        'TLS.identifier': userId,
        'TLS.sdkappid': sdkAppId,
        'TLS.expire': expireSeconds,
        'TLS.time': currTime,
        'TLS.sig': sig,
      };

      // 3. ZLib 压缩 → Base64 → 转义
      final compressed = const ZLibEncoder().encode(utf8.encode(json.encode(sigDoc)));
      final userSig = base64
          .encode(compressed)
          .replaceAll('+', '*')
          .replaceAll('/', '-')
          .replaceAll('=', '_');

      debugPrint('[DebugUserSig] ✅ UserSig 生成成功 (userId=$userId)');
      return userSig;
    } catch (e) {
      debugPrint('[DebugUserSig] ❌ UserSig 生成失败: $e');
      return null;
    }
  }
}
