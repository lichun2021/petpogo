/// ════════════════════════════════════════════════════════════
///  API 客户端 — ApiClient
///
///  整个 App 只有一个 ApiClient 实例（通过 Riverpod 管理单例）。
///
///  架构职责：
///    ┌─ ApiClient ─────────────────────────────────────────┐
///    │  1. 统一配置 baseUrl / timeout / headers             │
///    │  2. 自动注入 Auth Token（登录后通过 setToken 更新）   │
///    │  3. 把所有 Dio 异常 → ApiException（上层不依赖 Dio）  │
///    │  4. Debug 模式打印请求/响应日志                       │
///    └─────────────────────────────────────────────────────┘
///
///  上下游关系：
///    ApiClient ← Repository ← Controller ← View
/// ════════════════════════════════════════════════════════════

library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'request_signature.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import 'api_exception.dart';
import 'api_endpoints.dart';

class ApiClient {
  /// 底层 Dio 实例（私有，外部不可直接使用）
  late final Dio _dio;

  /// 刷新凭证失效时的回调，由上层（AuthController）注入
  /// 用于触发 forceLogout() 而不造成循环依赖
  void Function()? onUnauthorized;
  Future<String?> Function()? onRefreshToken;
  Future<String?>? _refreshInFlight;
  String? get token => (_dio.options.headers['Authorization'] as String?)
      ?.replaceFirst('Bearer ', '');

  Future<String?> _refreshToken() {
    return _refreshInFlight ??= Future.sync(() => onRefreshToken?.call())
        .whenComplete(() => _refreshInFlight = null);
  }

  /// 构造时可传入初始 Token（从 SecureStorage 读取的持久化 Token）
  ApiClient({String? token, HttpClientAdapter? adapter}) {
    _dio = Dio(
      BaseOptions(
        // 服务器地址，从 AppConfig 统一管理（dev/prod 不同地址）
        baseUrl: AppConfig.apiBaseUrl,

        // 连接超时：超过 10 秒无法建立连接则报错
        connectTimeout: const Duration(seconds: 10),

        // 读取超时：连接成功后，等待响应最多 15 秒
        receiveTimeout: const Duration(seconds: 15),

        // 默认请求头
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    if (adapter != null) _dio.httpClientAdapter = adapter;
    if (token != null) setToken(token);

    // ── 注册拦截器链（按顺序执行）────────────────────────
    _dio.interceptors.addAll([
      // 1. Auth 拦截器：在每个请求头里自动插入 Token
      _AuthInterceptor(_dio.transformer),

      // 2. 错误拦截器：把 DioException → ApiException
      //    _SessionInterceptor 先处理续期，确认失效后才通知 AuthController
      _SessionInterceptor(this),
      _ErrorInterceptor(),

      // 3. 日志拦截器：仅 Debug 模式开启，完整打印 进/出 参数
      if (AppConfig.isDebug) _DevLogInterceptor(),
    ]);
  }

  // ── HTTP 方法封装 ──────────────────────────────────────

  /// GET 请求
  ///
  /// [path]     - API 路径，如 '/sdkapi/pet/list'（从 ApiEndpoints 获取）
  /// [params]   - URL 查询参数，如 {'page': 1, 'size': 20}
  /// [fromJson] - JSON 反序列化函数，传入时自动解析，不传则返回原始数据
  ///
  /// 示例：
  ///   final pets = await _client.get(
  ///     ApiEndpoints.petList,
  ///     fromJson: (data) => (data as List).map(PetModel.fromJson).toList(),
  ///   );
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? params,
    T Function(dynamic)? fromJson,
  }) async {
    final res = await _dio.get(path, queryParameters: params);
    return fromJson != null ? fromJson(res.data) : res.data as T;
  }

