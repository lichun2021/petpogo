/// ════════════════════════════════════════════════════════════
///  AI 图像 Repository — 纯业务层
///
///  职责：
///    ✅ 上传图片到 POST /dog/analyze
///    ✅ 解析 DogImageAnalysisResult
///    ✅ 完整打印请求/响应日志
///    ❌ 不包含 UI 逻辑
/// ════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/result.dart';
import '../models/ai_image_model.dart';

const _tag = 'AI_IMG';

class AiImageRepository {
  late final Dio _dio;

  AiImageRepository() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.aiServiceBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60), // 图像推理较慢
    ));
    _dio.interceptors.add(_AiImageLogInterceptor());
  }

  /// 上传图片 → 获取 13 类情绪分析结果
  Future<Result<DogImageAnalysisResult>> analyze(File imageFile) =>
      guardResult(() async {
        final fileSize = imageFile.lengthSync();
        debugPrint('[$_tag] ▶ 开始上传图像分析');
        debugPrint('[$_tag]   URL  : ${ApiEndpoints.aiServiceBase}${ApiEndpoints.aiDogAnalyze}');
        debugPrint('[$_tag]   文件 : ${imageFile.path}');
        debugPrint('[$_tag]   大小 : ${(fileSize / 1024).toStringAsFixed(1)} KB');

        final sw = Stopwatch()..start();

        // 根据文件扩展名决定 MIME 类型
        final ext = imageFile.path.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png'
            : ext == 'webp' ? 'image/webp'
            : 'image/jpeg';

        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            imageFile.path,
            filename: 'pet_photo.$ext',
            contentType: DioMediaType.parse(mime),
          ),
        });

        try {
          final response = await _dio.post(
            ApiEndpoints.aiDogAnalyze,
            data: formData,
            options: Options(headers: {'Accept': 'application/json'}),
          );

          sw.stop();
          debugPrint('[$_tag] ✅ 响应成功 (${sw.elapsedMilliseconds}ms)');
          debugPrint('[$_tag]   HTTP 状态: ${response.statusCode}');
          debugPrint('[$_tag] ══ 原始 JSON ══════════════════════════');
          debugPrint('[$_tag] ${response.data}');
          debugPrint('[$_tag] ═══════════════════════════════════════');

          final raw = response.data as Map<String, dynamic>;
          final result = DogImageAnalysisResult.fromJson(raw);

          debugPrint('[$_tag]   主情绪: ${result.primaryPrediction.labelZh} '
              '(${result.primaryPrediction.percentText})');
          debugPrint('[$_tag]   Top-3 : ${result.top3.map((e) => '${e.labelZh}${e.percentText}').join(' / ')}');
          debugPrint('[$_tag]   建议  : ${result.advice.substring(0, result.advice.length.clamp(0, 30))}');
          debugPrint('[$_tag]   模型数: ${result.ensembleSize} | 服务端耗时: ${result.processingTimeMs}ms');

          return result;
        } on DioException catch (e) {
          sw.stop();
          debugPrint('[$_tag] ❌ 请求失败 (${sw.elapsedMilliseconds}ms)');
          debugPrint('[$_tag]   类型: ${e.type}');
          debugPrint('[$_tag]   状态码: ${e.response?.statusCode}');
          debugPrint('[$_tag]   消息: ${e.message}');
          debugPrint('[$_tag]   响应体: ${e.response?.data}');

          final code = e.response?.statusCode;
          final msg  = _extractMsg(e.response?.data) ?? e.message ?? '图像分析失败';
          throw ApiException(
            message: msg,
            statusCode: code,
            type: code != null && code >= 500
                ? ApiErrorType.server
                : ApiErrorType.network,
          );
        }
      });

  String? _extractMsg(dynamic data) {
    if (data is Map) return data['detail']?.toString() ?? data['message']?.toString();
    return null;
  }
}

// ── Dio 日志拦截器 ─────────────────────────────────────────
class _AiImageLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[$_tag] → ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('[$_tag] ← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[$_tag] ✗ ${err.type} ${err.requestOptions.path}: ${err.message}');
    handler.next(err);
  }
}

// ── Riverpod Provider ──────────────────────────────────────
final aiImageRepositoryProvider = Provider<AiImageRepository>((ref) {
  return AiImageRepository();
});
