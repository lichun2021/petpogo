/// ═══════════════════════════════════════════════════════
///  PeerApiClient — iPet 硬件网关专用 HTTP 客户端
///
///  与 ApiClient 的区别：
///    ✅ baseUrl = peerGatewayUrl（登录时下发，iPet 公网地址）
///    ✅ header  = token: <token>（不是 Authorization: Bearer）
///    ✅ body    = application/x-www-form-urlencoded
///    ✅ 只有 POST（iPet 后台所有接口都是 POST）
///    ✅ 响应格式 = { code, info, tip }（iPet 统一格式）
/// ═══════════════════════════════════════════════════════

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../../features/auth/controller/auth_controller.dart';

// ── iPet 统一响应格式 ────────────────────────────────────
class PeerResponse<T> {
  final int code;
  final String tip;
  final T? info;
  final List<dynamic>? list;

  PeerResponse({required this.code, required this.tip, this.info, this.list});

  factory PeerResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromInfo,
  ) {
    return PeerResponse<T>(
      code: json['code'] is num
          ? (json['code'] as num).toInt()
          : int.tryParse(json['code']?.toString() ?? '') ?? -1,
      tip: json['tip']?.toString() ?? '',
      info: fromInfo != null && json['info'] != null
          ? fromInfo(json['info'])
          : null,
      list: json['list'] as List<dynamic>?,
    );
  }

  bool get isSuccess => code == 0;
}

// ── PeerApiClient ────────────────────────────────────────
class PeerApiClient {
  late Dio _dio;
  String _token = '';
  String _baseUrl = '';

  PeerApiClient();

  void init({required String baseUrl, required String token}) {
    _baseUrl = baseUrl;
    _token = token;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'token': token,
      },
    ));
    if (AppConfig.isDebug) {
      _dio.interceptors.add(_PeerLogInterceptor());
    }
  }

  void updateToken(String token) {
    _token = token;
    _dio.options.headers['token'] = token;
  }

  bool get isReady => _baseUrl.isNotEmpty && _token.isNotEmpty;

  /// POST to iPet gateway (form-urlencoded), returns parsed [PeerResponse]
  Future<PeerResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? params,
    T Function(dynamic)? fromInfo,
    bool useJson = false, // true → application/json body
  }) async {
    if (!isReady) {
      throw Exception('[PeerApi] 设备接口未就绪，请检查网络或重新登录');
    }

    dynamic body;
    Options? options;
    if (useJson) {
      body = params ?? {};
      options = Options(headers: {'Content-Type': 'application/json'});
    } else {
      body = params != null
          ? Uri(
              queryParameters:
                  params.map((k, v) => MapEntry(k, v?.toString() ?? ''))).query
          : '';
    }

    final res = await _dio.post<dynamic>(
      path,
      data: body,
      options: options,
    );
    final json = _decodeResponseMap(res.data, path);
    final pr = PeerResponse<T>.fromJson(json, fromInfo);
    if (!pr.isSuccess) {
      debugPrint('[PeerApi] POST $path 业务错误 code=${pr.code}: ${pr.tip}');
      throw Exception('[iPet] ${pr.tip}');
    }
    return pr;
  }

  /// GET to iPet gateway (query params), returns parsed [PeerResponse]
  /// 部分接口（如 /user/device/online/state）服务端只接受 GET。
  Future<PeerResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? params,
    T Function(dynamic)? fromInfo,
  }) async {
    if (!isReady) {
      throw Exception('[PeerApi] 设备接口未就绪，请检查网络或重新登录');
    }

    final res = await _dio.get<dynamic>(
      path,
      queryParameters: params?.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    );
    final json = _decodeResponseMap(res.data, path);
    final pr = PeerResponse<T>.fromJson(json, fromInfo);
    if (!pr.isSuccess) {
      debugPrint('[PeerApi] GET $path 业务错误 code=${pr.code}: ${pr.tip}');
      throw Exception('[iPet] ${pr.tip}');
    }
    return pr;
  }

  // ── 声音控制 ─────────────────────────────────────────────

  /// 播放音频到设备  POST /pet/sound/play  (JSON body)
  /// [mac]    设备 MAC 地址
  /// [url]    音频 URL (MP3/AAC/FLAC/WAV)
  /// [volume] 0-21，默认 15
  Future<PeerResponse<void>> soundPlay({
    required String mac,
    required String url,
    int volume = 15,
  }) =>
      post<void>('/pet/sound/play', useJson: true, params: {
        'mac': mac,
        'url': url,
        'volume': volume,
      });

  /// 停止设备播放  POST /pet/sound/stop  (JSON body)
  Future<PeerResponse<void>> soundStop({required String mac}) =>
      post<void>('/pet/sound/stop', useJson: true, params: {'mac': mac});
}

