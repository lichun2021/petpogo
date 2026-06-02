import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/theme/app_colors.dart';
import '../controller/ai_controller.dart';
import '../data/models/ai_result_model.dart';

/// AI 宠物图像情绪识别面板
///
/// 新版流程：
///   拍照/相册 → 上传 OSS → 调 /sdkapi/ai/image-analyze → 显示结果
///   配额由后端控制
class AiImagePanel extends ConsumerStatefulWidget {
  const AiImagePanel({super.key});

  @override
  ConsumerState<AiImagePanel> createState() => _AiImagePanelState();
}

class _AiImagePanelState extends ConsumerState<AiImagePanel> {
  final ImagePicker _picker = ImagePicker();
  File? _previewFile;

  // ── 选图（相册 / 相机）────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.lightImpact();
    final xFile = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (xFile == null) return;
    setState(() => _previewFile = File(xFile.path));
  }

  // ── 弹出选图来源菜单 ──────────────────────────────────────────────────────────
  Future<void> _showPickSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text('选择照片来源', style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 15,
            fontWeight: FontWeight.w700, color: AppColors.onSurface,
          )),
          const SizedBox(height: 4),
          ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
            ),
            title: const Text('拍照', style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600,
            )),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
            ),
            title: const Text('从相册选择', style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600,
            )),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source != null) _pickImage(source);
  }

  // ── 开始分析 ──────────────────────────────────────────────
  Future<void> _startAnalysis() async {
    if (_previewFile == null) return;
    HapticFeedback.mediumImpact();
    await ref.read(aiImageControllerProvider.notifier).analyzeImage(_previewFile!);
  }

  // ── 重置 ──────────────────────────────────────────────────
  void _reset() {
    setState(() => _previewFile = null);
    ref.read(aiImageControllerProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiImageControllerProvider);

    // 分析完成后弹 SnackBar
    ref.listen(aiImageControllerProvider, (prev, next) {
      if (prev?.phase == AiPhase.analyzing &&
          (next.phase == AiPhase.result || next.phase == AiPhase.notPet)) {
        final quota = next.result?.quota;
        if (quota != null && mounted) {
          final msg = quota.isUnlimited
              ? '分析完成 • VIP 无限次数✨'
              : '分析完成 • 今日剩余 ${quota.remaining} 次';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            duration: const Duration(seconds: 3),
          ));
        }
      }
    });
    return Container(
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
            const Text('📸', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            const Text('读懂宠物表情', style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 16,
              fontWeight: FontWeight.w800, color: AppColors.onSurface,
            )),
            const Spacer(),
            if (state.phase == AiPhase.result ||
                state.phase == AiPhase.notPet ||
                state.phase == AiPhase.error)
              TextButton(
                onPressed: _reset,
                child: const Text('再拍一张', style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                  color: AppColors.primary,
                )),
              ),
          ]),
          const SizedBox(height: 20),

          // 内容区（固定最小高度，防止切换阶段时外框跳动）
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 220),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: switch (state.phase) {
                  AiPhase.idle      => _buildIdleView(),
                  AiPhase.uploading => _ProgressView(
                      key: const ValueKey('upload'),
                      label: '上传图片中…',
                      progress: state.uploadProgress,
                      icon: '☁️',
                    ),
                  AiPhase.analyzing => const _SpinnerView(
                      key: ValueKey('analyze'),
                      label: 'AI 正在分析表情…',
                      icon: '🔍',
                    ),
                  AiPhase.result    => _ResultView(
                      key: const ValueKey('result'),
                      result: state.result!,
                      previewFile: _previewFile,
                    ),
                  AiPhase.notPet    => _NotPetView(
                      key: const ValueKey('notPet'),
                      reason: state.notPetReason ?? '未检测到宠物',
                      quota: state.result?.quota,
                      onRetry: _reset,
                    ),
                  AiPhase.error     => _ErrorView(
                      key: const ValueKey('error'),
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

  Widget _buildIdleView() {
    return Column(
      key: const ValueKey('idle'),
      children: [
        // 预览图（缩小 + 边框）
        if (_previewFile != null) ...[
          Center(
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.file(
                  _previewFile!,
                  height: 220,
                  fit: BoxFit.fitHeight, // 高度固定，宽度按照片比例
                ),
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: _showPickSheet,
                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                label: const Text('换张图',
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                  side: BorderSide(color: AppColors.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startAnalysis,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('开始分析',
                    style: TextStyle(fontSize: 13),
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ] else ...[
          // 单个相机按钮，点击弹出来源菜单
          const Text('选择宠物照片，AI 读懂它的心情', style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 13,
            color: AppColors.onSurfaceVariant,
          )),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _showPickSheet,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 16, spreadRadius: -2,
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 10),
          const Text('点击拍照或从相册选择', style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 11,
            color: AppColors.onSurfaceVariant,
          )),
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
    return Column(children: [
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
    ]);
  }
}

// ── AI 分析中 ─────────────────────────────────────────────
class _SpinnerView extends StatelessWidget {
  final String label;
  final String icon;
  const _SpinnerView({super.key, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(icon, style: const TextStyle(fontSize: 40))
          .animate(onPlay: (c) => c.repeat())
          .rotate(duration: 2.seconds),
      const SizedBox(height: 12),
      Text(label, style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans', fontSize: 14,
        color: AppColors.onSurfaceVariant,
      )),
      const SizedBox(height: 12),
      const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
    ]);
  }
}

// ── 结果展示 ──────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  final AiAnalysisResult result;
  final File? previewFile;
  const _ResultView({super.key, required this.result, this.previewFile});

  @override
  Widget build(BuildContext context) {
    final emotion = result.primaryEmotion;
    final color   = Color(result.primaryColorHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 预览图缩略
        if (previewFile != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(previewFile!, height: 120, width: double.infinity, fit: BoxFit.cover),
          ),
        const SizedBox(height: 12),

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
        ).animate().fadeIn(duration: 400.ms),

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
        if (result.advice.isNotEmpty)
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

        // 配额
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
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
        ]),
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
    return Column(children: [
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
    ]);
  }
}

// ── 非宠物提示 ────────────────────────────────────────────────
class _NotPetView extends StatelessWidget {
  final String reason;
  final dynamic quota; // AiQuotaInfo?
  final VoidCallback onRetry;
  const _NotPetView({super.key, required this.reason, this.quota, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('🤔', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(reason, textAlign: TextAlign.center, style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 14,
          color: AppColors.onSurface,
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 6),
        Text('请换一张宠物的清晰照片再试试',
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 12,
            color: AppColors.onSurfaceVariant,
          )
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('重新选图'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

