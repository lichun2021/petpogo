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

import 'package:petpogo_app/core/logging/app_log.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';

/// 旧版 ali-oss signatureUrl 默认使用 HTTP。V1 签名不包含协议，
/// 仅升级已识别的阿里云 OSS 签名 URL；原始路径和查询串保持逐字节不变。
String secureOssUploadUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    throw ArgumentError('上传地址无效');
  }
  if (uri.scheme == 'https') return url;
  final isOssV1 = RegExp(r'^[a-z0-9][a-z0-9-]*\.oss-[a-z0-9-]+\.aliyuncs\.com$')
          .hasMatch(uri.host) &&
      const ['OSSAccessKeyId', 'Expires', 'Signature']
          .every((key) => uri.queryParameters[key]?.isNotEmpty == true);
  if (uri.scheme == 'http' &&
      !uri.hasPort &&
      RegExp(r'^http://[^/:?#]+/').hasMatch(url) &&
      isOssV1) {
    return 'https${url.substring(4)}';
  }
  throw ArgumentError('上传地址必须使用 HTTPS');
}

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

  factory OssSignResult.fromJson(Map<String, dynamic> json) {
    final upload = json['uploadUrl'];
    final cdn = json['cdnUrl'];
    if (upload is! String || upload.isEmpty || cdn is! String || cdn.isEmpty) {
      throw const ApiException(message: '上传凭证不完整，请重试');
    }
    final cdnUri = Uri.tryParse(cdn);
    if (cdnUri == null ||
        !['http', 'https'].contains(cdnUri.scheme) ||
        cdnUri.host.isEmpty ||
        cdnUri.userInfo.isNotEmpty) {
      throw const ApiException(message: '文件访问地址无效，请重试');
    }
    try {
      return OssSignResult(
        uploadUrl: secureOssUploadUrl(upload),
        key: json['key']?.toString() ?? '',
        cdnUrl: cdn,
      );
    } on ArgumentError {
      throw const ApiException(message: '上传地址无效，请稍后重试');
    }
  }
}

// ── OSS 上传工具类 ─────────────────────────────────────────
class OssUploader {
  final ApiClient _client;
  final Dio? _uploadClient;
  OssUploader(this._client, {Dio? uploadClient}) : _uploadClient = uploadClient;

  /// 获取 OSS 预签名上传地址
  ///
  /// [folder]   - 存储目录，见 library 注释
  /// [mimeType] - MIME 类型，如 'image/jpeg' / 'video/mp4'
  Future<OssSignResult> getSign({
    required String folder,
    required String mimeType,
    String? fileType,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.ossUploadSign,
      data: {
        'folder': folder,
        'mimeType': mimeType,
        if (fileType != null) 'fileType': fileType
      },
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
  }) =>
      _upload(uploadUrl, Stream.value(bytes), bytes.length, onProgress);

  Future<void> uploadFile({
    required String uploadUrl,
    required File file,
    void Function(double progress)? onProgress,
  }) async =>
      _upload(uploadUrl, file.openRead(), await file.length(), onProgress);

  Future<void> _upload(String uploadUrl, Stream<List<int>> data, int length,
      void Function(double progress)? onProgress) async {
    final secureUrl = secureOssUploadUrl(uploadUrl);
    final dio = _uploadClient ??
        Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
    // The current presigned contract excludes Content-Type from the signature.
    dio.interceptors.removeImplyContentTypeInterceptor();
    try {
      await dio.put(secureUrl,
          data: data,
          options: Options(
            headers: {Headers.contentLengthHeader: length},
            followRedirects: false,
            sendTimeout: const Duration(minutes: 5),
            receiveTimeout: const Duration(minutes: 5),
            validateStatus: (status) =>
                status != null && status >= 200 && status < 300,
          ), onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      });
    } on DioException catch (error) {
      AppLog.event('media.upload.failed', level: 'warning', fields: {
        'status': error.response?.statusCode,
        'errorType': error.type.name,
      });
      rethrow;
    } finally {
      if (_uploadClient == null) dio.close();
    }
  }
}

final ossUploaderProvider = Provider<OssUploader>((ref) {
  return OssUploader(ref.watch(apiClientProvider));
});
