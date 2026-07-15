import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class GalleryAccessDeniedException implements Exception {
  const GalleryAccessDeniedException();
}

/// 下载远程图片或视频并保存到系统相册。
Future<void> saveRemoteMediaToGallery({
  required String url,
  required bool isVideo,
  required String fileNamePrefix,
  String album = 'PetPogo',
}) async {
  final hasAccess = await Gal.hasAccess(toAlbum: true);
  if (!hasAccess) {
    final granted = await Gal.requestAccess(toAlbum: true);
    if (!granted) throw const GalleryAccessDeniedException();
  }

  File? temporaryFile;
  try {
    final directory = await getTemporaryDirectory();
    final extension = isVideo ? 'mp4' : 'jpg';
    temporaryFile = File(
      '${directory.path}/${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 2),
      ),
    ).download(url, temporaryFile.path);
    if (isVideo) {
      await Gal.putVideo(temporaryFile.path, album: album);
    } else {
      await Gal.putImage(temporaryFile.path, album: album);
    }
  } finally {
    if (temporaryFile != null && await temporaryFile.exists()) {
      await temporaryFile.delete();
    }
  }
}
