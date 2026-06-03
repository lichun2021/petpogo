import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/pet_toast.dart';
import '../controller/feed_controller.dart';
import '../controller/publish_controller.dart';
import '../data/models/post_model.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';


class PublishPage extends ConsumerStatefulWidget {
  const PublishPage({super.key});

  @override
  ConsumerState<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends ConsumerState<PublishPage>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  final _textCtrl = TextEditingController();
  VideoPlayerController? _previewVideoCtrl;
  late AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabAnim.forward();
    // 监听文字变化，实时更新发布按钮激活状态
    _textCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _previewVideoCtrl?.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  // ── 显示媒体选择底部弹窗 ─────────────────────────────────
  void _showMediaPicker() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MediaPickerSheet(
        onPickImages: _pickImages,
        onCamera: _pickCamera,
        onPickVideo: _pickVideo,
      ),
    );
  }

  // ── 相册选图片（最多9张）────────────────────────────────
  Future<void> _pickImages() async {
    Navigator.of(context).pop();
    HapticFeedback.mediumImpact();
    final picked = await _picker.pickMultiImage(imageQuality: 85, limit: 9);
    if (picked.isEmpty) return;
    ref.read(publishControllerProvider.notifier).setImages(
      picked.map((x) => File(x.path)).toList(),
    );
  }

  // ── 拍照（检查摄像头权限）────────────────────────────────
  Future<void> _pickCamera() async {
    Navigator.of(context).pop();
    HapticFeedback.mediumImpact();
    // 检查摄像头权限
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      if (status.isDenied || status.isRestricted) {
        status = await Permission.camera.request();
      }
      if (!status.isGranted) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.no_photography_rounded, color: Color(0xFFFF6B6B)),
              SizedBox(width: 8),
              Flexible(child: Text('需要相机权限',
                style: TextStyle(fontFamily: AppFonts.primary,
                    fontSize: 17, fontWeight: FontWeight.w700))),
            ]),
            content: const Text(
              '拍照或视频通话需要使用相机。\n请在「设置 → PetPogo」中开启相机权限。',
              style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 14, height: 1.6),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('取消',
                  style: TextStyle(color: AppColors.onSurfaceVariant)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('去设置',
                  style: TextStyle(color: Colors.white,
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
        return;
      }
    }
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (picked == null) return;
    final existing = ref.read(publishControllerProvider).selectedImages;
    ref.read(publishControllerProvider.notifier).setImages(
      [...existing, File(picked.path)],
    );
  }

  // ── 选视频 ───────────────────────────────────────────────
  Future<void> _pickVideo() async {
    Navigator.of(context).pop();
    HapticFeedback.mediumImpact();
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked == null) return;
    final file = File(picked.path);
    ref.read(publishControllerProvider.notifier).setVideo(file);
    _previewVideoCtrl?.dispose();
    _previewVideoCtrl = VideoPlayerController.file(file);
    await _previewVideoCtrl!.initialize();
    await _previewVideoCtrl!.setLooping(true);
    await _previewVideoCtrl!.play();
    if (mounted) setState(() {});
  }

  // ── 发布 ─────────────────────────────────────────────────
  Future<void> _publish() async {
    final text = _textCtrl.text.trim();
    final pub = ref.read(publishControllerProvider);
    final hasMedia = pub.selectedMediaType.hasMedia;

    // 媒体和文字都必填
    if (!hasMedia) {
      _showToast('请添加图片或视频', isError: true);
      return;
    }
    if (text.isEmpty) {
      _showToast('请输入文字内容', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    final newPost =
        await ref.read(publishControllerProvider.notifier).publish(content: text);
    if (!mounted) return;
    final state = ref.read(publishControllerProvider);
    if (state.isDone && newPost != null) {
      // 刷新列表（而非 prependPost）防止本地插入 + API 返回导致重复
      ref.read(feedControllerProvider.notifier).refresh();
      Navigator.of(context).pop(true);
      _showToast('发布成功 🎉');
    } else if (state.isError) {
      _showToast(state.errorMessage ?? '发布失败', isError: true);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (isError) {
      PetToast.error(context, msg);
    } else {
      PetToast.success(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pub = ref.watch(publishControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // ── 渐变顶栏 ────────────────────────────────────
          _GradientHeader(
            isBusy: pub.isBusy,
            onClose: () {
              // 关闭前先收起键盘并清除焦点，避免 TextField counter overlay 残留在社区页
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop();
            },
            onPublish: _publish,
            canPublish: pub.selectedMediaType.hasMedia && _textCtrl.text.trim().isNotEmpty,
          ),

          // ── 上传进度条 ───────────────────────────────────
          if (pub.isUploading)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pub.uploadProgress ?? 0),
              duration: const Duration(milliseconds: 300),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 3,
                backgroundColor: AppColors.surfaceContainerLow,
                valueColor: AlwaysStoppedAnimation(AppColors.primaryContainer),
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 文本输入卡片 ─────────────────────────
                  _TextCard(controller: _textCtrl),

                  const SizedBox(height: 20),

                  // ── 图片预览 ─────────────────────────────
                  if (pub.selectedMediaType == MediaType.image &&
                      pub.selectedImages.isNotEmpty) ...[
                    _ImagePreviewGrid(
                      images: pub.selectedImages,
                      onRemove: (i) {
                        final list = [...pub.selectedImages]..removeAt(i);
                        if (list.isEmpty) {
                          ref.read(publishControllerProvider.notifier).clearMedia();
                        } else {
                          ref.read(publishControllerProvider.notifier).setImages(list);
                        }
                      },
                      onAddMore: pub.selectedImages.length < 9 ? _showMediaPicker : null, // ignore: dead_null_aware_expression
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── 视频预览 ─────────────────────────────
                  if (pub.selectedMediaType == MediaType.video &&
                      _previewVideoCtrl != null &&
                      _previewVideoCtrl!.value.isInitialized) ...[
                    _VideoPreviewCard(
                      controller: _previewVideoCtrl!,
                      onRemove: () {
                        _previewVideoCtrl?.dispose();
                        _previewVideoCtrl = null;
                        ref.read(publishControllerProvider.notifier).clearMedia();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── 视频提示 ─────────────────────────────
                  if (pub.selectedMediaType == MediaType.video)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text('视频发布后将进行转码，完成后自动显示',
                            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                        ),
                      ]),
                    ),

                  // ── 添加媒体按钮（无媒体时显示） ──────────
                  if (!pub.selectedMediaType.hasMedia) ...[
                    const SizedBox(height: 8),
                    _AddMediaCard(onTap: _showMediaPicker),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on MediaType {
  bool get hasMedia => this != MediaType.none;
}

// ── 渐变顶栏 ───────────────────────────────────────────────────
class _GradientHeader extends StatelessWidget {
  final bool isBusy;
  final bool canPublish;
  final VoidCallback onClose;
  final VoidCallback onPublish;
  const _GradientHeader({
    required this.isBusy,
    required this.canPublish,
    required this.onClose,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: top),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFa83206), Color(0xFFff784e)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [BoxShadow(color: Color(0x40a83206), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: isBusy ? null : onClose,
          ),
          const Expanded(
            child: Text('发布动态',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.primary, fontSize: 17,
                fontWeight: FontWeight.w700, color: Colors.white,
              )),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: isBusy
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : GestureDetector(
                    onTap: canPublish ? onPublish : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: canPublish ? Colors.white : Colors.white.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: canPublish
                            ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)]
                            : null,
                      ),
                      child: Text('发 布',
                        style: TextStyle(
                          fontFamily: AppFonts.primary, fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: canPublish ? const Color(0xFFa83206) : Colors.white.withOpacity(0.5),
                        )),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 文本输入卡片 ──────────────────────────────────────────────
class _TextCard extends StatelessWidget {
  final TextEditingController controller;
  const _TextCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14a83206), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: 6,
            minLines: 4,
            maxLength: 500,
            style: const TextStyle(
              fontFamily: AppFonts.primary, fontSize: 16, color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: '分享你的宠物日常… 🐾',
              hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withOpacity(0.5), fontSize: 15),
              filled: false,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.primaryContainer, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(18),
              counterText: '',  // 隐藏默认计数器，避免 iOS overlay 残影
            ),
          ),
        ],
      ),
    );
  }
}

// ── 添加媒体大卡片 ────────────────────────────────────────────
class _AddMediaCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMediaCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryContainer.withOpacity(0.4), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x0Ea83206), blurRadius: 12, offset: Offset(0, 3))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Color(0x40a83206), blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('添加图片 / 视频',
                  style: TextStyle(
                    fontFamily: AppFonts.primary, fontWeight: FontWeight.w700,
                    fontSize: 15, color: AppColors.primary,
                  )),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('必选',
                    style: TextStyle(fontFamily: AppFonts.primary, fontSize: 10,
                        fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('支持拍照、相册、视频',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}

// ── 图片预览网格（含加号格） ────────────────────────────────────
class _ImagePreviewGrid extends StatelessWidget {
  final List<File> images;
  final void Function(int) onRemove;
  final VoidCallback? onAddMore;
  const _ImagePreviewGrid({required this.images, required this.onRemove, this.onAddMore});

  @override
  Widget build(BuildContext context) {
    final showAdd = onAddMore != null;
    final count = images.length + (showAdd ? 1 : 0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (_, i) {
        if (showAdd && i == images.length) {
          return GestureDetector(
            onTap: onAddMore,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryContainer.withOpacity(0.4), width: 1.5),
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 32),
            ),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(images[i], fit: BoxFit.cover),
            ),
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () => onRemove(i),
                child: Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── 视频预览卡片 ───────────────────────────────────────────────
class _VideoPreviewCard extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onRemove;
  const _VideoPreviewCard({required this.controller, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x1Fa83206), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
          ),
          Positioned(
            top: 10, right: 10,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 30, height: 30,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 媒体选择底部弹窗 ───────────────────────────────────────────
class _MediaPickerSheet extends StatelessWidget {
  final VoidCallback onPickImages;
  final VoidCallback onCamera;
  final VoidCallback onPickVideo;
  const _MediaPickerSheet({
    required this.onPickImages,
    required this.onCamera,
    required this.onPickVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x30000000), blurRadius: 30, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('选择媒体',
            style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.onSurface)),
          const SizedBox(height: 20),
          Row(children: [
            _SheetOption(
              icon: Icons.camera_alt_rounded,
              label: '拍照',
              gradient: const LinearGradient(colors: [Color(0xFFa83206), Color(0xFFff784e)]),
              onTap: onCamera,
            ),
            const SizedBox(width: 14),
            _SheetOption(
              icon: Icons.photo_library_rounded,
              label: '相册图片',
              gradient: const LinearGradient(colors: [Color(0xFF006760), Color(0xFF7fe6db)]),
              onTap: onPickImages,
            ),
            const SizedBox(width: 14),
            _SheetOption(
              icon: Icons.videocam_rounded,
              label: '视频',
              gradient: const LinearGradient(colors: [Color(0xFF705900), Color(0xFFfdd34d)]),
              onTap: onPickVideo,
            ),
          ]),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('取消', textAlign: TextAlign.center,
                style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.onSurfaceVariant)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _SheetOption({required this.icon, required this.label, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: gradient.colors.first.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(
            fontFamily: AppFonts.primary, fontWeight: FontWeight.w600,
            fontSize: 13, color: AppColors.onSurface)),
        ]),
      ),
    );
  }
}
