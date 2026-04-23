import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/result.dart';
import '../models/ai_analysis_model.dart';

/// 日志 Tag — 在 logcat 里过滤 "AI_REPO" 即可看到所有 AI 调用日志
const _tag = 'AI_REPO';

class AiVoiceRepository {
  late final Dio _dio;

  AiVoiceRepository() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.aiServiceBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    // 添加日志拦截器，打印完整请求/响应
    _dio.interceptors.add(_AiLogInterceptor());
  }

  /// 上传音频 → 获取物种 + 情绪分析结果
  Future<Result<AiAnalysisResult>> analyze(File audioFile) =>
      guardResult(() async {
        // ── 请求前日志 ───────────────────────────────
        final fileSize = audioFile.lengthSync();
        debugPrint('[$_tag] ▶ 开始上传分析');
        debugPrint('[$_tag]   URL  : ${ApiEndpoints.aiServiceBase}${ApiEndpoints.aiAnalyze}');
        debugPrint('[$_tag]   文件 : ${audioFile.path}');
        debugPrint('[$_tag]   大小 : ${(fileSize / 1024).toStringAsFixed(1)} KB');

        final sw = Stopwatch()..start();

        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            audioFile.path,
            filename: 'pet_voice.wav',
          ),
        });

        try {
          final response = await _dio.post(
            ApiEndpoints.aiAnalyze,
            data: formData,
            options: Options(headers: {'Accept': 'application/json'}),
          );

          sw.stop();

          // ── 响应日志 ─────────────────────────────────
          debugPrint('[$_tag] ✅ 响应成功 (${sw.elapsedMilliseconds}ms)');
          debugPrint('[$_tag]   HTTP 状态: ${response.statusCode}');

          final raw = response.data as Map<String, dynamic>;
          debugPrint('[$_tag]   物种: ${raw['species']?['label_zh']} '
              '(${((raw['species']?['confidence'] ?? 0) * 100).toStringAsFixed(1)}%)');

          final emotions = raw['emotions'] as List? ?? [];
          for (int i = 0; i < emotions.length; i++) {
            final e = emotions[i] as Map<String, dynamic>;
            debugPrint('[$_tag]   情绪#${i + 1}: ${e['label_zh']} '
                '(${((e['confidence'] ?? 0) * 100).toStringAsFixed(1)}%)');
          }
          debugPrint('[$_tag]   建议: ${(raw['advice'] as String?)?.substring(0, 30)}...');
          debugPrint('[$_tag]   服务端耗时: ${raw['processing_time_ms']}ms');

          return AiAnalysisResult.fromJson(raw);

        } on DioException catch (e) {
          sw.stop();

          // ── 错误日志 ─────────────────────────────────
          debugPrint('[$_tag] ❌ 请求失败 (${sw.elapsedMilliseconds}ms)');
          debugPrint('[$_tag]   类型: ${e.type}');
          debugPrint('[$_tag]   状态码: ${e.response?.statusCode}');
          debugPrint('[$_tag]   消息: ${e.message}');
          debugPrint('[$_tag]   响应体: ${e.response?.data}');

          final code = e.response?.statusCode;
          final msg  = _extractMsg(e.response?.data) ?? e.message ?? '分析失败';
          throw ApiException(
            message: msg,
            statusCode: code,
            type: code != null && code >= 500
                ? ApiErrorType.server
                : ApiErrorType.network,
          );
        }
      });

  /// 检查 AI 服务健康状态
  Future<bool> isServiceAlive() async {
    debugPrint('[$_tag] 🔍 检查 AI 服务状态: ${ApiEndpoints.aiServiceBase}/health');
    try {
      final res = await _dio.get(
        ApiEndpoints.aiHealth,
        options: Options(sendTimeout: const Duration(seconds: 5)),
      );
      final data = res.data as Map<String, dynamic>;
      final ok = data['status'] == 'ok' &&
          (data['emotion_model_loaded'] == true) &&
          (data['species_model_loaded'] == true);
      debugPrint('[$_tag] 服务状态: ${ok ? "✅ 在线" : "⚠️ 异常"} | $data');
      return ok;
    } catch (e) {
      debugPrint('[$_tag] ❌ 服务不可达: $e');
      return false;
    }
  }

  String? _extractMsg(dynamic data) {
    if (data is Map) return data['detail']?.toString() ?? data['message']?.toString();
    return null;
  }
}

// ── Dio 日志拦截器 ────────────────────────────────────────
/// 打印每次 HTTP 请求/响应的完整信息到 logcat
class _AiLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[$_tag] → ${options.method} ${options.uri}');
    debugPrint('[$_tag]   Content-Type: ${options.contentType}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('[$_tag] ← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[$_tag] ✗ ${err.type} ${err.requestOptions.path}');
    debugPrint('[$_tag]   ${err.message}');
    handler.next(err);
  }
}

// ── Riverpod Provider ─────────────────────────────────────
final aiVoiceRepositoryProvider = Provider<AiVoiceRepository>((ref) {
  return AiVoiceRepository();
});
