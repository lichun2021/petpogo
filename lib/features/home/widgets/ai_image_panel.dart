import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/theme/app_colors.dart';

/// AI 宠物图像情绪识别面板
///
/// 功能：
///   拍照 / 相册选图 → 上传服务器 → 显示情绪结果
///
/// 当前状态：
///   UI 和拍照功能已完整，接口返回结果留空（TODO）
///
/// 状态流程：
///   idle → picking → previewing → analyzing → result / error
enum _Phase { idle, picking, previewing, analyzing, result, error }

class AiImagePanel extends StatefulWidget {
  const AiImagePanel({super.key});

  @override
  State<AiImagePanel> createState() => _AiImagePanelState();
}

class _AiImagePanelState extends State<AiImagePanel>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.idle;
  File? _imageFile;
  String? _errorMessage;
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
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,       // 适当压缩，减少上传体积
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (xfile == null) {
        // 用户取消
        setState(() => _phase = _Phase.idle);
        return;
      }
      setState(() {
        _imageFile = File(xfile.path);
        _phase = _Phase.previewing;
      });
      debugPrint('[AI图像] 拍照完成: ${xfile.path}');
    } catch (e) {
      debugPrint('[AI图像] 拍照失败: $e');
      setState(() {
        _phase = _Phase.error;
        _errorMessage = '拍照失败，请检查相机权限';
      });
    }
  }

  // ── 从相册选图 ─────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    HapticFeedback.lightImpact();
    setState(() => _phase = _Phase.picking);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (xfile == null) {
        setState(() => _phase = _Phase.idle);
        return;
      }
      setState(() {
        _imageFile = File(xfile.path);
        _phase = _Phase.previewing;
      });
      debugPrint('[AI图像] 选图完成: ${xfile.path}');
    } catch (e) {
      debugPrint('[AI图像] 选图失败: $e');
      setState(() {
        _phase = _Phase.error;
        _errorMessage = '选图失败，请重试';
      });
    }
  }

  // ── 上传分析 ───────────────────────────────────────────────
  Future<void> _analyze() async {
    if (_imageFile == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _phase = _Phase.analyzing);
    debugPrint('[AI图像] → 开始上传分析: ${_imageFile!.path}');

    // TODO: 调用图像情绪分析接口
    // final repo = ref.read(aiImageRepositoryProvider);
    // final result = await repo.analyze(_imageFile!);
    // result.when(
    //   success: (r) => setState(() { _result = r; _phase = _Phase.result; }),
    //   failure: (e) => setState(() { _errorMessage = e.userMessage; _phase = _Phase.error; }),
    // );

    // 暂时模拟 2 秒等待（接口就绪后删除）
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('[AI图像] ← 分析完成（结果待接入）');
    setState(() => _phase = _Phase.result);
  }

  // ── 重置 ────────────────────────────────────────────────────
  void _reset() {
    HapticFeedback.selectionClick();
    setState(() {
      _phase = _Phase.idle;
      _imageFile = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _buildContent(),
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

  // ── 待机界面 ──────────────────────────────────────────────
  Widget _buildIdle() {
    return Column(
      key: const ValueKey('idle'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.15),
                shape: BoxShape.circle),
            child: const Center(child: Text('📸', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AI 图像情绪识别',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                    fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            Text('拍照分析宠物当前情绪',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                    color: AppColors.onSurfaceVariant)),
          ]),
        ]),

        const SizedBox(height: 24),

        // 两个按钮：拍照 / 相册
        Row(children: [
          // 拍照按钮
          Expanded(
            child: GestureDetector(
              onTap: _pickFromCamera,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withOpacity(0.35),
                      blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
                  const SizedBox(height: 6),
                  const Text('拍照', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.95, 0.95)),
          ),

          const SizedBox(width: 12),

          // 相册按钮
          Expanded(
            child: GestureDetector(
              onTap: _pickFromGallery,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.outline.withOpacity(0.2)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 32),
                  const SizedBox(height: 6),
                  Text('相册', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ]),
              ),
            ).animate().fadeIn(delay: 180.ms).scale(begin: const Offset(0.95, 0.95)),
          ),
        ]),

        const SizedBox(height: 14),
        Text('支持猫咪 🐱 和狗狗 🐶 的图像情绪识别',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                color: AppColors.onSurfaceVariant.withOpacity(0.7))),
      ],
    );
  }

  // ── 选图中 ────────────────────────────────────────────────
  Widget _buildPicking() {
    return Column(
      key: const ValueKey('picking'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const CircularProgressIndicator(strokeWidth: 2.5),
        const SizedBox(height: 16),
        Text('打开相机中...', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 13, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── 预览 + 确认上传 ───────────────────────────────────────
  Widget _buildPreview() {
    return Column(
      key: const ValueKey('preview'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题行
        Row(children: [
          const Text('确认照片', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          const Spacer(),
          IconButton(
            onPressed: _reset,
            icon: Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant, size: 20),
            tooltip: '重新选择',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ]),
        const SizedBox(height: 12),

        // 图片预览
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _imageFile!,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96)),

        const SizedBox(height: 16),

        // 操作按钮
        Row(children: [
          // 重拍
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickFromCamera,
              icon: const Icon(Icons.camera_alt_rounded, size: 16),
              label: const Text('重拍'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurfaceVariant,
                side: BorderSide(color: AppColors.outline.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 开始分析
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _analyze,
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('开始分析'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ── 分析中 ────────────────────────────────────────────────
  Widget _buildAnalyzing() {
    return Column(
      key: const ValueKey('analyzing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),

        // 图片 + 扫描遮罩
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _imageFile!,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
            // 半透明扫描条动画
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AnimatedBuilder(
                  animation: _shimmerCtrl,
                  builder: (_, __) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [
                            (_shimmerCtrl.value - 0.2).clamp(0.0, 1.0),
                            _shimmerCtrl.value.clamp(0.0, 1.0),
                            (_shimmerCtrl.value + 0.2).clamp(0.0, 1.0),
                          ],
                          colors: [
                            Colors.black.withOpacity(0.3),
                            const Color(0xFFFF9800).withOpacity(0.5),
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // AI 分析中标签
            Positioned(
              bottom: 10, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: const Color(0xFFFF9800)),
                    ),
                    const SizedBox(width: 8),
                    const Text('AI 分析中...',
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),
        Text('正在识别宠物情绪，请稍候',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── 结果（暂时留空）─────────────────────────────────────────
  Widget _buildResult() {
    return Column(
      key: const ValueKey('result'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题行
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.15),
                shape: BoxShape.circle),
            child: const Center(child: Text('📸', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('分析完成', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
              Text('图像情绪识别结果', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11, color: AppColors.onSurfaceVariant)),
            ]),
          ),
          IconButton(
            onPressed: _reset,
            icon: Icon(Icons.refresh_rounded, color: AppColors.onSurfaceVariant),
            tooltip: '重新分析',
          ),
        ]),

        const SizedBox(height: 12),

        // 缩略图
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(_imageFile!, width: double.infinity,
              height: 120, fit: BoxFit.cover),
        ),

        const SizedBox(height: 16),

        // 结果占位（接口就绪后替换）
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.2)),
          ),
          child: Column(children: [
            Icon(Icons.hourglass_top_rounded,
                color: const Color(0xFFFF9800), size: 28),
            const SizedBox(height: 8),
            const Text('情绪识别结果', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            const SizedBox(height: 4),
            Text('接口对接中，敬请期待',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                    color: AppColors.onSurfaceVariant)),
          ]),
        ),
      ],
    );
  }

  // ── 错误 ──────────────────────────────────────────────────
  Widget _buildError() {
    return Column(
      key: const ValueKey('error'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
        const SizedBox(height: 12),
        Text(_errorMessage ?? '分析失败，请重试',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 13, color: AppColors.error)),
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
