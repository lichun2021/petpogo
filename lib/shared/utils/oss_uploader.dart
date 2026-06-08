/// OSS 上传工具
///
/// 整个 App 的 OSS 直传逻辑统一在这里。
/// 调用方只需：
///   1. getOssSign(folder, mimeType) → 获取预签名
///   2. uploadBytes(uploadUrl, bytes) → PUT 直传
///
/// folder 规划：
///   posts          - 社区帖子图片/视频
///   ai             - AI 情绪分析上传
///   avatar         - 用户/宠物头像
///   devices-media  - 机器人摄影媒体库
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

// ── OSS 签名响应模型 ───────────────────────────────────────
class OssSignResult {
  /// OSS PUT 预签名地址（15 分钟有效）
  final String uploadUrl;

  /// OSS 对象 Key（用于后续删除/拼 CDN）
  final String key;

  /// CDN 公开访问地址（上传后立即可用）
  final String cdnUrl;

  const OssSignResult({
    required this.uploadUrl,
    required this.key,
    required this.cdnUrl,
  });

  factory OssSignResult.fromJson(Map<String, dynamic> json) => OssSignResult(
    uploadUrl: (json['uploadUrl'] as String?) ?? '',
    key:       (json['key']       as String?) ?? '',
    cdnUrl:    (json['cdnUrl']    as String?) ?? '',
  );
}

// ── OSS 上传工具类 ─────────────────────────────────────────
class OssUploader {
  final ApiClient _client;
  OssUploader(this._client);

  /// 获取 OSS 预签名上传地址
  ///
  /// [folder]   - 存储目录，见 library 注释
  /// [mimeType] - MIME 类型，如 'image/jpeg' / 'video/mp4'
  Future<OssSignResult> getSign({
    required String folder,
    required String mimeType,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.ossUploadSign,
      data: {'folder': folder, 'mimeType': mimeType},
    );
    return OssSignResult.fromJson(res);
  }

  /// PUT 直传 OSS
  ///
  /// NOTE: OSS 预签名 v1 把 Content-Type 纳入 HMAC，
  ///       后端签名时若 Content-Type 为空则客户端也不能发，否则 403。
  ///       如需传 Content-Type，后端签名时需同步指定。
  Future<void> uploadBytes({
    required String uploadUrl,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async {
    final dio = Dio();
    debugPrint('[OSS] 开始上传 ${bytes.length} bytes → $uploadUrl');
    try {
      final resp = await dio.put(
        uploadUrl,
        data: bytes,
        options: Options(
          headers: const <String, dynamic>{},
          sendTimeout:    const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
          validateStatus: (s) => s != null && s < 400,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
      debugPrint('[OSS] 上传成功 status=${resp.statusCode}');
    } on DioException catch (e) {
      debugPrint('[OSS] 上传失败 status=${e.response?.statusCode}');
      debugPrint('[OSS] 错误体: ${e.response?.data}');
      rethrow;
    }
  }
}

final ossUploaderProvider = Provider<OssUploader>((ref) {
  return OssUploader(ref.watch(apiClientProvider));
});
