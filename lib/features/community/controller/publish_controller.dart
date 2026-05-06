import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/post_model.dart';
import '../data/post_repository.dart';

enum PublishStep { idle, uploading, submitting, done, error }

class PublishState {
  final PublishStep step;
  final double uploadProgress;  // 0.0 ~ 1.0
  final String? errorMessage;
  final String? resultPostId;
  final MediaType selectedMediaType;
  final List<File> selectedImages;
  final File? selectedVideo;

  const PublishState({
    this.step = PublishStep.idle,
    this.uploadProgress = 0,
    this.errorMessage,
    this.resultPostId,
    this.selectedMediaType = MediaType.none,
    this.selectedImages = const [],
    this.selectedVideo,
  });

  bool get isIdle      => step == PublishStep.idle;
  bool get isUploading => step == PublishStep.uploading;
  bool get isSubmitting=> step == PublishStep.submitting;
  bool get isDone      => step == PublishStep.done;
  bool get isError     => step == PublishStep.error;
  bool get isBusy      => isUploading || isSubmitting;

  PublishState copyWith({
    PublishStep? step,
    double? uploadProgress,
    String? errorMessage,
    String? resultPostId,
    MediaType? selectedMediaType,
    List<File>? selectedImages,
    File? selectedVideo,
  }) => PublishState(
    step:              step              ?? this.step,
    uploadProgress:    uploadProgress    ?? this.uploadProgress,
    errorMessage:      errorMessage,
    resultPostId:      resultPostId      ?? this.resultPostId,
    selectedMediaType: selectedMediaType ?? this.selectedMediaType,
    selectedImages:    selectedImages    ?? this.selectedImages,
    selectedVideo:     selectedVideo     ?? this.selectedVideo,
  );
}

class PublishController extends StateNotifier<PublishState> {
  final PostRepository _repo;
  PublishController(this._repo) : super(const PublishState());

  void setImages(List<File> files) {
    state = state.copyWith(
      selectedImages:    files,
      selectedMediaType: MediaType.image,
      selectedVideo:     null,
    );
  }

  void setVideo(File file) {
    state = state.copyWith(
      selectedVideo:     file,
      selectedMediaType: MediaType.video,
      selectedImages:    [],
    );
  }

  void clearMedia() {
    state = const PublishState();
  }

  Future<PostModel?> publish({required String content, String? location}) async {
    if (state.isBusy) return null;
    try {
      List<String> mediaUrls = [];
      String? videoUrl;
      String? coverUrl;
      String? rawVideoKey;

      // ── 图片上传 ──────────────────────────────────────
      if (state.selectedMediaType == MediaType.image && state.selectedImages.isNotEmpty) {
        state = state.copyWith(step: PublishStep.uploading, uploadProgress: 0);
        final total = state.selectedImages.length;
        for (int i = 0; i < total; i++) {
          final file = state.selectedImages[i];
          final sign = await _repo.getOssSign(fileType: 'image');
          await _repo.uploadToOss(
            uploadUrl:   sign.uploadUrl,
            file:        file,
            contentType: 'image/jpeg',
            onProgress: (p) {
              state = state.copyWith(uploadProgress: (i + p) / total);
            },
          );
          mediaUrls.add(sign.cdnUrl);
        }
      }

      // ── 视频上传 ──────────────────────────────────────
      else if (state.selectedMediaType == MediaType.video && state.selectedVideo != null) {
        state = state.copyWith(step: PublishStep.uploading, uploadProgress: 0);
        final sign = await _repo.getOssSign(fileType: 'video');
        await _repo.uploadToOss(
          uploadUrl:   sign.uploadUrl,
          file:        state.selectedVideo!,
          contentType: 'video/mp4',
          onProgress: (p) => state = state.copyWith(uploadProgress: p),
        );
        rawVideoKey = sign.key;
      }

      // ── 提交帖子 ─────────────────────────────────────
      state = state.copyWith(step: PublishStep.submitting, uploadProgress: 1);
      final res = await _repo.createPost(
        content:     content,
        mediaType:   state.selectedMediaType,
        mediaUrls:   mediaUrls.isNotEmpty ? mediaUrls : null,
        videoUrl:    videoUrl,
        coverUrl:    coverUrl,
        rawVideoKey: rawVideoKey,
        location:    location,
      );

      final postId = res['id'] as String? ?? '';
      debugPrint('[Publish] 发布成功 postId=$postId');
      state = state.copyWith(step: PublishStep.done, resultPostId: postId);

      // 构造本地帖子模型（供 Feed 顶部插入）
      return PostModel(
        id:           postId,
        content:      content,
        mediaType:    state.selectedMediaType,
        mediaUrls:    mediaUrls,
        videoUrl:     videoUrl,
        coverUrl:     coverUrl,
        likeCount:    0,
        commentCount: 0,
        viewCount:    0,
        createdAt:    DateTime.now(),
        userId:       '',
        nickname:     '我',
      );
    } catch (e) {
      debugPrint('[Publish] 失败: $e');
      state = state.copyWith(step: PublishStep.error, errorMessage: e.toString());
      return null;
    }
  }

  void reset() => state = const PublishState();
}

final publishControllerProvider =
    StateNotifierProvider.autoDispose<PublishController, PublishState>((ref) {
  return PublishController(ref.watch(postRepositoryProvider));
});
