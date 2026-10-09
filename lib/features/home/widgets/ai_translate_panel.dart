import 'dart:io';
import 'dart:async';
import '../controller/hold_recording_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/ai_loading_views.dart';
import '../controller/ai_controller.dart';
import '../../profile/data/account_overview_provider.dart';
import '../data/models/ai_result_model.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

/// AI 宠物语音识别面板
///
/// 新版流程：
///   录音 → 上传 OSS → 调 /sdkapi/ai-proxy/voice/analyze → 显示结果
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
  late final HoldRecordingSession _recording;
  Timer? _recordTimer;
  int _recordSecs = 0;

  @override
  void initState() {
    super.initState();
    _recording = HoldRecordingSession(
      start: () async {
        if (!await _recorder.hasPermission()) {
          _showSnack('请授权麦克风权限');
          return false;
        }
        if (!mounted) return false;
        final dir = await getTemporaryDirectory();
        if (!mounted) return false;
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav),
            path:
                '${dir.path}/pet_voice_${DateTime.now().millisecondsSinceEpoch}.wav');
        return true;
      },
      stop: _recorder.stop,
      cancel: _recorder.cancel,
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseCtrl.dispose();
    unawaited(_recording
        .end(submit: false)
        .catchError((_) => null)
        .whenComplete(() => _recorder.dispose()));
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      await _recording.begin();
      if (!mounted || !_recording.isRecording) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _isRecording = true;
        _recordSecs = 0;
      });
      _pulseCtrl.repeat(reverse: true);
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isRecording) setState(() => _recordSecs++);
      });
    } catch (_) {
      _showSnack('无法开始录音，请重试');
    }
  }

  Future<void> _finishRecording({required bool submit}) async {
    _recordTimer?.cancel();
    final duration = _recordSecs;
    try {
      final path = await _recording.end(submit: submit && duration >= 1);
      if (!mounted) return;
      _pulseCtrl.stop();
      setState(() => _isRecording = false);
      if (!submit) return;
      if (duration < 1) {
        _showSnack('录音时间太短，请至少按住 1 秒');
        return;
      }
      if (path != null) {
        await ref
            .read(aiVoiceControllerProvider.notifier)
            .analyzeVoice(File(path));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isRecording = false);
        _showSnack('录音未完成，请重试');
      }
    }
  }

  void _reset() => ref.read(aiVoiceControllerProvider.notifier).reset();

  void _showSnack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: color ?? AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiVoiceControllerProvider);
    final voicePoints = ref.watch(aiPointsProvider).valueOrNull?['voice'];

    // 分析完成后弹 SnackBar 提示
    ref.listen(aiVoiceControllerProvider, (prev, next) {
      if (prev?.phase == AiPhase.analyzing &&
          (next.phase == AiPhase.result ||
              next.phase == AiPhase.notPet ||
              next.phase == AiPhase.error)) {
        ref.invalidate(pointsBalanceProvider);
      }
      if (prev?.phase == AiPhase.analyzing &&
          (next.phase == AiPhase.result || next.phase == AiPhase.notPet)) {
        final quota = next.result?.quota;
        if (quota != null) {
          _showSnack('分析完成 ✨', color: AppColors.primary);
        }
      }
    });
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 18,
            spreadRadius: -10,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.brandPrimarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                color: AppColors.brandPrimary,
                size: 19,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('听懂宠物的情绪',
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                        voicePoints == null ? '积分消耗加载中' : '$voicePoints 积分 / 次',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
            ),
            if (state.result != null || state.phase == AiPhase.notPet) ...[
              TextButton(
                onPressed: _reset,
                child: Text('再试一次',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 12,
                      color: AppColors.primary,
                    )),
              ),
            ],
          ]),
          SizedBox(height: 18),

          // 内容区（固定最小高度，防止切换阶段时外框跳动）
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: 190),
            child: Center(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                child: switch (state.phase) {
                  AiPhase.idle => _IdleView(
                      key: ValueKey('idle'),
                      isRecording: _isRecording,
                      recordSecs: _recordSecs,
                      onPressDown: _startRecording,
                      onPressUp: () => _finishRecording(submit: true),
                      onCancel: () => _finishRecording(submit: false),
                      pulseCtrl: _pulseCtrl,
                    ),
                  AiPhase.uploading => AiUploadProgressView(
                      key: ValueKey('upload'),
                      label: '上传音频中…',
                      progress: state.uploadProgress,
                      icon: '☁️',
                    ),
                  AiPhase.analyzing => const AiAnalyzingSpinnerView(
                      key: ValueKey('analyze'),
                      label: 'AI 正在聆听中…',
                    ),
                  AiPhase.result => _ResultView(
                      key: ValueKey('result'),
                      result: state.result!,
                    ),
                  AiPhase.notPet => _NotPetView(
                      key: ValueKey('notPet'),
                      reason: state.notPetReason ?? '未检测到宠物',
                      onRetry: _reset,
                    ),
                  AiPhase.error => AiErrorView(
                      key: ValueKey('error'),
                      message: state.errorMessage ?? '分析失败',
                      onRetry: _reset,
                    ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 录音按钮（按住说话）────────────────────────────────────────────────
class _IdleView extends StatelessWidget {
  final bool isRecording;
  final int recordSecs;
  final Future<void> Function() onPressDown;
  final Future<void> Function() onPressUp;
  final Future<void> Function() onCancel;
  final AnimationController pulseCtrl;

  const _IdleView({
    super.key,
    required this.isRecording,
    required this.recordSecs,
    required this.onPressDown,
    required this.onPressUp,
    required this.onCancel,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isRecording ? '松开完成录音' : '按住对宠物录音',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 13,
            color: isRecording ? AppColors.primary : AppColors.onSurfaceVariant,
            fontWeight: isRecording ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        SizedBox(height: 20),
        GestureDetector(
          onLongPressStart: (_) => onPressDown(),
          onLongPressEnd: (_) => onPressUp(),
          onLongPressCancel: () => onCancel(),
          onLongPressMoveUpdate: (details) {
            if (details.localOffsetFromOrigin.distance > 80) onCancel();
          },
          child: AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) {
              final scale = isRecording ? (1.0 + pulseCtrl.value * 0.12) : 1.0;
              final glow = isRecording ? pulseCtrl.value * 0.4 : 0.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35 + glow),
                        blurRadius: 20 + glow * 20,
                        spreadRadius: -2 + glow * 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 12),
        if (isRecording)
          Text(
            '录音中  ${recordSecs}s',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Text(
            '按住录音，滑开取消',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
            ),
          ),
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
    final color = Color(result.primaryColorHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主情绪
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Text(result.primaryEmoji, style: TextStyle(fontSize: 36)),
            SizedBox(width: 14),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emotion.labelZh,
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                    )),
                Text('置信度 ${emotion.percentText}',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 12,
                      color: color.withValues(alpha: 0.7),
                    )),
              ],
            )),
          ]),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),

        SizedBox(height: 12),

        // Top-3
        if (result.top3.length > 1) ...[
          Text('情绪分布',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              )),
          SizedBox(height: 8),
          ...result.top3.take(3).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  SizedBox(
                    width: 60,
                    child: Text(e.labelZh,
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 12,
                          color: AppColors.onSurface,
                        )),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                      child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: e.confidence,
                      backgroundColor: AppColors.surfaceContainerHighest,
                      color: color,
                      minHeight: 6,
                    ),
                  )),
                  SizedBox(width: 8),
                  Text(e.percentText,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      )),
                ]),
              )),
          SizedBox(height: 8),
        ],

        // 建议
        if (result.advice.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💡', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Expanded(
                    child: Text(result.advice,
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 12,
                          color: AppColors.onSurface,
                          height: 1.5,
                        ))),
              ],
            ),
          ),
          SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ── 非宠物提示 ────────────────────────────────────────────────
class _NotPetView extends StatelessWidget {
  final String reason;
  final VoidCallback onRetry;
  const _NotPetView({super.key, required this.reason, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('🤔', style: TextStyle(fontSize: 40)),
        SizedBox(height: 12),
        Text(reason,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 14,
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            )),
        SizedBox(height: 6),
        Text(
          '请对着宠物录音再试试',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: Icon(Icons.refresh_rounded, size: 16),
          label: Text('重新录音'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
