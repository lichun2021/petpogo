import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../app.dart' show AppL10nX;

enum TranslateState { idle, recording, analyzing, result }

class AiTranslatePanel extends StatefulWidget {
  const AiTranslatePanel({super.key});

  @override
  State<AiTranslatePanel> createState() => _AiTranslatePanelState();
}

class _AiTranslatePanelState extends State<AiTranslatePanel>
    with SingleTickerProviderStateMixin {
  TranslateState _state = TranslateState.idle;
  late AnimationController _waveController;

  final _mockResult = {
    'translation': '主人快来抱我！我好想你了嘛～',
    'emotions': [
      {'name': '撒娇', 'percent': 78, 'emoji': '🥺'},
      {'name': '开心', 'percent': 45, 'emoji': '😊'},
      {'name': '困意', 'percent': 20, 'emoji': '😴'},
    ],
    'suggestion': '轻轻抚摸猫咪下巴，用温柔的声音回应它',
  };

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _startRecording() => setState(() => _state = TranslateState.recording);
  void _stopRecording() {
    setState(() => _state = TranslateState.analyzing);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _state = TranslateState.result);
    });
  }
  void _reset() => setState(() => _state = TranslateState.idle);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 40, spreadRadius: -5),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // 状态徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.aiTranslateBadge,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _buildContent(l10n),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildContent(dynamic l10n) {
    switch (_state) {
      case TranslateState.idle:      return _buildIdle(l10n);
      case TranslateState.recording: return _buildRecording(l10n);
      case TranslateState.analyzing: return _buildAnalyzing(l10n);
      case TranslateState.result:    return _buildResult(l10n);
    }
  }

  Widget _buildIdle(dynamic l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 32, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.aiTranslateTitle,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 22,
              fontWeight: FontWeight.w700, letterSpacing: -0.4,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.aiTranslateDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 14,
              color: AppColors.onSurfaceVariant, height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            child: Container(
              width: double.infinity, height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(48),
                boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    l10n.aiTranslateHoldRecord,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans', fontSize: 16,
                      fontWeight: FontWeight.w700, color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildRecording(dynamic l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (_, __) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(9, (i) {
                final h = 12.0 +
                    (i % 3 == 0 ? 28 * _waveController.value
                        : i % 2 == 0 ? 18 * (1 - _waveController.value)
                        : 20 * _waveController.value);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 4, height: h,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.aiTranslateRecording,
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(l10n.aiTranslateRelease,
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(48)),
              child: Text(l10n.aiTranslateStop,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildAnalyzing(dynamic l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text(l10n.aiTranslateAnalyzing,
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14)),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildResult(dynamic l10n) {
    final emotions = _mockResult['emotions'] as List;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 20, spreadRadius: -5)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.aiTranslatePetSays,
                    style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(_mockResult['translation'] as String,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
                        color: AppColors.onSurface, height: 1.5)),
              ],
            ),
          ).animate().slideY(begin: 0.2),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            children: emotions.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 8)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e['emoji'] as String, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text('${e['name']} ${e['percent']}%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                ],
              ),
            )).toList(),
          ).animate().slideY(begin: 0.2, delay: 100.ms),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_mockResult['suggestion'] as String,
                      style: TextStyle(fontSize: 13, color: AppColors.onSurface)),
                ),
              ],
            ),
          ).animate().slideY(begin: 0.2, delay: 200.ms),

          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _reset,
            icon: Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
            label: Text(l10n.aiTranslateAgain,
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
