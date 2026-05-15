import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// 统一选图 + 裁剪工具
/// 所有头像选取场景都走这个方法，保证裁剪体验一致
class ImagePickHelper {
  ImagePickHelper._();

  /// 弹出来源选择（相机/相册），选图后进入圆形裁剪页
  /// 返回裁剪后的 [File]，用户取消则返回 null
  static Future<File?> pickAndCropAvatar(BuildContext context) async {
    // 1. 选择来源
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SourceSheet(),
    );
    if (source == null) return null;

    // 2. 拍照或选相册
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return null;

    // 3. 裁剪（圆形区域，可拖动）
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '调整头像',
          toolbarColor: const Color(0xFF9e2f04),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFFe85d26),
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: '调整头像',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: CropStyle.circle,
        ),
      ],
    );
    if (cropped == null) return null;
    return File(cropped.path);
  }
}

// ── 来源选择 Sheet ────────────────────────────────────────
class _SourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(999))),
        ListTile(
          leading: const Icon(Icons.camera_alt_rounded),
          title: const Text('拍照',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600)),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_rounded),
          title: const Text('从相册选择',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600)),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}