  /// POST 请求（创建资源）
  ///
  /// [data]    - 请求体，会被自动序列化为 JSON
  /// [options] - 可选 Dio Options（如自定义超时）
  Future<T> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
    Options? options,
  }) async {
    final res = await _dio.post(path, data: data, options: options);
    return fromJson != null ? fromJson(res.data) : res.data as T;
  }

  /// PUT 请求（更新资源，全量替换）
  Future<T> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    final res = await _dio.put(path, data: data);
    return fromJson != null ? fromJson(res.data) : res.data as T;
  }

  /// PATCH 请求（更新资源，部分修改）
  Future<T> patch<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    final res = await _dio.patch(path, data: data);
    return fromJson != null ? fromJson(res.data) : res.data as T;
  }

  /// DELETE 请求（删除资源）
  Future<void> delete(String path) async {
    await _dio.delete(path);
  }

  // ── SSE 流式响应 ───────────────────────────────────────

  /// 流式 POST，返回 SSE 帧流（适用大模型逐 token 输出等场景）
  ///
  /// [url] 可以是相对路径（走 baseUrl）或完整 URL（http(s)://...），
  /// 完整 URL 形式用于访问独立后端（如宠小伊 AI 服务），
  /// 此时会绕开 baseUrl 但仍然经过现有拦截器。
  ///
  /// 行为：
  ///   - 4xx/5xx → 经 _ErrorInterceptor 转 ApiException 抛出
  ///   - 200 但流中 event: error → 作为普通帧 yield，Repository 自行处理
  ///   - 服务器关流 → Stream 自然结束
  ///
  /// 调用方必须用 try/catch 包裹 `await for` 以处理 ApiException。
  Stream<SseFrame> postStream(
    String url, {
    Object? data,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) async* {
    final token = cancelToken ?? CancelToken();
    var timedOut = false;
    final timer = Timer(const Duration(seconds: 310), () {
      timedOut = true;
      token.cancel('stream deadline');
    });
    try {
      yield* _postStreamFrames(url,
          data: data, headers: headers, cancelToken: token);
      if (timedOut) {
        throw const ApiException(
            message: '回答超时，请重试', type: ApiErrorType.timeout);
      }
    } catch (_) {
      if (timedOut) {
        throw const ApiException(
            message: '回答超时，请重试', type: ApiErrorType.timeout);
      }
      rethrow;
    } finally {
      timer.cancel();
      if (!token.isCancelled) token.cancel('stream closed');
    }
  }

  Stream<SseFrame> _postStreamFrames(
    String url, {
    Object? data,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) async* {
    final response = await _dio.post<ResponseBody>(
      url,
      data: data,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        // SSE 是长连接，receiveTimeout 必须关掉，否则会被强制断开
        receiveTimeout: Duration.zero,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          if (headers != null) ...headers,
        },
      ),
    );

    // ── SSE 分帧解析 ──
    // 协议：每帧由若干 "field: value\n" 行组成，以空行（\n\n）结束
    String currentEvent = 'message';
    final dataBuf = StringBuffer();

    final lines = response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) {
        // 空行 = 一帧结束 → flush
        if (dataBuf.isNotEmpty || currentEvent != 'message') {
          yield SseFrame(event: currentEvent, data: dataBuf.toString());
          currentEvent = 'message';
          dataBuf.clear();
        }
        continue;
      }
      // 以 ':' 开头是 SSE 注释/心跳，忽略
      if (line.startsWith(':')) continue;

      final idx = line.indexOf(':');
      if (idx < 0) continue;
      final field = line.substring(0, idx);
      var value = line.substring(idx + 1);
      if (value.startsWith(' ')) value = value.substring(1);

      if (field == 'event') {
        currentEvent = value;
      } else if (field == 'data') {
        if (dataBuf.isNotEmpty) dataBuf.write('\n');
        dataBuf.write(value);
      }
      // id / retry 字段暂不处理
    }

    // 服务器关流前如果还有未 flush 的帧（没以空行结尾），补 yield 一次
    if (dataBuf.isNotEmpty || currentEvent != 'message') {
      yield SseFrame(event: currentEvent, data: dataBuf.toString());
    }
  }

  // ── Token 管理 ────────────────────────────────────────

  /// 登录成功后更新 Token
  ///
  /// 调用时机：
  ///   1. 登录接口返回 token 后
  ///   2. Token 刷新后
  ///
  /// 用法：
  ///   ref.read(apiClientProvider).setToken(loginResponse.token);
  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// 退出登录后清除 Token
  void clearToken() {
    _dio.options.headers.remove('Authorization');
  }
}