// ── 日志拦截器 ────────────────────────────────────────────
Map<String, dynamic> _decodeResponseMap(dynamic data, String path) {
  if (data is Map) return data.cast<String, dynamic>();
  if (data is String) {
    final text = data.trim();
    if (text.isEmpty) {
      throw FormatException('[PeerApi] $path 返回空响应');
    }
    final decoded = jsonDecode(text);
    if (decoded is Map) return decoded.cast<String, dynamic>();
  }
  throw FormatException(
    '[PeerApi] $path 响应格式错误: ${data.runtimeType}',
  );
}

/// debugPrint 默认截断 800 字符，用此函数分段打印长内容保证完整显示
void _logLong(String msg, {int chunkSize = 500}) {
  if (msg.length <= chunkSize) {
    debugPrint(msg);
    return;
  }
  var offset = 0;
  var first = true;
  while (offset < msg.length) {
    final chunk =
        msg.substring(offset, (offset + chunkSize).clamp(0, msg.length));
    if (first) {
      debugPrint(chunk);
      first = false;
    } else {
      debugPrint('│  $chunk');
    }
    offset += chunkSize;
  }
}

class _PeerLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('\n┌─── [PeerAPI 请求] ─────────────────────────────');
    debugPrint('│ ${options.method} ${options.uri}');
    debugPrint('│ Content-Type: ${options.headers['Content-Type']}');
    _logLong('│ Body: ${_redactForLog(options.data)}');
    debugPrint('└───────────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('\n┌─── [PeerAPI 响应] ─────────────────────────────');
    debugPrint(
        '│ ${response.requestOptions.method} ${response.requestOptions.path}');
    debugPrint('│ ${response.statusCode} ${response.statusMessage ?? ''}');
    _logLong('│ Body: ${_redactForLog(response.data)}');
    debugPrint('└───────────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final req = err.requestOptions;
    final res = err.response;
    debugPrint('\n┌─── [PeerAPI 错误] ─────────────────────────────');
    debugPrint('│ ${req.method} ${req.uri}');
    debugPrint('│ 类型: ${err.type}');
    debugPrint('│ 状态码: ${res?.statusCode} ${res?.statusMessage ?? ''}');
    debugPrint('│ 请求头: ${_redactForLog(req.headers)}');
    _logLong('│ 请求体: ${_redactForLog(req.data)}');
    debugPrint(
        '│ 允许的方法(Allow): ${res?.headers.map['allow'] ?? res?.headers.map['Allow']}');
    debugPrint('│ 响应头: ${res?.headers.map}');
    _logLong('│ 响应体: ${_redactForLog(res?.data)}');
    _logLong('│ message: ${err.message}');
    debugPrint('└───────────────────────────────────────────────');
    handler.next(err);
  }
}

dynamic _redactForLog(dynamic value) {
  if (value is Map) {
    return value.map((key, item) {
      final normalized = key.toString().toLowerCase();
      const secrets = {
        'token',
        'authorization',
        'password',
        'p',
        'usersig',
        'clientsecret',
        'x-signature',
      };
      return MapEntry(
        key,
        secrets.contains(normalized) ? '***' : _redactForLog(item),
      );
    });
  }
  if (value is List) return value.map(_redactForLog).toList();
  if (value is String) {
    final text = value.trim();
    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      try {
        return _redactForLog(jsonDecode(text));
      } catch (_) {
        // 不是有效 JSON，继续按普通字符串脱敏。
      }
    }
    return value.replaceAllMapped(
      RegExp(
        r'(^|&)(token|authorization|password|p|usersig|clientsecret|x-signature)=([^&]*)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}${match.group(2)}=***',
    );
  }
  return value;
}

// ── Riverpod Provider ────────────────────────────────────
final peerApiClientProvider = Provider<PeerApiClient>((ref) {
  final client = PeerApiClient();

  void _tryInit() {
    final authState = ref.read(authControllerProvider);
    if (!authState.isLoggedIn || authState.user == null) return;
    final user = authState.user!;
    if (user.token.isEmpty) return;

    // 所有 iPet 请求统一走受控 HTTPS 网关；不再采用登录响应中的旧地址。
    const url = AppConfig.peerPublicBaseUrl;

    if (!client.isReady) {
      client.init(baseUrl: url, token: user.token);
      debugPrint('[PeerApi] 初始化完成 url=$url');
    } else {
      client.updateToken(user.token);
      debugPrint('[PeerApi] Token 已更新');
    }
  }

  // 监听登录状态变化（包含启动恢复 restoring → loggedIn 的场景）
  ref.listen(authControllerProvider, (prev, next) {
    if (next.isLoggedIn) _tryInit();
  }, fireImmediately: true);

  // 首次创建时主动检查（防止 fireImmediately 在 restoring 状态错过）
  _tryInit();

  return client;
});
