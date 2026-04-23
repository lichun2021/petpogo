/// ════════════════════════════════════════════════════════════
///  AI 语音翻译 Controller
///
///  状态机流程：
///    idle → recording（按住录音）→ analyzing（上传分析）→ result（显示结果）
///    任何状态 → idle（点击重置 / 出错）
///
///  依赖：
///    - record 包：录音并保存为 WAV 文件
///    - AiVoiceRepository：上传音频到 /analyze 接口
/// ════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/ai_analysis_model.dart';
import '../data/repository/ai_voice_repository.dart';

// ── 状态枚举 ──────────────────────────────────────────────
enum AiTranslatePhase {
  idle,       // 待机：显示"按住说话"按钮
  recording,  // 录音中：显示波形动画 + 计时
  analyzing,  // 分析中：显示上传 / AI 处理动画
  result,     // 结果：显示物种 + 情绪 + 建议
  error,      // 出错：显示错误提示
}

// ── 状态类 ────────────────────────────────────────────────
class AiTranslateState {
  final AiTranslatePhase phase;
  final AiAnalysisResult? result;
  final String? errorMessage;
  final int recordingSeconds;

  /// 录音文件路径（分析完成后保留，供用户回放验证）
  final String? recordingPath;

  const AiTranslateState({
    this.phase = AiTranslatePhase.idle,
    this.result,
    this.errorMessage,
    this.recordingSeconds = 0,
    this.recordingPath,
  });

  AiTranslateState copyWith({
    AiTranslatePhase? phase,
    AiAnalysisResult? result,
    String? errorMessage,
    int? recordingSeconds,
    String? recordingPath,
  }) =>
      AiTranslateState(
        phase:            phase ?? this.phase,
        result:           result ?? this.result,
        errorMessage:     errorMessage,
        recordingSeconds: recordingSeconds ?? this.recordingSeconds,
        recordingPath:    recordingPath ?? this.recordingPath,
      );
}

// ── Controller ────────────────────────────────────────────
class AiTranslateController extends StateNotifier<AiTranslateState> {
  final AiVoiceRepository _repo;

  /// record 包的录音实例
  final AudioRecorder _recorder = AudioRecorder();

  /// 录音文件存储路径
  String? _recordingPath;

  AiTranslateController(this._repo) : super(const AiTranslateState());

  // ── 开始录音 ──────────────────────────────────────────
  /// 调用时机：用户按下录音按钮
  ///
  /// 权限检查、录音文件路径生成、启动 AudioRecorder 都在这里
  Future<void> startRecording() async {
    debugPrint('[AiCtrl] startRecording() called');

    // 检查麦克风权限
    final hasPermission = await _recorder.hasPermission();
    debugPrint('[AiCtrl] hasPermission=$hasPermission');
    if (!hasPermission) {
      state = state.copyWith(
        phase: AiTranslatePhase.error,
        errorMessage: '请在设置中允许麦克风权限',
      );
      return;
    }

    // 生成录音临时文件路径（WAV 格式，AI 接口支持）
    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/pet_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 128000,
      ),
      path: _recordingPath!,
    );
    debugPrint('[AiCtrl] 录音已开始，文件路径: $_recordingPath');

    state = state.copyWith(
      phase: AiTranslatePhase.recording,
      recordingSeconds: 0,
    );
  }

  /// 录音计时器：每秒由 UI 层调用一次（用 Timer 驱动）
  void tickRecordingTime() {
    if (state.phase != AiTranslatePhase.recording) return;
    final secs = state.recordingSeconds + 1;
    // 超过 10 秒自动停止（AI 接口建议 1-10 秒）
    if (secs >= 10) {
      stopAndAnalyze();
    } else {
      state = state.copyWith(recordingSeconds: secs);
    }
  }

  // ── 停止录音 + 上传分析 ───────────────────────────────
  /// 调用时机：用户松开录音按钮（或录音超过 10 秒）
  Future<void> stopAndAnalyze() async {
    debugPrint('[AiCtrl] stopAndAnalyze() called, phase=${state.phase}');
    if (state.phase != AiTranslatePhase.recording) return;

    // 停止录音，获取文件路径
    final path = await _recorder.stop();
    if (path == null) {
      state = state.copyWith(
        phase: AiTranslatePhase.error,
        errorMessage: '录音失败，请重试',
      );
      return;
    }

    // 切换到"分析中"状态
    state = state.copyWith(phase: AiTranslatePhase.analyzing);

    // 上传到 AI 服务器分析
    final file = File(path);
    final result = await _repo.analyze(file);

    result.when(
      success: (data) {
        // 成功：保留录音文件供用户回放验证准确性（不再删除）
        debugPrint('[AiCtrl] 分析成功，保留录音文件: $path');
        state = state.copyWith(
          phase: AiTranslatePhase.result,
          result: data,
          recordingPath: path, // 保留路径，供 UI 回放
        );
      },
      failure: (err) {
        state = state.copyWith(
          phase: AiTranslatePhase.error,
          errorMessage: err.userMessage,
        );
      },
    );
  }

  // ── 重置 ──────────────────────────────────────────────
  /// 回到初始状态（用户点击"重新录音"或关闭结果面板）
  Future<void> reset() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    // 重置时清理保留的录音文件
    if (state.recordingPath != null) {
      final f = File(state.recordingPath!);
      if (f.existsSync()) f.deleteSync();
    }
    state = const AiTranslateState();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────
final aiTranslateControllerProvider =
    StateNotifierProvider<AiTranslateController, AiTranslateState>((ref) {
  return AiTranslateController(ref.read(aiVoiceRepositoryProvider));
});