// ── SSE 帧 ────────────────────────────────────────────────
/// Server-Sent Events 单帧
///
/// SSE 协议格式：
///   event: name\n        ← 可选，默认 'message'
///   data: payload\n      ← 多行 data 会被拼成同一帧（用 \n 分隔）
///   \n                     ← 空行结束一帧
class SseFrame {
  /// 事件名，缺省 'message'（SSE 协议规定）
  final String event;

  /// data 字段的内容（多行 data 已以 \n 拼接）
  final String data;

  const SseFrame({required this.event, required this.data});

  @override
  String toString() => 'SseFrame(event=$event, data=$data)';
}

// ── Auth 拦截器 ───────────────────────────────────────────
/// 在每个请求的 Header 中注入 Authorization Token
///
/// 登录凭证由 ApiClient.setToken/clearToken 管理；此处只负责路由与 SDK 签名。
class _AuthInterceptor extends Interceptor {
  final Transformer _transformer;
  _AuthInterceptor(this._transformer);

  // nonce 随机数生成器（防重放标识用）
  static final _rand = Random.secure();

  /// 生成防重放 nonce：32 位十六进制随机串（16 字节熵）
  /// 服务端要求 16–128 位，5 分钟窗口内不可重复。
  String _genNonce() {
    final bytes = List<int>.generate(16, (_) => _rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final path = Uri.parse(options.path).path;
    final isAi = path.startsWith('${ApiEndpoints.aiProxyPrefix}/');
    if (isAi) {
      options.headers.removeWhere((key, _) => {
            'x-api-key',
            'x-signature',
            'x-timestamp'
          }.contains(key.toLowerCase()));
      // Account is authoritative on the server; never trust stale local storage.
      if (options.data is FormData) {
        final form = (options.data as FormData).clone();
        form.fields.removeWhere((entry) => entry.key == 'account');
        options.data = form;
      } else if (options.data is Map) {
        options.data = Map<String, dynamic>.from(options.data as Map)
          ..remove('account');
      }
      if (options.responseType != ResponseType.stream) {
        options.receiveTimeout = path.endsWith('/video/recording/stop')
            ? const Duration(seconds: 310)
            : const Duration(seconds: 130);
      }
    } else if (path.startsWith('${ApiEndpoints.peerProxyPrefix}/')) {
      options.receiveTimeout = const Duration(seconds: 30);
      if (path == ApiEndpoints.peerCountryList ||
          path == ApiEndpoints.peerCountryDefault) {
        options.headers
            .removeWhere((key, _) => key.toLowerCase() == 'authorization');
      }
    }

    if (options.uri.path.startsWith('/sdkapi/')) {
      try {
        final body = await _bodyBytes(options);
        // 固定正文后签名；Dio 直接发送字节，避免再次编码导致验签失败。
        if (options.data != null) options.data = body;
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final nonce = _genNonce();
        const secret = '1q21ee182efd1gf1g@#\$';
        options.headers.removeWhere((key, _) => {
              'x-signature-version',
              'x-key-id',
              'x-timestamp',
              'x-nonce',
              'x-signature',
              'content-length',
            }.contains(key.toLowerCase()));
        options.headers.addAll({
          'x-signature-version': '2',
          'x-key-id': 'primary',
          'x-timestamp': timestamp,
          'x-nonce': nonce,
          'x-signature': sdkSignatureV2(
            secret: secret,
            method: options.method,
            uri: options.uri,
            timestamp: timestamp,
            nonce: nonce,
            body: body,
          ),
        });
      } catch (error, stack) {
        handler.reject(DioException(
            requestOptions: options, error: error, stackTrace: stack));
        return;
      }
    }

    // 继续传递请求（必须调用，否则请求会被阻断）
    handler.next(options);
  }

  Future<Uint8List> _bodyBytes(RequestOptions options) async {
    final data = options.data;
    if (data == null) return Uint8List(0);
    if (data is Uint8List) return data;
    if (data is FormData) {
      options.contentType =
          '${Headers.multipartFormDataContentType}; boundary=${data.boundary}';
      return data.readAsBytes();
    }
    if (data is Stream) {
      throw ArgumentError('SDKAPI 签名请求需要可读取的完整正文');
    }
    final text = await _transformer.transformRequest(options);
    final encoder = options.requestEncoder;
    final bytes =
        encoder == null ? utf8.encode(text) : await encoder(text, options);
    return Uint8List.fromList(bytes);
  }
}

// ── 开发日志拦截器 ────────────────────────────────────────
/// 完整打印每个请求的 进/出 参数，方便开发调试
/// 使用 debugPrint 确保日志能被 ./log.sh 捕获

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

bool _isProxyRequest(RequestOptions options) =>
    options.uri.path.startsWith('${ApiEndpoints.peerProxyPrefix}/') ||
    options.uri.path.startsWith('${ApiEndpoints.aiProxyPrefix}/') ||
    options.uri.path.startsWith('/sdkapi/auth/');

class _DevLogInterceptor extends Interceptor {
  // 记录请求开始时间，用于计算耗时
  final _startTimes = <String, DateTime>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = '${options.method}:${options.path}';
    _startTimes[key] = DateTime.now();

