import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../shared/theme/app_colors.dart';

enum TranslateState { idle, recording, analyzing, result }

/// AI 宠物翻译面板 — 设计稿 Image 1/2 还原
/// 样式：surface-container-low 背景卡片，primary 录音按钮（pill 形），
///       状态徽章：白色 60% 透明玻璃态
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
    'pet_type': '猫',
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
    // TODO: 上传录音 → 调用 pet-audio-translation API
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _state = TranslateState.result);
    });
  }

  void _reset() => setState(() => _state = TranslateState.idle);

  @override
  Widget build(BuildContext context) {
    return Container(
      // surface-container-low + 品牌阴影（无灰色）
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 40,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── 状态徽章（玻璃态）─────────────────────────
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'AI TRANSLATOR ACTIVE',
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

          // ── 主区域 ────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _buildContent(),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case TranslateState.idle:
        return _buildIdle();
      case TranslateState.recording:
        return _buildRecording();
      case TranslateState.analyzing:
        return _buildAnalyzing();
      case TranslateState.result:
        return _buildResult();
    }
  }

  // ── Idle: 大圆按钮 + 文字 + Hold to Record pill ───────
  Widget _buildIdle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 主图标圆
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'AI Pet Translator',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Point your phone towards your pet\nand record their sound.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // Hold to Record — primary pill 按钮
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(48),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGlow,
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Hold to Record',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPrimary,
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

  // ── Recording ─────────────────────────────────────────
  Widget _buildRecording() {
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
                    (i % 3 == 0
                        ? 28 * _waveController.value
                        : i % 2 == 0
                            ? 18 * (1 - _waveController.value)
                            : 20 * _waveController.value);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 4,
                  height: h,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '正在录音...',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '松开手指完成录制',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(48),
              ),
              child: const Text(
                '停止录音',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(),
    );
  }

  // ── Analyzing ─────────────────────────────────────────
  Widget _buildAnalyzing() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 16),
          Text(
            'AI 正在分析宠物声音...',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  // ── Result ────────────────────────────────────────────
  Widget _buildResult() {
    final emotions = _mockResult['emotions'] as List;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 翻译结果 — surfaceContainerLowest 卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💬 宠物说：',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _mockResult['translation'] as String,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ).animate().slideY(begin: 0.2),

          const SizedBox(height: 12),

          // 情绪标签
          Wrap(
            spacing: 8,
            children: emotions.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e['emoji'] as String, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '${e['name']} ${e['percent']}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ).animate().slideY(begin: 0.2, delay: 100.ms),

          const SizedBox(height: 12),

          // 建议
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
                  child: Text(
                    _mockResult['suggestion'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().slideY(begin: 0.2, delay: 200.ms),

          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _reset,
            icon: Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
            label: Text(
              '再次翻译',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
