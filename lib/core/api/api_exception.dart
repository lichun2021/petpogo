/// ════════════════════════════════════════════════════════════
///  统一 API 异常类型 — ApiException
///
///  为什么要统一异常？
///    - ApiClient 的拦截器把所有 Dio/网络异常统一转为 ApiException
///    - Repository 和 Controller 只需处理 ApiException，
///      不依赖 Dio 具体的异常类型，方便以后换 HTTP 库
///    - userMessage 提供用户友好的中文提示，直接显示到 UI
/// ════════════════════════════════════════════════════════════
class ApiException implements Exception {
  /// HTTP 状态码（网络异常时可能为 null）
  final int? statusCode;

  /// 技术性错误信息（用于开发调试，不直接显示给用户）
  final String message;

  /// 错误类型（用于区分不同的处理策略）
  final ApiErrorType type;

  const ApiException({
    required this.message,
    this.statusCode,
    this.type = ApiErrorType.unknown,
  });

  @override
  String toString() => 'ApiException[$type|$statusCode]: $message';

  // ── 用户友好提示 ────────────────────────────────────────
  /// 根据错误类型返回中文提示，直接传给 SnackBar / Dialog 显示
  ///
  /// 如果需要多语言，可以在此传入 AppL10n 对象替换文字
  String get userMessage {
    switch (type) {
      case ApiErrorType.network:
        return '网络连接失败，请检查你的网络设置';
      case ApiErrorType.timeout:
        return '请求超时，请稍后重试';
      case ApiErrorType.unauthorized:
        return '登录已过期，请重新登录';
      case ApiErrorType.notFound:
        return '该内容不存在或已被删除';
      case ApiErrorType.server:
        return '服务器繁忙，请稍后重试';
      case ApiErrorType.unknown:
        // 如果后端返回了具体的错误消息，直接显示
        return message.isNotEmpty ? message : '出了点问题，请重试';
    }
  }
}

// ── 错误类型枚举 ──────────────────────────────────────────
/// 对应不同的处理策略：
///   - network / timeout → 引导用户检查网络
///   - unauthorized      → 跳转登录页
///   - notFound          → 提示内容不存在
///   - server            → 提示稍后重试
///   - unknown           → 显示后端返回的 message
enum ApiErrorType {
  /// 无网络 / DNS 解析失败 / 连接被拒绝
  network,

  /// 请求超时（connectTimeout / receiveTimeout）
  timeout,

  /// HTTP 401 — Token 过期或未登录
  unauthorized,

  /// HTTP 404 — 资源不存在
  notFound,

  /// HTTP 5xx — 服务端错误
  server,

  /// 其他未归类异常（JSON 解析失败、空指针等）
  unknown,
}
