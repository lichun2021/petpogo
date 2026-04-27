import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/theme/app_colors.dart';
import '../data/models/ai_image_model.dart';
import '../data/repository/ai_image_repository.dart';

/// AI 宠物图像情绪识别面板
///
/// 接口：POST http://49.234.39.11:8002/dog/analyze
///   - 上传图片（JPEG / PNG）
///   - 返回 13 类情绪的 Top-3 结果 + 照顾建议
///
/// 状态流程：
///   idle → picking → previewing → analyzing → result / error
enum _Phase { idle, picking, previewing, analyzing, result, error }

class AiImagePanel extends ConsumerStatefulWidget {
  const AiImagePanel({super.key});

  @override
  ConsumerState<AiImagePanel> createState() => _AiImagePanelState();
}

class _AiImagePanelState extends ConsumerState<AiImagePanel>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.idle;
  File? _imageFile;
  String? _errorMessage;
  DogImageAnalysisResult? _result;
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── 拍照 ──────────────────────────────────────────────────
  Future<void> _pickFromCamera() async {
    HapticFeedback.lightImpact();
    setState(() => _phase = _Phase.picking);
    try {
      final xfile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (xfile == null) { setState(() => _phase = _Phase.idle); return; }
      setState(() { _imageFile = File(xfile.path); _phase = _Phase.previewing; });
      debugPrint('[AI图像] 拍照完成: ${xfile.path}');
    } catch (e) {
      debugPrint('[AI图像] 拍照失败: $e');
      setState(() { _phase = _Phase.error; _errorMessage = '拍照失败，请检查相机权限'; });
    }
  }

  // ── 相册选图 ───────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    HapticFeedback.lightImpact();
    setState(() => _phase = _Phase.picking);
    try {
      final xfile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (xfile == null) { setState(() => _phase = _Phase.idle); return; }
      setState(() { _imageFile = File(xfile.path); _phase = _Phase.previewing; });
      debugPrint('[AI图像] 选图完成: ${xfile.path}');
    } catch (e) {
      debugPrint('[AI图像] 选图失败: $e');
      setState(() { _phase = _Phase.error; _errorMessage = '选图失败，请重试'; });
    }
  }

  // ── 上传分析 ───────────────────────────────────────────────
  Future<void> _analyze() async {
    if (_imageFile == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _phase = _Phase.analyzing);

    final repo = ref.read(aiImageRepositoryProvider);
    final result = await repo.analyze(_imageFile!);

    result.when(
      success: (r) => setState(() { _result = r; _phase = _Phase.result; }),
      failure: (e) => setState(() { _errorMessage = e.message; _phase = _Phase.error; }),
    );
  }

  // ── 重置 ────────────────────────────────────────────────────
  void _reset() {
    HapticFeedback.selectionClick();
    setState(() {
      _phase = _Phase.idle;
      _imageFile = null;
      _errorMessage = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 24, spreadRadius: -6)],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_phase) {
      case _Phase.idle:       return _buildIdle();
      case _Phase.picking:    return _buildPicking();
      case _Phase.previewing: return _buildPreview();
      case _Phase.analyzing:  return _buildAnalyzing();
      case _Phase.result:     return _buildResult();
      case _Phase.error:      return _buildError();
    }
  }

  // ── 待机 ──────────────────────────────────────────────────
  Widget _buildIdle() {
    return Column(
      key: const ValueKey('idle'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // 渐变 Banner
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9800), Color(0xFFFF6D00)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            Container(width: 48, height: 48,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Center(child: Text('📸', style: TextStyle(fontSize: 24)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AI 图像情绪识别',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16,
                      fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text('拍一张照片，即刻读懂宠物心情',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                      color: Colors.white.withOpacity(0.85))),
            ])),
            Text('🐾', style: TextStyle(fontSize: 28, color: Colors.white.withOpacity(0.25))),
          ]),
        ).animate().fadeIn().slideY(begin: -0.05),

        const SizedBox(height: 14),

        // 两按钮
        Row(children: [
          Expanded(child: _ActionButton(onTap: _pickFromCamera,
              icon: Icons.camera_alt_rounded, label: '拍  照', sublabel: '立即拍摄',
              gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              shadowColor: const Color(0xFFFF9800), delay: 80)),
          const SizedBox(width: 10),
          Expanded(child: _ActionButton(onTap: _pickFromGallery,
              icon: Icons.photo_library_rounded, label: '相  册', sublabel: '从相册选择',
              gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              shadowColor: const Color(0xFF7C4DFF), delay: 160)),
        ]),

        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🐶', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text('目前支持狗狗图像分析',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                  color: AppColors.onSurfaceVariant.withOpacity(0.6))),
        ]),
      ],
    );
  }

  // ── 打开相机中 ─────────────────────────────────────────────
  Widget _buildPicking() {
    return Column(key: const ValueKey('picking'), mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 16),
      const CircularProgressIndicator(strokeWidth: 2.5),
      const SizedBox(height: 16),
      Text('打开相机中...', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
          fontSize: 13, color: AppColors.onSurfaceVariant)),
      const SizedBox(height: 16),
    ]);
  }

  // ── 图片预览 ───────────────────────────────────────────────
  Widget _buildPreview() {
    return Column(key: const ValueKey('preview'), mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Text('确认照片', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        const Spacer(),
        IconButton(onPressed: _reset,
            icon: Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
      ]),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(16),
          child: Image.file(_imageFile!, width: double.infinity, height: 200, fit: BoxFit.cover))
          .animate().fadeIn().scale(begin: const Offset(0.96, 0.96)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _pickFromCamera,
          icon: const Icon(Icons.camera_alt_rounded, size: 16),
          label: const Text('重拍'),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onSurfaceVariant,
              side: BorderSide(color: AppColors.outline.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: ElevatedButton.icon(
          onPressed: _analyze,
          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
          label: const Text('开始分析'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
      ]),
    ]);
  }

  // ── 分析中（扫描动画）────────────────────────────────────────
  Widget _buildAnalyzing() {
    return Column(key: const ValueKey('analyzing'), mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 8),
      Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(16),
            child: Image.file(_imageFile!, width: double.infinity, height: 160, fit: BoxFit.cover)),
        Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(16),
            child: AnimatedBuilder(animation: _shimmerCtrl, builder: (_, __) {
              return Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                stops: [(_shimmerCtrl.value - 0.2).clamp(0.0, 1.0),
                  _shimmerCtrl.value.clamp(0.0, 1.0),
                  (_shimmerCtrl.value + 0.2).clamp(0.0, 1.0)],
                colors: [Colors.black.withOpacity(0.3),
                  const Color(0xFFFF9800).withOpacity(0.5),
                  Colors.black.withOpacity(0.3)],
              )));
            }))),
        Positioned(bottom: 10, left: 0, right: 0, child: Center(
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: const Color(0xFFFF9800))),
                  const SizedBox(width: 8),
                  const Text('AI 分析中...', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ])))),
      ]),
      const SizedBox(height: 14),
      Text('正在识别狗狗情绪，请稍候',
          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.onSurfaceVariant)),
      const SizedBox(height: 8),
    ]);
  }

  // ── 结果展示 ──────────────────────────────────────────────
  Widget _buildResult() {
    final r = _result;
    if (r == null) { _reset(); return const SizedBox.shrink(); }

    final emotion = r.primaryEmotion;
    final emotionColor = Color(emotion.colorHex);

    return Column(key: const ValueKey('result'), mainAxisSize: MainAxisSize.min, children: [
      // 标题 + 刷新
      Row(children: [
        Container(width: 48, height: 48,
            decoration: BoxDecoration(color: emotionColor.withOpacity(0.12), shape: BoxShape.circle),
            child: Center(child: Text(emotion.emoji, style: const TextStyle(fontSize: 24)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(emotion.displayName, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: emotionColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(r.primaryPrediction.percentText,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                        fontWeight: FontWeight.w700, color: emotionColor))),
          ]),
          const SizedBox(height: 2),
          Text('狗狗图像情绪识别', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 11, color: AppColors.onSurfaceVariant)),
        ])),
        IconButton(onPressed: _reset,
            icon: Icon(Icons.refresh_rounded, color: AppColors.onSurfaceVariant),
            tooltip: '重新分析'),
      ]),

      const SizedBox(height: 12),

      // 缩略图
      ClipRRect(borderRadius: BorderRadius.circular(12),
          child: Image.file(_imageFile!, width: double.infinity, height: 110, fit: BoxFit.cover)),

      const SizedBox(height: 14),

      // 快速建议条
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: emotionColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: emotionColor.withOpacity(0.2))),
        child: Row(children: [
          Icon(Icons.lightbulb_rounded, size: 16, color: emotionColor),
          const SizedBox(width: 8),
          Expanded(child: Text(r.advice, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface))),
        ]),
      ),

      const SizedBox(height: 14),

      // Top-3 情绪柱状图
      Text('情绪分析', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
      const SizedBox(height: 8),
      ...r.top3.asMap().entries.map((entry) {
        final idx  = entry.key;
        final pred = entry.value;
        final emo  = DogEmotion.fromLabel(pred.label);
        final col  = Color(emo.colorHex);
        final isTop = idx == 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Text(emo.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            SizedBox(width: 48, child: Text(emo.displayName,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                    fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                    color: isTop ? AppColors.onSurface : AppColors.onSurfaceVariant))),
            const SizedBox(width: 8),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: pred.confidence,
                  backgroundColor: col.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(isTop ? col : col.withOpacity(0.5)),
                  minHeight: isTop ? 8 : 5,
                ))),
            const SizedBox(width: 8),
            SizedBox(width: 40, child: Text(pred.percentText, textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                    fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                    color: isTop ? col : AppColors.onSurfaceVariant))),
          ]),
        ).animate().fadeIn(delay: (idx * 80).ms).slideX(begin: 0.1);
      }),

      const SizedBox(height: 8),
      Row(children: [
        Icon(Icons.timer_outlined, size: 12, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text('${r.ensembleSize} 模型集成 · ${r.processingTimeMs.toStringAsFixed(0)}ms',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, color: AppColors.onSurfaceVariant)),
      ]),
    ]);
  }

  // ── 错误 ──────────────────────────────────────────────────
  Widget _buildError() {
    return Column(key: const ValueKey('error'), mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 8),
      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
      const SizedBox(height: 12),
      Text(_errorMessage ?? '分析失败，请重试', textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.error)),
      const SizedBox(height: 16),
      TextButton.icon(onPressed: _reset,
          icon: const Icon(Icons.refresh_rounded), label: const Text('重试')),
      const SizedBox(height: 8),
    ]);
  }
}

// ── 操作按钮组件 ───────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final String sublabel;
  final LinearGradient gradient;
  final Color shadowColor;
  final int delay;

  const _ActionButton({
    required this.onTap, required this.icon,
    required this.label, required this.sublabel,
    required this.gradient, required this.shadowColor, required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: shadowColor.withOpacity(0.35),
              blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(sublabel, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 10, color: Colors.white.withOpacity(0.8))),
        ]),
      ),
    ).animate().fadeIn(delay: delay.ms).scale(begin: const Offset(0.92, 0.92));
  }
}
