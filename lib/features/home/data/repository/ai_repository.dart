/// ════════════════════════════════════════════════════════════
///  AI Repository — 宠物语音 / 图像情绪分析
///
///  新版流程（三步）：
///    1. 调用方先上传文件到 OSS，拿到 publicUrl
///    2. 调用 analyzeVoice(audioUrl) 或 analyzeImage(imageUrl)
///    3. 后端检查配额 → 调 AI → 成功才扣次 → 存库 → 返回结果
///
///  不再直连 AI 服务器，所有 AI 调用均经过业务后端。
/// ════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../models/ai_result_model.dart';

class AiRepository {
  final ApiClient _client;
  AiRepository(this._client);

  // ── 步骤1：获取 OSS 预签名上传地址 ────────────────────────
  /// fileType: 'wav' | 'mp3' | 'jpg' | 'png' 等
  /// folder:   'ai-voice' | 'ai-image'（在 OSS 中的目录）
  Future<OssUploadToken> getUploadToken({
    required String fileType,
    required String folder,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/sdkapi/upload/sign',
      data: {'fileType': fileType, 'folder': folder},
    );
    return OssUploadToken.fromJson(res);
  }

  // ── 步骤2：直传 OSS（PUT，不经业务后端流量）─────────────
  Future<void> uploadToOss({
    required String uploadUrl,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    final dio = Dio();
    final bytes = await file.readAsBytes();
    debugPrint('[AI-OSS] 上传 ${bytes.length} bytes → $uploadUrl');
    try {
      await dio.put(
        uploadUrl,
        data: bytes,
        options: Options(
          // 不发 Content-Type，避免与预签名签名字符串不匹配 → 403
          headers: const <String, dynamic>{},
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
          validateStatus: (s) => s != null && s < 400,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
      debugPrint('[AI-OSS] 上传成功');
    } on DioException catch (e) {
      debugPrint('[AI-OSS] 上传失败 ${e.response?.statusCode}: ${e.response?.data}');
      rethrow;
    }
  }

  // ── 步骤3a：语音分析（传 OSS URL 给后端）────────────────
  /// [audioUrl] : OSS 公开访问 URL（从 getUploadToken 得到的 publicUrl）
  /// [petId]    : 可选，关联宠物 ID，便于历史记录
  Future<AiAnalysisResult> analyzeVoice({
    required String audioUrl,
    String? petId,
  }) async {
    debugPrint('[AI] 语音分析 → $audioUrl');
    final res = await _client.post<Map<String, dynamic>>(
      '/sdkapi/ai/voice-analyze',
      data: {
        'audioUrl': audioUrl,
        if (petId != null) 'petId': petId,
      },
    );
    return AiAnalysisResult.fromJson(res);
  }

  // ── 步骤3b：图像分析（传 OSS URL 给后端）────────────────
  /// [imageUrl] : OSS 公开访问 URL
  /// [petId]    : 可选，关联宠物 ID
  Future<AiAnalysisResult> analyzeImage({
    required String imageUrl,
    String? petId,
  }) async {
    debugPrint('[AI] 图像分析 → $imageUrl');
    final res = await _client.post<Map<String, dynamic>>(
      '/sdkapi/ai/image-analyze',
      data: {
        'imageUrl': imageUrl,
        if (petId != null) 'petId': petId,
      },
    );
    return AiAnalysisResult.fromJson(res);
  }

  // ── 便捷方法：一步完成上传 + 分析（语音）────────────────
  /// 适合直接从本地文件调用，内部完成 OSS 上传 + voice-analyze
  Future<AiAnalysisResult> uploadAndAnalyzeVoice({
    required File file,
    String? petId,
    void Function(String stage, double progress)? onProgress,
  }) async {
    // 1. 获取上传凭证
    onProgress?.call('upload', 0);
    final token = await getUploadToken(
      fileType: file.path.split('.').last.toLowerCase(),
      folder: 'ai-voice',
    );

    // 2. 上传到 OSS
    await uploadToOss(
      uploadUrl: token.uploadUrl,
      file: file,
      onProgress: (p) => onProgress?.call('upload', p * 0.8),
    );
    onProgress?.call('analyzing', 0.8);

    // 3. 调后端分析（配额由后端控制）
    final result = await analyzeVoice(
      audioUrl: token.publicUrl,
      petId: petId,
    );
    onProgress?.call('done', 1.0);
    return result;
  }

  // ── 便捷方法：一步完成上传 + 分析（图像）────────────────
  Future<AiAnalysisResult> uploadAndAnalyzeImage({
    required File file,
    String? petId,
    void Function(String stage, double progress)? onProgress,
  }) async {
    // 1. 获取上传凭证
    onProgress?.call('upload', 0);
    final ext = file.path.split('.').last.toLowerCase();
    final token = await getUploadToken(
      fileType: ext,
      folder: 'ai-image',
    );

    // 2. 上传到 OSS
    await uploadToOss(
      uploadUrl: token.uploadUrl,
      file: file,
      onProgress: (p) => onProgress?.call('upload', p * 0.8),
    );
    onProgress?.call('analyzing', 0.8);

    // 3. 调后端分析
    final result = await analyzeImage(
      imageUrl: token.publicUrl,
      petId: petId,
    );
    onProgress?.call('done', 1.0);
    return result;
  }
}

// ── OSS 上传凭证 ──────────────────────────────────────────
class OssUploadToken {
  final String uploadUrl;  // PUT 上传地址（预签名）
  final String publicUrl;  // 上传完成后的公开访问 URL

  const OssUploadToken({
    required this.uploadUrl,
    required this.publicUrl,
  });

  factory OssUploadToken.fromJson(Map<String, dynamic> json) => OssUploadToken(
    uploadUrl: (json['uploadUrl'] ?? json['url'] ?? '') as String,
    publicUrl: (json['publicUrl'] ?? json['fileUrl'] ?? '') as String,
  );
}

// ── Provider ─────────────────────────────────────────────
final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(apiClientProvider));
});
