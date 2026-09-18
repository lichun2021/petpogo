/// Peer protocol adapter over the signed SDKAPI gateway.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

// ── iPet 统一响应格式 ────────────────────────────────────
class PeerResponse<T> {
  final int code;
  final String tip;
  final T? info;
  final List<dynamic>? list;

  PeerResponse({required this.code, required this.tip, this.info, this.list});

  factory PeerResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromInfo,
  ) {
    return PeerResponse<T>(
      code: json['code'] is num
          ? (json['code'] as num).toInt()
          : int.tryParse(json['code']?.toString() ?? '') ?? -1,
      tip: json['tip']?.toString() ?? '',
      info: fromInfo != null && json['info'] != null
          ? fromInfo(json['info'])
          : null,
      list: json['list'] as List<dynamic>?,
    );
  }

  bool get isSuccess => code == 0;
}

// ── PeerApiClient ────────────────────────────────────────
class PeerApiClient {
  final ApiClient _client;

  PeerApiClient(this._client);

  /// POST to iPet gateway (form-urlencoded), returns parsed [PeerResponse]
  Future<PeerResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? params,
    T Function(dynamic)? fromInfo,
    bool useJson = false, // true → application/json body
  }) async {
    dynamic body;
    Options options = Options(contentType: Headers.formUrlEncodedContentType);
    if (useJson) {
      body = params ?? {};
      options = Options(headers: {'Content-Type': 'application/json'});
    } else {
      body = params != null
          ? Uri(
              queryParameters:
                  params.map((k, v) => MapEntry(k, v?.toString() ?? ''))).query
          : '';
    }

    final res = await _client.post<dynamic>(
      '${ApiEndpoints.peerProxyPrefix}$path',
      data: body,
      options: options,
    );
    final json = _decodeResponseMap(res, path);
    final pr = PeerResponse<T>.fromJson(json, fromInfo);
    if (!pr.isSuccess) {
      debugPrint('[PeerApi] POST $path 业务错误 code=${pr.code}: ${pr.tip}');
      throw Exception('[iPet] ${pr.tip}');
    }
    return pr;
  }

  /// GET to iPet gateway (query params), returns parsed [PeerResponse]
  /// 部分接口（如 /user/device/online/state）服务端只接受 GET。
  Future<PeerResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? params,
    T Function(dynamic)? fromInfo,
  }) async {
    final res = await _client.get<dynamic>(
      '${ApiEndpoints.peerProxyPrefix}$path',
      params: params?.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    );
    final json = _decodeResponseMap(res, path);
    final pr = PeerResponse<T>.fromJson(json, fromInfo);
    if (!pr.isSuccess) {
      debugPrint('[PeerApi] GET $path 业务错误 code=${pr.code}: ${pr.tip}');
      throw Exception('[iPet] ${pr.tip}');
    }
    return pr;
  }

  // ── 声音控制 ─────────────────────────────────────────────

  /// 播放音频到设备  POST /pet/sound/play  (JSON body)
  /// [mac]    设备 MAC 地址
  /// [url]    音频 URL (MP3/AAC/FLAC/WAV)
  /// [volume] 0-21，默认 15
  Future<PeerResponse<void>> soundPlay({
    required String mac,
    required String url,
    int volume = 15,
  }) =>
      post<void>('/pet/sound/play', useJson: true, params: {
        'mac': mac,
        'url': url,
        'volume': volume,
      });

  /// 停止设备播放  POST /pet/sound/stop  (JSON body)
  Future<PeerResponse<void>> soundStop({required String mac}) =>
      post<void>('/pet/sound/stop', useJson: true, params: {'mac': mac});
}

// ── 日志拦截器 ────────────────────────────────────────────
Map<String, dynamic> _decodeResponseMap(dynamic data, String path) {
  if (data is Map) return data.cast<String, dynamic>();
  if (data is String) {
    final text = data.trim();
    if (text.isEmpty) {
      throw FormatException('[PeerApi] $path 返回空响应');
    }
    final decoded = jsonDecode(text);
    if (decoded is Map) return decoded.cast<String, dynamic>();
  }
  throw FormatException(
    '[PeerApi] $path 响应格式错误: ${data.runtimeType}',
  );
}

// Reuse SDK authentication and token lifecycle, including logout/refresh.
final peerApiClientProvider = Provider<PeerApiClient>((ref) {
  return PeerApiClient(ref.watch(apiClientProvider));
});
