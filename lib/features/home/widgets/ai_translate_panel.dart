import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import '../../../shared/theme/app_colors.dart';
import '../controller/ai_translate_controller.dart';
import '../data/models/ai_analysis_model.dart';

/// AI 宠物语音翻译面板
///
/// 接入真实 API：POST http://49.234.39.11:8002/analyze
/// 支持：猫 / 狗 两种物种，6 种情绪识别
///
/// 状态流程：
///   idle → recording（按住录音）→ analyzing（上传 AI）→ result（显示结果）
class AiTranslatePanel extends ConsumerStatefulWidget {
  const AiTranslatePanel({super.key});

  @override
  ConsumerState<AiTranslatePanel> createState() => _AiTranslatePanelState();
}

class _AiTranslatePanelState extends ConsumerState<AiTranslatePanel>
    with SingleTickerProviderStateMixin {
  Timer? _recordTimer;
  late AnimationController _pulseCtrl;

  /// just_audio 播放器（用于回放录音）
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // 监听播放状态变化，同步按钮图标
    _player.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── 开始录音 ────────────────────────────────────────────
  void _startRecording() {
    final phase = ref.read(aiTranslateControllerProvider).phase;
    debugPrint('[AI] _startRecording called, current phase=$phase');
    if (phase != AiTranslatePhase.idle) return; // 防止重复触发

    HapticFeedback.mediumImpact();
    ref.read(aiTranslateControllerProvider.notifier).startRecording();
    _pulseCtrl.repeat(reverse: true);

    // 每秒触发一次计时
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(aiTranslateControllerProvider.notifier).tickRecordingTime();
    });
  }

  // ── 停止录音 ────────────────────────────────────────────
  void _stopRecording() {
    final phase = ref.read(aiTranslateControllerProvider).phase;
    debugPrint('[AI] _stopRecording called, current phase=$phase');
    if (phase != AiTranslatePhase.recording) return; // 没在录音则忽略

    HapticFeedback.lightImpact();
    _recordTimer?.cancel();
    _pulseCtrl.stop();
    ref.read(aiTranslateControllerProvider.notifier).stopAndAnalyze();
  }

  // ── 重置 ────────────────────────────────────────────────
  void _reset() {
    _recordTimer?.cancel();
    _pulseCtrl.stop();
    ref.read(aiTranslateControllerProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiTranslateControllerProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 24, spreadRadius: -6),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _buildContent(state),
      ),
    );
  }

  Widget _buildContent(AiTranslateState state) {
    switch (state.phase) {
      case AiTranslatePhase.idle:
        return _buildIdle(state);
      case AiTranslatePhase.recording:
        return _buildRecording(state);
      case AiTranslatePhase.tooShort:
        return _buildTooShort();
      case AiTranslatePhase.analyzing:
        return _buildAnalyzing();
      case AiTranslatePhase.result:
        return _buildResult(state.result!);
      case AiTranslatePhase.error:
        return _buildError(state.errorMessage ?? '分析失败');
    }
  }

  // ── Phase 1: 待机 ────────────────────────────────────────
  Widget _buildIdle(AiTranslateState state) {
    return Column(
      key: const ValueKey('idle'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.25), shape: BoxShape.circle),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI 宠物语音翻译',
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                    fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            Text('支持猫咪 🐱 和狗狗 🐶',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.onSurfaceVariant)),
          ]),
        ]),
        const SizedBox(height: 20),

        // 录音按钮
        // 用 Listener（原始指针事件）替代 GestureDetector.onLongPress
        // 原因：onLongPress 需要等待 500ms 识别期，在 AnimatedBuilder 下
        // 手势竞技场可能拦截事件导致按钮失效。
        // Listener.onPointerDown/Up 是最底层事件，100% 可靠触发。
        Listener(
          onPointerDown: (_) {
            debugPrint('[AI] 按钮 onPointerDown → 开始录音');
            _startRecording();
          },
          onPointerUp: (_) {
            debugPrint('[AI] 按钮 onPointerUp → 停止录音');
            _stopRecording();
          },
          onPointerCancel: (_) {
            debugPrint('[AI] 按钮 onPointerCancel → 停止录音');
            _stopRecording();
          },
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) {
              // 录音时按钮轻微缩小（给用户"按下"的触觉反馈）
              return Transform.scale(
                scale: 1.0,
                child: child,
              );
            },
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 20, spreadRadius: -4)],
              ),
              child: const Center(child: Icon(Icons.mic_rounded, color: Colors.white, size: 36)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('按住麦克风开始录音',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text('建议录制 2~10 秒',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.onSurfaceVariant.withOpacity(0.6))),
      ],
    );
  }

  // ── Phase 2: 录音中 ──────────────────────────────────────
  Widget _buildRecording(AiTranslateState state) {
    return Column(
      key: const ValueKey('recording'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('录音中...', style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.error)),
        const SizedBox(height: 4),
        Text('${state.recordingSeconds}s / 10s',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),

        // 波形动画
        _WaveformWidget(controller: _pulseCtrl),

        const SizedBox(height: 16),

        // 录音进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: state.recordingSeconds / 10,
            backgroundColor: AppColors.surfaceContainerLow,
            color: AppColors.error,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 16),

        // 松开停止
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.errorContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.stop_rounded, color: AppColors.error, size: 18),
              SizedBox(width: 6),
              Text('停止录音', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error)),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Phase 3: 分析中 ─────────────────────────────────────
  Widget _buildAnalyzing() {
    return Column(
      key: const ValueKey('analyzing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          width: 60, height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.primary,
            backgroundColor: AppColors.primaryContainer.withOpacity(0.2),
          ),
        ),
        const SizedBox(height: 16),
        Text('AI 分析中...', style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        const SizedBox(height: 4),
        Text('正在识别物种和情绪，请稍候',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Phase 4: 分析结果 ────────────────────────────────────
  Widget _buildResult(AiAnalysisResult result) {
    // 物种未识别时：不显示情绪，只提示重录
    if (result.species == PetSpecies.unknown) {
      return _buildUnknownSpecies(result);
    }

    final state = ref.read(aiTranslateControllerProvider);
    final emotion = result.primaryEmotion;
    final emotionColor = Color(emotion.colorHex);

    return Column(
      key: const ValueKey('result'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 顶部：物种 + 主情绪 ─────────────────────────
        Row(children: [
          // 物种头像
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(result.species.emoji, style: const TextStyle(fontSize: 30))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(result.species.displayName, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${(result.speciesPrediction.confidence * 100).toStringAsFixed(0)}% 置信',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9,
                        fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ]),
            const SizedBox(height: 4),
            // 主情绪 badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: emotionColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: emotionColor.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(emotion.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text('${emotion.displayName} ${result.primaryEmotionPrediction.percentText}',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                        fontWeight: FontWeight.w700, color: emotionColor)),
              ]),
            ),
          ])),
          // 重新录音按钮
          IconButton(
            onPressed: _reset,
            icon: Icon(Icons.refresh_rounded, color: AppColors.onSurfaceVariant),
            tooltip: '重新录音',
          ),
        ]),

        const SizedBox(height: 16),

        // ── 快速建议提示条 ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: emotionColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: emotionColor.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(Icons.lightbulb_rounded, size: 16, color: emotionColor),
            const SizedBox(width: 8),
            Expanded(child: Text(emotion.quickTip,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                    fontWeight: FontWeight.w600, color: AppColors.onSurface))),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Top-3 情绪柱状图 ────────────────────────────
        Text('情绪分析', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
            fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        ...result.emotions.asMap().entries.map((e) {
          final idx   = e.key;
          final pred  = e.value;
          final emo   = PetEmotion.fromLabel(pred.label);
          final color = Color(emo.colorHex);
          return _EmotionBar(
            emoji: emo.emoji,
            label: emo.displayName,
            confidence: pred.confidence,
            color: color,
            isTop: idx == 0,
          ).animate().fadeIn(delay: (idx * 80).ms).slideX(begin: 0.1);
        }),

        const SizedBox(height: 16),

        // ── AI 照顾建议 ─────────────────────────────────
        Text('AI 建议', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
            fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(result.advice,
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                  color: AppColors.onSurface, height: 1.6)),
        ),

        const SizedBox(height: 12),

        // ── 时长标注 ────────────────────────────────────
        Row(children: [
          Icon(Icons.timer_outlined, size: 13, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text('音频 ${result.durationSeconds.toStringAsFixed(1)}s · 处理 ${result.processingTimeMs.toStringAsFixed(0)}ms',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.onSurfaceVariant)),
        ]),
      ],
    );
  }

  // ── Phase: 录音太短（< 2秒）提示 ────────────────────────────
  Widget _buildTooShort() {
    return Column(
      key: const ValueKey('tooShort'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(Icons.mic_rounded, color: AppColors.primary, size: 32),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('请按長一点👌',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                        fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 3),
                Text('至少需要 2 秒麦克风输入，AI 才能准确识别宠物声音',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                        color: AppColors.onSurfaceVariant)),
              ],
            )),
          ]),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ── 物种未识别结果卡片 ───────────────────────────────────
  /// 录音上传成功但模型无法识别物种时显示（不显示情绪）
  Widget _buildUnknownSpecies(AiAnalysisResult result) {
    final state = ref.read(aiTranslateControllerProvider);
    return Column(
      key: const ValueKey('unknownSpecies'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // 图标 + 标题
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🐾', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('未能识别物种', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
            const SizedBox(height: 3),
            Text('建议录制 3~5 秒清晰的叫声效果更好',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                    color: AppColors.onSurfaceVariant)),
          ])),
          IconButton(onPressed: _reset, icon: Icon(Icons.refresh_rounded,
              color: AppColors.onSurfaceVariant), tooltip: '重新录音'),
        ]),

        // 如有录音文件可回放
        if (state.recordingPath != null) ...[
          const SizedBox(height: 12),
          _PlaybackBar(audioPath: state.recordingPath!, player: _player,
              isPlaying: _isPlaying, duration: result.durationSeconds),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Phase 5: 出错 ────────────────────────────────────────
  Widget _buildError(String message) {
    return Column(
      key: const ValueKey('error'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                color: AppColors.error)),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── 情绪进度条组件 ────────────────────────────────────────
class _EmotionBar extends StatelessWidget {
  final String emoji, label;
  final double confidence;
  final Color color;
  final bool isTop;

  const _EmotionBar({
    required this.emoji, required this.label,
    required this.confidence, required this.color, required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        SizedBox(width: 44, child: Text(label,
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                color: isTop ? AppColors.onSurface : AppColors.onSurfaceVariant))),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: confidence,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(isTop ? color : color.withOpacity(0.5)),
              minHeight: isTop ? 8 : 5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 36, child: Text('${(confidence * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                color: isTop ? color : AppColors.onSurfaceVariant))),
      ]),
    );
  }
}

