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
    bool useJson = false,   // true → application/json body
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
          ? Uri(queryParameters: params.map((k, v) => MapEntry(k, v?.toString() ?? ''))).query
          : '';
    }

    final res = await _dio.post<Map<String, dynamic>>(
      path,
      data: body,
      options: options,
    );
    final json = res.data!;
    final pr = PeerResponse<T>.fromJson(json, fromInfo);
    if (!pr.isSuccess) {
      debugPrint('[PeerApi] POST $path 业务错误 code=${pr.code}: ${pr.tip}');
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
/// iPet 硬件网关 BaseUrl 兜底（环境变量未配置时使用）
const _kFallbackPeerUrl = 'http://49.234.39.11:8006';

final peerApiClientProvider = Provider<PeerApiClient>((ref) {
  final client = PeerApiClient();

  void _tryInit() {
    final authState = ref.read(authControllerProvider);
    if (!authState.isLoggedIn || authState.user == null) return;
    final user = authState.user!;
    if (user.token.isEmpty) return;

    // peerGatewayUrl 可能为空（后端环境变量未配）→ 用兜底地址
    final url = user.peerGatewayUrl.isNotEmpty ? user.peerGatewayUrl : _kFallbackPeerUrl;

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
