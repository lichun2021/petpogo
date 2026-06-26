import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

/// 统一选图工具（不含裁剪）
/// 头像在 UI 层通过 ClipOval 圆形显示，无需裁剪步骤
/// 原 ImageCropper 方案在 iOS Modal / Android 未注册 Activity 时会崩溃，已移除
class ImagePickHelper {
  ImagePickHelper._();

  /// 弹出来源选择（Alert Dialog，避免 BottomSheet 嵌套），选图后返回 [File]
  /// 用户取消或选图失败返回 null
  static Future<File?> pickAndCropAvatar(BuildContext context) async {
    // 1. 选择来源（Dialog，不是 BottomSheet，避免 Modal 嵌套崩溃）
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('选择图片来源',
            style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w700)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded),
            title: Text('拍照',
                style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: Text('从相册选择',
                style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (source == null) return null;

    // 2. 拍照或选相册（限 512×512，减少上传体积）
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return null;
    return File(picked.path);
  }
}
