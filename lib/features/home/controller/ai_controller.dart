/// ════════════════════════════════════════════════════════════
///  AI 分析 Controller
///
///  统一管理语音和图像两种 AI 分析的状态机：
///    idle → uploading → analyzing → result / notPet / error
///
///  分析完成后自动回写配额到 authControllerProvider
/// ════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/controller/auth_controller.dart';
import '../../auth/data/models/auth_model.dart';
import '../data/models/ai_result_model.dart';
import '../data/repository/ai_repository.dart';

// ── 状态枚举 ───────────────────────────────────────────────
enum AiPhase {
  idle,       // 待机
  uploading,  // 上传到 OSS
  analyzing,  // 后端 AI 分析中
  result,     // 显示情绪结果
  notPet,     // 识别到非宠物（success=false，配额已扣减）
  error,      // 网络/服务器错误
}

// ── 状态类 ───────────────────────────────────────────────
class AiAnalyzeState {
  final AiPhase phase;
  final double uploadProgress;
  final AiAnalysisResult? result;
  final String? errorMessage;
  final String? notPetReason;

  const AiAnalyzeState({
    this.phase          = AiPhase.idle,
    this.uploadProgress = 0.0,
    this.result,
    this.errorMessage,
    this.notPetReason,
  });

  AiAnalyzeState copyWith({
    AiPhase? phase,
    double? uploadProgress,
    AiAnalysisResult? result,
    String? errorMessage,
    String? notPetReason,
  }) => AiAnalyzeState(
    phase:          phase          ?? this.phase,
    uploadProgress: uploadProgress ?? this.uploadProgress,
    result:         result         ?? this.result,
    errorMessage:   errorMessage,
    notPetReason:   notPetReason,
  );
}

// ── Controller ────────────────────────────────────────────
class AiAnalyzeController extends StateNotifier<AiAnalyzeState> {
  final AiRepository _repo;
  final Ref _ref;

  AiAnalyzeController(this._repo, this._ref) : super(const AiAnalyzeState());

  // ── 分析完成后回写配额到 authControllerProvider ─────────
  void _syncQuota(AiQuotaInfo quotaInfo) {
    final quota = AiQuota(
      used:      quotaInfo.used,
      limit:     quotaInfo.limit,
      remaining: quotaInfo.remaining,
    );
    _ref.read(authControllerProvider.notifier).updateAiQuota(quota);
  }

  // ── 语音分析 ────────────────────────────────────────────────
  Future<void> analyzeVoice(File audioFile, {String? petId}) async {
    state = const AiAnalyzeState(phase: AiPhase.uploading, uploadProgress: 0);
    try {
      final result = await _repo.uploadAndAnalyzeVoice(
        file: audioFile,
        petId: petId,
        onProgress: (stage, p) {
          if (stage == 'upload') {
            state = state.copyWith(phase: AiPhase.uploading, uploadProgress: p);
          } else if (stage == 'analyzing') {
            state = state.copyWith(phase: AiPhase.analyzing, uploadProgress: 1.0);
          }
        },
      );
      _syncQuota(result.quota);

      if (!result.success) {
        state = AiAnalyzeState(
          phase: AiPhase.notPet,
          notPetReason: result.reason ?? '无法识别该音频',
          result: result,
          uploadProgress: 1.0,
        );
        return;
      }
      state = AiAnalyzeState(phase: AiPhase.result, result: result, uploadProgress: 1.0);
      debugPrint('[AiCtrl] 语音分析完成: ${result.primaryEmotion.labelZh} (剩余: ${result.quota.remaining})');
    } catch (e) {
      state = AiAnalyzeState(phase: AiPhase.error, errorMessage: _parseError(e));
      debugPrint('[AiCtrl] 语音分析失败: $e');
    }
  }

  // ── 图像分析 ────────────────────────────────────────────────
  Future<void> analyzeImage(File imageFile, {String? petId}) async {
    state = const AiAnalyzeState(phase: AiPhase.uploading, uploadProgress: 0);
    try {
      final result = await _repo.uploadAndAnalyzeImage(
        file: imageFile,
        petId: petId,
        onProgress: (stage, p) {
          if (stage == 'upload') {
            state = state.copyWith(phase: AiPhase.uploading, uploadProgress: p);
          } else if (stage == 'analyzing') {
            state = state.copyWith(phase: AiPhase.analyzing, uploadProgress: 1.0);
          }
        },
      );
      _syncQuota(result.quota);

      if (!result.success) {
        state = AiAnalyzeState(
          phase: AiPhase.notPet,
          notPetReason: result.reason ?? '无法识别宠物',
          result: result,
          uploadProgress: 1.0,
        );
        return;
      }
      state = AiAnalyzeState(phase: AiPhase.result, result: result, uploadProgress: 1.0);
      debugPrint('[AiCtrl] 图像分析完成: ${result.primaryEmotion.labelZh} (剩余: ${result.quota.remaining})');
    } catch (e) {
      state = AiAnalyzeState(phase: AiPhase.error, errorMessage: _parseError(e));
      debugPrint('[AiCtrl] 图像分析失败: $e');
    }
  }

  void reset() => state = const AiAnalyzeState();

  String _parseError(Object e) {
    if (e is ApiException) {
      if (e.statusCode == 429) return '今日 AI 次数已用完，升级 VIP 享无限次数';
      if (e.statusCode == 502) return 'AI 服务暂时不可用，请稍后重试';
      if (e.type == ApiErrorType.network) return '网络连接失败，请检查网络';
      if (e.type == ApiErrorType.timeout) return '请求超时，请稍后重试';
      if (e.message.isNotEmpty) return e.message;
    }
    return '分析失败，请重试';
  }
}

// ── Providers ─────────────────────────────────────────────
final aiVoiceControllerProvider =
    StateNotifierProvider<AiAnalyzeController, AiAnalyzeState>((ref) {
  return AiAnalyzeController(ref.watch(aiRepositoryProvider), ref);
});

final aiImageControllerProvider =
    StateNotifierProvider<AiAnalyzeController, AiAnalyzeState>((ref) {
  return AiAnalyzeController(ref.watch(aiRepositoryProvider), ref);
});
