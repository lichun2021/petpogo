import 'dart:convert';
import 'package:crypto/crypto.dart';

/// SDKAPI v2：查询参数按名称稳定排序，正文使用实际发送的字节。
String sdkSignatureV2({
  required String secret,
  required String method,
  required Uri uri,
  required String timestamp,
  required String nonce,
  required List<int> body,
}) {
  final pairs = <({String key, String value, int index})>[];
  for (final part in uri.query.split('&')) {
    if (part.isEmpty) continue;
    final equals = part.indexOf('=');
    pairs.add((
      key: Uri.decodeQueryComponent(
          equals < 0 ? part : part.substring(0, equals)),
      value: Uri.decodeQueryComponent(
          equals < 0 ? '' : part.substring(equals + 1)),
      index: pairs.length,
    ));
  }
  pairs.sort((a, b) {
    final order = a.key.compareTo(b.key);
    return order == 0 ? a.index.compareTo(b.index) : order;
  });
  final query = pairs
      .map((p) => '${_formEncode(p.key)}=${_formEncode(p.value)}')
      .join('&');
  final target = uri.toString();
  final path = (uri.hasAuthority ? target.substring(uri.origin.length) : target)
      .split(RegExp(r'[?#]'))
      .first;
  final message = [
    '2',
    'primary',
    method.toUpperCase(),
    path.isEmpty ? '/' : path,
    query,
    timestamp,
    nonce,
    sha256.convert(body).toString()
  ].join('\n');
  return Hmac(sha256, utf8.encode(secret))
      .convert(utf8.encode(message))
      .toString();
}

// WHATWG URLSearchParams：空格为 +，仅保留字母数字及 * - . _。
String _formEncode(String value) {
  final out = StringBuffer();
  for (final byte in utf8.encode(value)) {
    if ((byte >= 65 && byte <= 90) ||
        (byte >= 97 && byte <= 122) ||
        (byte >= 48 && byte <= 57) ||
        [42, 45, 46, 95].contains(byte)) {
      out.writeCharCode(byte);
    } else if (byte == 32) {
      out.write('+');
    } else {
      out.write('%${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}');
    }
  }
  return out.toString();
}
