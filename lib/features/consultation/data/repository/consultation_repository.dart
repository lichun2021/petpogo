/// ════════════════════════════════════════════════════════════
///  宠小伊 AI 问诊 — ConsultationRepository
///
///  后端：AppConfig.aiConsultBaseUrl (49.234.39.11:8007)
///
///  v0.4 API 变更（已全量适配）：
///    ① 统一响应格式 {code, info, tip}，通过 _unwrap() 统一解包
///    ② /session/new 改为 POST + JSON body，pet_id 必填
///    ③ /report 的 disease_card 改为英文 key，probability 为 int
///    ④ 错误以 code==1 返回而非 HTTP 4xx
///    ⑤ 新增 /session/by-pet 和 /session/messages 历史接口
/// ════════════════════════════════════════════════════════════

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/result.dart';
import '../../../../core/config/app_config.dart';
import '../models/auto_analysis_models.dart';
import '../models/consultation_models.dart';

class ConsultationRepository {
  final ApiClient _client;

  ConsultationRepository(this._client);

  // ── URL 拼接 ──────────────────────────────────────────
  String _url(String path) => '${AppConfig.aiConsultBaseUrl}$path';

  // ── 统一响应解包 ──────────────────────────────────────
  /// v0.4 所有接口返回 {code:int, info:object|null, tip:string}
  /// code==0 → 成功，返回 info；code!=0 → 业务错误，抛 ApiException
  Map<String, dynamic> _unwrap(Map<String, dynamic> data) {
    final code = data['code'] as int? ?? 0;
    if (code != 0) {
      final tip = (data['tip'] as String?) ?? '请求失败';
      throw ApiException(message: tip, type: ApiErrorType.server);
    }
    return (data['info'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  // ── 1. 创建 Session（v0.4：POST JSON body，pet_id 必填）────
  Future<Result<ConsultationSession>> createSession({
    required String petId,
  }) =>
      guardResult(() async {
        final data = await _client.post<Map<String, dynamic>>(
          _url(ApiEndpoints.aiConsultSessionNew),
          data: {'pet_id': petId},
        );
        return ConsultationSession.fromJson(_unwrap(data));
      });

  // ── 2. 流式问诊（主入口）──────────────────────────────
  /// SSE 流：StreamStart → StreamDelta × N → StreamDone
  Stream<ConsultationStreamEvent> sendMessageStream({
    required String sessionId,
    required String text,
    CancelToken? cancelToken,
  }) async* {
    final frames = _client.postStream(
      _url(ApiEndpoints.aiConsultMessagesStream),
      data: {'session_id': sessionId, 'text': text},
      cancelToken: cancelToken,
    );

    await for (final frame in frames) {
      switch (frame.event) {
        case 'start':
          yield StreamStart(decodeSseData(frame.data));
        case 'delta':
          yield StreamDelta(decodeSseData(frame.data));
        case 'done':
          yield StreamDone(decodeSseData(frame.data));
        case 'error':
          throw ApiException(
            message: decodeSseData(frame.data),
            type: ApiErrorType.server,
          );
        default:
          yield StreamUnknown(frame.event, frame.data);
      }
    }
  }

  // ── 3. 同步问诊（降级/调试用）─────────────────────────
  Future<Result<ConsultationTurn>> sendMessageSync({
    required String sessionId,
    required String text,
  }) =>
      guardResult(() async {
        final data = await _client.post<Map<String, dynamic>>(
          _url(ApiEndpoints.aiConsultMessages),
          data: {'session_id': sessionId, 'text': text},
        );
        return ConsultationTurn.fromJson(_unwrap(data));
      });

  // ── 4. 生成诊断报告 ───────────────────────────────────
  Future<Result<ConsultationReport>> generateReport({
    required String sessionId,
  }) =>
      guardResult(() async {
        final data = await _client.post<Map<String, dynamic>>(
          _url(ApiEndpoints.aiConsultReport),
          data: {'session_id': sessionId},
        );
        return ConsultationReport.fromJson(_unwrap(data));
      });

  // ── 5. 删除 Session ───────────────────────────────────
  /// 只在用户没有生成报告就退出时调用。
  /// v0.4：错误以 code!=0 返回（而非 HTTP 404），统一容错处理。
  Future<Result<void>> deleteSession({required String sessionId}) =>
      guardResult(() async {
        try {
          final data = await _client.post<Map<String, dynamic>>(
            _url(ApiEndpoints.aiConsultSessionDelete),
            data: {'session_id': sessionId},
          );
          // code!=0 说明 session 已不存在（报告生成后自动清理），视为成功
          final code = (data['code'] as int?) ?? 0;
          if (code != 0) return;
        } on ApiException {
          return; // cleanup 不能阻塞退出，吞掉所有错误
        }
      });

  // ── 6. 查询宠物历史会话列表（/session/by-pet）──────────
  /// 返回按 created_at 降序的摘要列表，pet_id 无记录时返回空数组
  Future<Result<List<ConsultationSessionSummary>>> getSessionsByPet({
    required String petId,
  }) =>
      guardResult(() async {
        final data = await _client.post<Map<String, dynamic>>(
          _url(ApiEndpoints.aiConsultSessionByPet),
          data: {'pet_id': petId},
        );
        final info = _unwrap(data);
        final sessions = (info['sessions'] as List?) ?? const [];
        return sessions
            .whereType<Map>()
            .map((e) => ConsultationSessionSummary.fromJson(
                  e.cast<String, dynamic>(),
                ))
            .toList();
      });

  // ── 7. 查询会话聊天记录（/session/messages）─────────────
  /// 返回完整历史会话（含 turns），session 不存在时抛 ApiException
  Future<Result<SessionHistory>> getSessionMessages({
    required String sessionId,
  }) =>
      guardResult(() async {
        final data = await _client.post<Map<String, dynamic>>(
          _url(ApiEndpoints.aiConsultSessionMessages),
          data: {'session_id': sessionId},
        );
        return SessionHistory.fromJson(_unwrap(data));
      });
  // ── 8. 保存/更新自动 AI 分析设置 ─────────────────────────
  Future<Result<AutoAnalysisSaveResult>> saveAutoAnalysisSetting({
    required String account,
    required String deviceNo,
    required String effectiveStartTime,
    required String effectiveEndTime,
    required List<int> repeatWeekdays,
    required int dailyAnalysisCount,
    bool enabled = true,
  }) =>
      guardResult(() async {
        final data = await _client.post<Map<String, dynamic>>(
          _url(ApiEndpoints.autoAnalysisSave),
          data: {
            'account': account,
            'device_no': deviceNo,
            'effective_start_time': effectiveStartTime,
            'effective_end_time': effectiveEndTime,
            'repeat_weekdays': repeatWeekdays,
            'daily_analysis_count': dailyAnalysisCount,
            'enabled': enabled,
          },
        );
        return AutoAnalysisSaveResult.fromJson(_unwrap(data));
      });

  // ── 9. 启用或禁用自动 AI 分析设置 ────────────────────────
  Future<Result<bool>> toggleAutoAnalysisSetting({
    required String account,
    required String deviceNo,
    required bool enabled,
  }) =>
      guardResult(() async {
        final data = await _client.post<Map<String, dynamic>>(
          _url(ApiEndpoints.autoAnalysisToggle),
          data: {
            'account': account,
            'device_no': deviceNo,
            'enabled': enabled,
          },
        );
        final info = _unwrap(data);
        return info['enabled'] as bool? ?? enabled;
      });

  // ── 10. 查询任务列表（setting + tasks[]）─────────────────
  Future<Result<AutoAnalysisTasksResult>> getAutoAnalysisTasks({
    required String account,
    required String deviceNo,
  }) =>
      guardResult(() async {
        final data = await _client.post<Map<String, dynamic>>(
          _url(ApiEndpoints.autoAnalysisTasks),
          data: {'account': account, 'device_no': deviceNo},
        );
        return AutoAnalysisTasksResult.fromJson(_unwrap(data));
      });
}

// ── Riverpod Provider ─────────────────────────────────────
final consultationRepositoryProvider = Provider<ConsultationRepository>((ref) {
  return ConsultationRepository(ref.read(apiClientProvider));
});