    debugPrint('\n┌─── [API 请求] ─────────────────────────────');
    debugPrint(
        '│ ${options.method} ${_isProxyRequest(options) ? options.uri.path : options.uri}');
    // 请求头（过滤掉 Authorization 的具体 token 值，只显示是否有）
    final headers = Map<String, dynamic>.from(options.headers);
    headers.updateAll((key, value) => {
          'authorization',
          'x-api-key',
          'x-signature',
          'x-nonce'
        }.contains(key.toLowerCase())
            ? '***'
            : value);
    debugPrint('│ Headers: $headers');
    if (!_isProxyRequest(options) && options.queryParameters.isNotEmpty) {
      debugPrint('│ Query: ${options.queryParameters}');
    }
    if (options.data != null) {
      _logLong(
          '│ Body: ${_isProxyRequest(options) ? '<proxy payload omitted>' : options.data is Uint8List ? '<${(options.data as Uint8List).length} bytes>' : options.data}');
    }
    debugPrint('└─────────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final key =
        '${response.requestOptions.method}:${response.requestOptions.path}';
    final ms = DateTime.now()
        .difference(_startTimes.remove(key) ?? DateTime.now())
        .inMilliseconds;

    debugPrint('\n┌─── [API 响应] ─────────────────────────────');
    debugPrint(
        '│ ${response.statusCode} ${response.requestOptions.uri}  (${ms}ms)');
    if (response.requestOptions.responseType == ResponseType.stream) {
      debugPrint('│ Body: <streaming>');
    } else {
      _logLong(
          '│ Body: ${_isProxyRequest(response.requestOptions) ? '<proxy payload omitted>' : response.data}');
    }
    debugPrint('└─────────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final key = '${err.requestOptions.method}:${err.requestOptions.path}';
    _startTimes.remove(key);

    debugPrint('\n┌─── [API 错误] ─────────────────────────────');
    debugPrint('│ ${err.requestOptions.method} ${err.requestOptions.uri}');
    debugPrint('│ Type: ${err.type}');
    debugPrint('│ Status: ${err.response?.statusCode}');
    _logLong(
        '│ Body: ${_isProxyRequest(err.requestOptions) ? '<proxy payload omitted>' : err.response?.data}');
    if (!_isProxyRequest(err.requestOptions)) _logLong('│ Msg: ${err.message}');
    debugPrint('└─────────────────────────────────────────────');
    handler.next(err);
  }
}

/// 仅携带当前登录凭证的请求允许续期；并发 401 共用一次刷新。
class _SessionInterceptor extends Interceptor {
  final ApiClient client;
  _SessionInterceptor(this.client);

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) async {
    final request = error.requestOptions;
    final sent = request.headers['Authorization'];
    if (error.response?.statusCode != 401 ||
        sent == null ||
        !request.uri.path.startsWith('/sdkapi/') ||
        request.uri.path.startsWith('/sdkapi/auth/') ||
        request.extra['sessionRetried'] == true) {
      handler.next(error);
      return;
    }
    final originalToken = client.token;
    if (originalToken == null) {
      handler.next(error);
      return;
    }
    String? renewed;
    try {
      renewed = sent != 'Bearer $originalToken'
          ? originalToken
          : await client._refreshToken();
    } catch (refreshError) {
      if (refreshError is DioException) {
        if (refreshError.response?.statusCode == 401 &&
            client.token == originalToken) {
          client.onUnauthorized?.call();
        }
        handler.next(DioException(
            requestOptions: request,
            type: refreshError.type,
            response: refreshError.response,
            error: refreshError.error,
            message: refreshError.message));
      } else {
        handler
            .next(DioException(requestOptions: request, error: refreshError));
      }
      return;
    }
    if (renewed == null) {
      if (client.token == originalToken) client.onUnauthorized?.call();
      handler.next(error);
      return;
    }
    // 用户在刷新期间退出或换了账号，不重放旧账号的请求。
    if (client.token != originalToken && client.token != renewed) {
      handler.next(error);
      return;
    }
    client.setToken(renewed);
    request.headers['Authorization'] = 'Bearer $renewed';
    request.extra['sessionRetried'] = true;
    try {
      handler.resolve(await client._dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}

/// 把 DioException 转换为 ApiException
///
/// 这是最重要的拦截器：经过这里之后，上层代码（Repository/Controller）
/// 完全不需要知道底层使用的是 Dio，只处理 ApiException 即可。
///
/// 转换规则：
///   connectionTimeout / sendTimeout / receiveTimeout → ApiErrorType.timeout
///   connectionError（无网络）                        → ApiErrorType.network
///   badResponse 401                                  → ApiErrorType.unauthorized
///   badResponse 404                                  → ApiErrorType.notFound
///   badResponse 5xx                                  → ApiErrorType.server
///   其他                                             → ApiErrorType.unknown
class _ErrorInterceptor extends Interceptor {
  _ErrorInterceptor();
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    ApiException apiEx;

    switch (err.type) {
      // 连接超时 / 发送超时 / 接收超时
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        apiEx = const ApiException(
          message: '请求超时',
          type: ApiErrorType.timeout,
        );
        break;

      // 网络不通（WiFi 未连接、飞行模式等）
      case DioExceptionType.connectionError:
        apiEx = const ApiException(
          message: '网络连接失败',
          type: ApiErrorType.network,
        );
        break;

      // 服务器返回了 4xx / 5xx 错误
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode ?? 0;
        // 尝试从响应体中提取服务器的错误消息
        final serverMsg =
            _extractServerMessage(err.response?.data) ?? err.message ?? '';

        if (statusCode == 401) {
          // 未授权：Token 过期或无效 → 触发强制登出回调
          apiEx = ApiException(
            message: serverMsg,
            statusCode: statusCode,
            type: ApiErrorType.unauthorized,
          );
          // 通知上层清除会话（避免直接引用 Riverpod）
          // 会话续期与失效处理由 _SessionInterceptor 负责。
        } else if (statusCode == 404) {
          // 资源不存在
          apiEx = ApiException(
            message: serverMsg,
            statusCode: statusCode,
            type: ApiErrorType.notFound,
          );
        } else if (statusCode >= 500) {
          // 服务端错误
          apiEx = ApiException(
            message: serverMsg,
            statusCode: statusCode,
            type: ApiErrorType.server,
          );
        } else {
          // 其他 4xx（如 400 参数错误、403 无权限）
          apiEx = ApiException(
            message: serverMsg,
            statusCode: statusCode,
          );
        }
        break;

      // 取消请求（用户主动取消，通常不需要提示）
      case DioExceptionType.cancel:
        apiEx = const ApiException(
          message: '请求已取消',
          type: ApiErrorType.unknown,
        );
        break;

      // 其他未分类异常
      default:
        apiEx = ApiException(message: err.message ?? '未知错误');
    }

    // 重要：把原始 DioException 替换为包含 ApiException 的新异常
    // 这样上层捕获到的 error 就是 ApiException，而不是 DioException
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: apiEx, // 携带 ApiException
        type: err.type,
        response: err.response,
      ),
    );
  }

  /// 从响应体中提取服务器错误信息
  ///
  /// 假设服务器返回格式：{ "code": 400, "message": "参数错误" }
  /// 可根据实际 API 格式调整解析逻辑
  String? _extractServerMessage(dynamic data) {
    if (data is Map) {
      return data['message'] as String? ?? data['msg'] as String?;
    }
    return null;
  }
}

// ── Riverpod Provider ─────────────────────────────────────
/// 全局唯一的 ApiClient Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