// ── 波形动画组件 ──────────────────────────────────────────
class _WaveformWidget extends StatelessWidget {
  final AnimationController controller;
  const _WaveformWidget({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(9, (i) {
            final phase = (i / 9 * 3.14) + controller.value * 3.14;
            final height = 12 + (16 * (0.5 + 0.5 * _sin(phase)));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.4 + 0.6 * controller.value),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }

  double _sin(double x) => x < 3.14 ? (x / 3.14) : ((6.28 - x) / 3.14);
}

// ── 回放录音条 ──────────────────────────────────────────────
/// 显示在结果页顶部，让用户回听录音验证 AI 识别是否准确
class _PlaybackBar extends StatelessWidget {
  final String audioPath;
  final AudioPlayer player;
  final bool isPlaying;
  final double duration;

  const _PlaybackBar({
    required this.audioPath,
    required this.player,
    required this.isPlaying,
    required this.duration,
  });

  Future<void> _toggle() async {
    if (isPlaying) {
      await player.pause();
    } else {
      // 每次重新加载（防止播放完后再按无效）
      await player.setFilePath(audioPath);
      await player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(children: [
        // 播放 / 暂停按钮
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white, size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('回放录音', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
              fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 2),
          Text('时长 ${duration.toStringAsFixed(1)}s · 验证识别准确性',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                  color: AppColors.onSurfaceVariant)),
        ])),
        // 播放中显示小波形
        if (isPlaying)
          Row(children: List.generate(4, (i) =>
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: 6.0 + (i % 2 == 0 ? 6.0 : 2.0),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.7),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          )),
      ]),
    );
  }
}
