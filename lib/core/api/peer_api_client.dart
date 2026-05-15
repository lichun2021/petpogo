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

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../../features/auth/controller/auth_controller.dart';

// ── iPet 统一响应格式 ────────────────────────────────────
class PeerResponse<T> {
  final int    code;
  final String tip;
  final T?     info;
  final List<dynamic>? list;

  PeerResponse({required this.code, required this.tip, this.info, this.list});

  factory PeerResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromInfo,
  ) {
    return PeerResponse<T>(
      code: (json['code'] as int?) ?? -1,
      tip:  (json['tip']  as String?) ?? '',
      info: fromInfo != null && json['info'] != null ? fromInfo(json['info']) : null,
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
    _token   = token;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
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

  /// POST to iPet gateway, returns parsed [PeerResponse]
  Future<PeerResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? params,
    T Function(dynamic)? fromInfo,
  }) async {
    if (!isReady) {
      throw Exception('[PeerApi] 未初始化，请先登录');
    }
    final body = params != null
        ? params.map((k, v) => MapEntry(k, v?.toString() ?? ''))
        : <String, String>{};

    final res = await _dio.post<Map<String, dynamic>>(
      path,
      data: Uri(queryParameters: body).query,
    );
    final json = res.data!;
    final pr = PeerResponse<T>.fromJson(json, fromInfo);
    if (!pr.isSuccess) {
      debugPrint('[PeerApi] POST $path 业务错误 code=${pr.code}: ${pr.tip}');
      throw Exception('[iPet] ${pr.tip}');
    }
    return pr;
  }
}

// ── 日志拦截器 ────────────────────────────────────────────
class _PeerLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('\n┌─── [PeerAPI 请求] ─────────────────────────────');
    debugPrint('│ POST ${options.uri}');
    debugPrint('│ Body: ${options.data}');
    debugPrint('└───────────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('\n┌─── [PeerAPI 响应] ─────────────────────────────');
    debugPrint('│ ${response.statusCode} ${response.requestOptions.path}');
    debugPrint('│ Body: ${response.data}');
    debugPrint('└───────────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('\n┌─── [PeerAPI 错误] ─────────────────────────────');
    debugPrint('│ ${err.requestOptions.path}');
    debugPrint('│ ${err.message}');
    debugPrint('│ ${err.response?.data}');
    debugPrint('└───────────────────────────────────────────────');
    handler.next(err);
  }
}

// ── Riverpod Provider ────────────────────────────────────
final peerApiClientProvider = Provider<PeerApiClient>((ref) {
  final client = PeerApiClient();
  // 监听登录状态，自动初始化/更新 token 和 baseUrl
  ref.listen(authControllerProvider, (_, next) {
    if (next.isLoggedIn && next.user != null) {
      final user = next.user!;
      if (user.peerGatewayUrl.isNotEmpty && user.token.isNotEmpty) {
        if (!client.isReady) {
          client.init(baseUrl: user.peerGatewayUrl, token: user.token);
          debugPrint('[PeerApi] 初始化完成 url=${user.peerGatewayUrl}');
        } else {
          client.updateToken(user.token);
        }
      }
    }
  }, fireImmediately: true);
  return client;
});
