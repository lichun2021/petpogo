import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../controller/ai_controller.dart';
import '../data/models/ai_result_model.dart';

/// AI 宠物语音识别面板
///
/// 新版流程：
///   录音 → 上传 OSS → 调 /sdkapi/ai/voice-analyze → 显示结果
///   配额由后端控制，超限时显示 VIP 提示
class AiTranslatePanel extends ConsumerStatefulWidget {
  const AiTranslatePanel({super.key});

  @override
  ConsumerState<AiTranslatePanel> createState() => _AiTranslatePanelState();
}

class _AiTranslatePanelState extends ConsumerState<AiTranslatePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _recordPath;
  int _recordSecs = 0;
  late final _timer = Stream.periodic(const Duration(seconds: 1));

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── 开始录音 ─────────────────────────────────────────────
  Future<void> _startRecording() async {
    final ctrl = ref.read(aiVoiceControllerProvider);
    if (ctrl.phase != AiPhase.idle && ctrl.phase != AiPhase.error) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showSnack('请授权麦克风权限');
      return;
    }

    HapticFeedback.mediumImpact();
    final dir  = await getTemporaryDirectory();
    _recordPath = '${dir.path}/pet_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: _recordPath!,
    );

    setState(() {
      _isRecording = true;
      _recordSecs  = 0;
    });

    // 计时（简单自增）
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isRecording || !mounted) return false;
      setState(() => _recordSecs++);
      return true;
    });
  }

  // ── 停止录音 → 分析 ──────────────────────────────────────
  Future<void> _stopAndAnalyze() async {
    if (!_isRecording) return;
    HapticFeedback.lightImpact();

    final path = await _recorder.stop();
    setState(() => _isRecording = false);

    if (path == null) return;
    if (_recordSecs < 1) {
      _showSnack('录音时间太短，请至少录制 1 秒');
      return;
    }

    // 触发分析
    await ref.read(aiVoiceControllerProvider.notifier).analyzeVoice(
      File(path),
    );
  }

  void _reset() => ref.read(aiVoiceControllerProvider.notifier).reset();

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiVoiceControllerProvider);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 20, spreadRadius: -4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Row(children: [
            const Text('🎙️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            const Text('听懂宠物语言', style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 16,
              fontWeight: FontWeight.w800, color: AppColors.onSurface,
            )),
            const Spacer(),
            if (state.result != null)
              TextButton(
                onPressed: _reset,
                child: const Text('再试一次', style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                  color: AppColors.primary,
                )),
              ),
          ]),
          const SizedBox(height: 20),

          // 内容区
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (state.phase) {
              AiPhase.idle   => _IdleView(
                  key: const ValueKey('idle'),
                  isRecording: _isRecording,
                  recordSecs: _recordSecs,
                  onStart: _startRecording,
                  onStop:  _stopAndAnalyze,
                  pulseCtrl: _pulseCtrl,
                ),
              AiPhase.uploading  => _ProgressView(
                  key: const ValueKey('upload'),
                  label: '上传音频中…',
                  progress: state.uploadProgress,
                  icon: '☁️',
                ),
              AiPhase.analyzing  => const _SpinnerView(
                  key: ValueKey('analyze'),
                  label: 'AI 正在聆听中…',
                  icon: '🧠',
                ),
              AiPhase.result   => _ResultView(
                  key: const ValueKey('result'),
                  result: state.result!,
                ),
              AiPhase.error    => _ErrorView(
                  key: const ValueKey('error'),
                  message: state.errorMessage ?? '分析失败',
                  onRetry: _reset,
                ),
            },
          ),
        ],
      ),
    );
  }
}

// ── 待机：录音按钮 ────────────────────────────────────────
class _IdleView extends StatelessWidget {
  final bool isRecording;
  final int recordSecs;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final AnimationController pulseCtrl;

  const _IdleView({
    super.key,
    required this.isRecording,
    required this.recordSecs,
    required this.onStart,
    required this.onStop,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isRecording) ...[
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) => Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.15 + pulseCtrl.value * 0.15),
              ),
              child: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 36),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '录音中  ${recordSecs}s',
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('停止并分析'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ] else ...[
          const Text('按下按钮，对宠物录音', style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 13,
            color: AppColors.onSurfaceVariant,
          )),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onStart,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 16, spreadRadius: -2)],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 32),
            ),
          ),
        ],
      ],
    );
  }
}

// ── 上传进度 ──────────────────────────────────────────────
class _ProgressView extends StatelessWidget {
  final String label;
  final double progress;
  final String icon;
  const _ProgressView({super.key, required this.label, required this.progress, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 14,
          color: AppColors.onSurfaceVariant,
        )),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.surfaceContainerHighest,
            color: AppColors.primary,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text('${(progress * 100).toInt()}%', style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 11,
          color: AppColors.onSurfaceVariant,
        )),
      ],
    );
  }
}

// ── AI 分析中（spinner）─────────────────────────────────
class _SpinnerView extends StatelessWidget {
  final String label;
  final String icon;
  const _SpinnerView({super.key, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 40))
            .animate(onPlay: (c) => c.repeat())
            .rotate(duration: 3.seconds),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 14,
          color: AppColors.onSurfaceVariant,
        )),
        const SizedBox(height: 12),
        const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
      ],
    );
  }
}

// ── 结果展示 ──────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  final AiAnalysisResult result;
  const _ResultView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final emotion = result.primaryEmotion;
    final color   = Color(result.primaryColorHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主情绪
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Text(result.primaryEmoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emotion.labelZh, style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 18,
                  fontWeight: FontWeight.w800, color: color,
                )),
                Text('置信度 ${emotion.percentText}', style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                  color: color.withOpacity(0.7),
                )),
              ],
            )),
          ]),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),

        const SizedBox(height: 12),

        // Top-3
        if (result.top3.length > 1) ...[
          const Text('情绪分布', style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 12,
            fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant,
          )),
          const SizedBox(height: 8),
          ...result.top3.take(3).map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              SizedBox(
                width: 60,
                child: Text(e.labelZh, style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                  color: AppColors.onSurface,
                )),
              ),
              const SizedBox(width: 8),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: e.confidence,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  color: color,
                  minHeight: 6,
                ),
              )),
              const SizedBox(width: 8),
              Text(e.percentText, style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                color: AppColors.onSurfaceVariant,
              )),
            ]),
          )),
          const SizedBox(height: 8),
        ],

        // 建议
        if (result.advice.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(result.advice, style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                  color: AppColors.onSurface, height: 1.5,
                ))),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 配额剩余
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              result.quota.isUnlimited ? Icons.all_inclusive_rounded : Icons.bolt_rounded,
              size: 14, color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              result.quota.isUnlimited
                  ? 'VIP 无限次'
                  : '今日剩余 ${result.quota.remaining} 次',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 错误 ──────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('😓', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 13,
          color: AppColors.onSurfaceVariant,
        )),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('重试'),
        ),
      ],
    );
  }
}
