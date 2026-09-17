/// ════════════════════════════════════════════════════════════
///  健康数据 — HealthDataRepository
///
///  后端：AppConfig.aiConsultBaseUrl (https://ai.jxpetai.com)
///  鉴权：X-API-Key + X-Timestamp + X-Signature (与 aiConsult 共享)
///
///  四个接口统一响应格式 {code:0, info:object, tip:string}
/// ════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/result.dart';
import '../../../../core/config/app_config.dart';
import '../models/health_data_models.dart';

class HealthDataRepository {
  final ApiClient _client;

  HealthDataRepository(this._client);

  // ── URL 拼接 ──────────────────────────────────────────
  String _url(String path) => '${AppConfig.aiConsultBaseUrl}$path';

  // ── 统一响应解包 ──────────────────────────────────────
  /// 所有接口返回 {code:int, info:object|null, tip:string}
  /// code==0 → 成功，返回 info；code!=0 → 业务错误，抛 ApiException
  Map<String, dynamic> _unwrap(Map<String, dynamic> data) {
    final code = data['code'] as int? ?? 0;
    if (code != 0) {
      final tip = (data['tip'] as String?) ?? '请求失败';
      throw ApiException(message: tip, type: ApiErrorType.server);
    }
    return (data['info'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  // ── 422 错误重写（FastAPI 校验错误）──────────────────
  /// 将 422 参数校验错误改写为通用用户友好消息，避免暴露 FastAPI 内部结构
  Future<Result<T>> _guardWithValidationRewrite<T>(Future<T> Function() fn) {
    return guardResult(() async {
      try {
        return await fn();
      } on ApiException catch (e) {
        if (e.statusCode == 422) {
          throw ApiException(
            message: '请求参数有误，请重试',
            type: ApiErrorType.server,
            statusCode: 422,
          );
        }
        rethrow;
      }
    });
  }

  // ── 1. 健康数据概览 ──────────────────────────────────
  Future<Result<HealthOverview>> fetchOverview({
    required String petId,
    String? date,
  }) =>
      _guardWithValidationRewrite(() async {
        final body = <String, dynamic>{'pet_id': petId};
        if (date != null) body['date'] = date;

        final data = await _client.post<Map<String, dynamic>>(
          _url(ApiEndpoints.healthDataOverview),
          data: body,
        );
        final info = _unwrap(data);
        return HealthOverview.fromJson(info);
      });

  // ── 2. 健康数据报告 ──────────────────────────────────
  Future<Result<HealthReport>> fetchHealthReport({
    required String petId,
    String? date,
  }) =>
      _guardWithValidationRewrite(() async {
        final body = <String, dynamic>{'pet_id': petId};
        if (date != null) body['date'] = date;

        final data = await _client.post<Map<String, dynamic>>(
          _url(ApiEndpoints.healthDataReport),
          data: body,
        );
        final info = _unwrap(data);
        return HealthReport.fromJson(info);
      });

  // ── 3. 行为分析详情 ──────────────────────────────────
  Future<Result<BehaviorAnalysis>> fetchBehaviorAnalysis({
    required String petId,
    String? date,
    String? period, // 'day' | 'week' | 'month'
  }) =>
      _guardWithValidationRewrite(() async {
        final body = <String, dynamic>{'pet_id': petId};
        if (date != null) body['date'] = date;
        if (period != null) body['period'] = period;

        final data = await _client.post<Map<String, dynamic>>(
          _url(ApiEndpoints.healthDataBehaviorAnalysis),
          data: body,
        );
        final info = _unwrap(data);
        return BehaviorAnalysis.fromJson(info);
      });

  // ── 4. 运动数据详情 ──────────────────────────────────
  Future<Result<ExerciseData>> fetchExerciseData({
    required String petId,
    String? date,
    String? period, // 'day' | 'week' | 'month'
  }) =>
      _guardWithValidationRewrite(() async {
        final body = <String, dynamic>{'pet_id': petId};
        if (date != null) body['date'] = date;
        if (period != null) body['period'] = period;

        final data = await _client.post<Map<String, dynamic>>(
          _url(ApiEndpoints.healthDataExerciseData),
          data: body,
        );
        final info = _unwrap(data);
        return ExerciseData.fromJson(info);
      });
}

// ── Provider ────────────────────────────────────────────
final healthDataRepositoryProvider = Provider<HealthDataRepository>(
  (ref) => HealthDataRepository(ref.watch(apiClientProvider)),
);
