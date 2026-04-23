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

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  /// 底层 Dio 实例（私有，外部不可直接使用）
  late final Dio _dio;

  /// 构造时可传入初始 Token（从 SecureStorage 读取的持久化 Token）
  ApiClient({String? token}) {
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

    // ── 注册拦截器链（按顺序执行）────────────────────────
    _dio.interceptors.addAll([
      // 1. Auth 拦截器：在每个请求头里自动插入 Token
      _AuthInterceptor(token: token),

      // 2. 错误拦截器：把 DioException → ApiException
      //    这是架构核心：上层代码不再需要了解 Dio 的异常类型
      _ErrorInterceptor(),

      // 3. 日志拦截器：仅 Debug 模式开启，打印请求/响应详情
      if (AppConfig.isDebug)
        LogInterceptor(
          requestBody: true,   // 打印请求体（用于调试 POST 参数）
          responseBody: true,  // 打印响应体（用于调试服务器返回）
          requestHeader: false, // 请求头不打印（Token 敏感信息）
        ),
    ]);
  }

  // ── HTTP 方法封装 ──────────────────────────────────────

  /// GET 请求
  ///
  /// [path]     - API 路径，如 '/pets'（从 ApiEndpoints 获取）
  /// [params]   - URL 查询参数，如 {'page': 1, 'size': 20}
  /// [fromJson] - JSON 反序列化函数，传入时自动解析，不传则返回原始数据
  ///
  /// 示例：
  ///   final pets = await _client.get<List<PetModel>>(
  ///     ApiEndpoints.pets,
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
  /// [data] - 请求体，会被自动序列化为 JSON
  Future<T> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    final res = await _dio.post(path, data: data);
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

// ── Auth 拦截器 ───────────────────────────────────────────
/// 在每个请求的 Header 中注入 Authorization Token
///
/// 注意：这里注入的是初始 Token（构造时传入）。
/// 登录后通过 ApiClient.setToken() 更新 Dio.options.headers，
/// 后续请求会自动携带新 Token，不需要重新创建 ApiClient。
class _AuthInterceptor extends Interceptor {
  final String? token;
  _AuthInterceptor({this.token});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 如果有初始 Token，注入到请求头
    if (token != null && token!.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    // 继续传递请求（必须调用，否则请求会被阻断）
    handler.next(options);
  }
}

// ── 错误转换拦截器 ─────────────────────────────────────────
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
        final serverMsg = _extractServerMessage(err.response?.data) ?? err.message ?? '';

        if (statusCode == 401) {
          // 未授权：Token 过期或无效
          apiEx = ApiException(
            message: serverMsg,
            statusCode: statusCode,
            type: ApiErrorType.unauthorized,
          );
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
        error: apiEx,          // 携带 ApiException
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
///
/// 整个 App 共享同一个 Dio 实例（节省资源、保持 Token 一致）。
/// Repository 通过 ref.read(apiClientProvider) 获取。
///
/// 生产环境接入：
///   可以在这里从 FlutterSecureStorage 读取持久化 Token：
///   final token = await ref.read(secureStorageProvider).read(key: 'token');
///   return ApiClient(token: token);
final apiClientProvider = Provider<ApiClient>((ref) {
  // TODO: 接入真实 Token 时，从 SecureStorage 读取
  return ApiClient();
});
