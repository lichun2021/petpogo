/// ════════════════════════════════════════════════════════════
///  AI 分析 Controller
///
///  统一管理语音和图像两种 AI 分析的状态机：
///    idle → uploading → analyzing → result / error
///
///  新版流程：
///    文件 → OSS 上传 → 后端 /sdkapi/ai/[voice|image]-analyze
///    配额由后端控制，前端只展示结果和剩余次数
/// ════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../data/models/ai_result_model.dart';
import '../data/repository/ai_repository.dart';

// ── 状态枚举 ──────────────────────────────────────────────
enum AiPhase {
  idle,       // 待机
  uploading,  // 上传到 OSS
  analyzing,  // 后端 AI 分析中
  result,     // 显示结果
  error,      // 出错
}

// ── 状态类 ────────────────────────────────────────────────
class AiAnalyzeState {
  final AiPhase phase;
  final double uploadProgress;  // 0.0 ~ 1.0
  final AiAnalysisResult? result;
  final String? errorMessage;

  const AiAnalyzeState({
    this.phase          = AiPhase.idle,
    this.uploadProgress = 0.0,
    this.result,
    this.errorMessage,
  });

  AiAnalyzeState copyWith({
    AiPhase? phase,
    double? uploadProgress,
    AiAnalysisResult? result,
    String? errorMessage,
  }) => AiAnalyzeState(
    phase:          phase          ?? this.phase,
    uploadProgress: uploadProgress ?? this.uploadProgress,
    result:         result         ?? this.result,
    errorMessage:   errorMessage,
  );
}

// ── Controller ────────────────────────────────────────────
class AiAnalyzeController extends StateNotifier<AiAnalyzeState> {
  final AiRepository _repo;

  AiAnalyzeController(this._repo) : super(const AiAnalyzeState());

  // ── 语音分析（录音文件 → OSS → 后端）────────────────────
  Future<void> analyzeVoice(File audioFile, {String? petId}) async {
    state = const AiAnalyzeState(phase: AiPhase.uploading, uploadProgress: 0);
    try {
      final result = await _repo.uploadAndAnalyzeVoice(
        file: audioFile,
        petId: petId,
        onProgress: (stage, p) {
          if (stage == 'upload') {
            state = state.copyWith(
              phase: AiPhase.uploading,
              uploadProgress: p,
            );
          } else if (stage == 'analyzing') {
            state = state.copyWith(phase: AiPhase.analyzing, uploadProgress: 1.0);
          }
        },
      );
      state = AiAnalyzeState(phase: AiPhase.result, result: result, uploadProgress: 1.0);
      debugPrint('[AiCtrl] 语音分析完成: ${result.primaryEmotion.labelZh} '
          '(剩余配额: ${result.quota.remaining})');
    } catch (e) {
      state = AiAnalyzeState(
        phase: AiPhase.error,
        errorMessage: _parseError(e),
      );
      debugPrint('[AiCtrl] 语音分析失败: $e');
    }
  }

  // ── 图像分析（照片文件 → OSS → 后端）────────────────────
  Future<void> analyzeImage(File imageFile, {String? petId}) async {
    state = const AiAnalyzeState(phase: AiPhase.uploading, uploadProgress: 0);
    try {
      final result = await _repo.uploadAndAnalyzeImage(
        file: imageFile,
        petId: petId,
        onProgress: (stage, p) {
          if (stage == 'upload') {
            state = state.copyWith(
              phase: AiPhase.uploading,
              uploadProgress: p,
            );
          } else if (stage == 'analyzing') {
            state = state.copyWith(phase: AiPhase.analyzing, uploadProgress: 1.0);
          }
        },
      );
      state = AiAnalyzeState(phase: AiPhase.result, result: result, uploadProgress: 1.0);
      debugPrint('[AiCtrl] 图像分析完成: ${result.primaryEmotion.labelZh} '
          '(剩余配额: ${result.quota.remaining})');
    } catch (e) {
      state = AiAnalyzeState(
        phase: AiPhase.error,
        errorMessage: _parseError(e),
      );
      debugPrint('[AiCtrl] 图像分析失败: $e');
    }
  }

  // ── 重置 ─────────────────────────────────────────────────
  void reset() => state = const AiAnalyzeState();

  String _parseError(Object e) {
    // 优先使用 ApiException 的真实 message（后端返回的中文原因）
    if (e is ApiException) {
      if (e.statusCode == 429) return '今日 AI 次数已用完，升级 VIP 享无限次数';
      if (e.statusCode == 502) return 'AI 服务暂时不可用，请稍后重试';
      if (e.type == ApiErrorType.network)  return '网络连接失败，请检查网络';
      if (e.type == ApiErrorType.timeout)  return '请求超时，请稍后重试';
      // 其他（包括 422 非宠物）：直接显示后端 message
      if (e.message.isNotEmpty) return e.message;
    }
    return '分析失败，请重试';
  }
}

// ── Providers ─────────────────────────────────────────────
/// 语音分析 Controller（独立状态，与图像互不干扰）
final aiVoiceControllerProvider =
    StateNotifierProvider<AiAnalyzeController, AiAnalyzeState>((ref) {
  return AiAnalyzeController(ref.watch(aiRepositoryProvider));
});

/// 图像分析 Controller
final aiImageControllerProvider =
    StateNotifierProvider<AiAnalyzeController, AiAnalyzeState>((ref) {
  return AiAnalyzeController(ref.watch(aiRepositoryProvider));
});
