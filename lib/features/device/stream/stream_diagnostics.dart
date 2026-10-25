import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api/peer_api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/logging/app_log.dart';
import 'stream_protocol.dart';

class StreamVideoStamp {
  final int attempt, sequence, receivedMs;
  const StreamVideoStamp(this.attempt, this.sequence, this.receivedMs);
}

/// 只记录链路元数据。视频、音频、文本消息正文和 URL 凭证不进入日志。
class StreamDiagnostics {
  final String mac;
  final String streamId;
  final int Function()? clock;
  final _watch = Stopwatch();
  final _stamps = Expando<StreamVideoStamp>();
  int attempt = 0;
  int messages = 0, binaryMessages = 0, textMessages = 0, receivedBytes = 0;
  int videoFrames = 0, audioFrames = 0, invalidFrames = 0;
  int decodedFrames = 0,
      paintedFrames = 0,
      decodeFailures = 0,
      decodeDropped = 0;
  int? _lastMessage, _lastVideo, _lastPaint, _statusAt;
  int _healthAt = 0, _healthVideo = 0, _healthDecoded = 0, _healthPainted = 0;
  bool? deviceConnected;
  int? appViewerCount;
  bool _firstFrameWarning = false;
  int _connectedAt = 0;
  final _decodeViews = <String>{},
      _paintViews = <String>{},
      _decodeBeginViews = <String>{};
  final _lastPainted = <String, StreamVideoStamp>{};
  final _rejections = <String, int>{};
  StreamDiagnostics(this.mac, {String? streamId, this.clock})
      : streamId = streamId ?? const Uuid().v4().substring(0, 12);
  int get nowMs => clock?.call() ?? _watch.elapsedMilliseconds;

  void begin(String reason) {
    attempt++;
    _watch
      ..reset()
      ..start();
    messages = binaryMessages = textMessages = receivedBytes = 0;
    videoFrames = audioFrames = invalidFrames = 0;
    decodedFrames = paintedFrames = decodeFailures = decodeDropped = 0;
    _lastMessage = _lastVideo = _lastPaint = _statusAt = null;
    deviceConnected = null;
    appViewerCount = null;
    _healthAt = nowMs;
    _healthVideo = _healthDecoded = _healthPainted = 0;
    _firstFrameWarning = false;
    _connectedAt = nowMs;
    _decodeViews.clear();
    _paintViews.clear();
    _decodeBeginViews.clear();
    _lastPainted.clear();
    _rejections.clear();
    log('session.start', '会话', '开始观看，记录运行环境', fields: {
      'reason': reason,
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'buildMode': kDebugMode
          ? 'debug'
          : kProfileMode
              ? 'profile'
              : 'release',
      'appVersion': AppConfig.appVersion,
      'apiBaseUrl': AppConfig.apiBaseUrl,
    });
  }

  void log(String event, String stage, String message,
      {String level = 'info',
      Map<String, Object?> fields = const {},
      int? forAttempt,
      int? elapsedMs}) {
    AppLog.deviceStream(event, level: level, fields: {
      ...fields,
      'streamId': streamId,
      'deviceMac': mac,
      'attempt': forAttempt ?? attempt,
      'elapsedMs': elapsedMs ?? nowMs,
      'stage': stage,
      'message': message,
    });
  }

  void failure(String event, String stage, String message, Object error,
      {Map<String, Object?> fields = const {}}) {
    log(event, stage, message,
        level: 'warning', fields: {...fields, ...safeError(error)});
  }

  static Map<String, Object?> safeError(Object error) {
    String text(String value) {
      final safe = AppLog.redact(value).replaceAll(RegExp(r'[\r\n]+'), ' ');
      return safe.length > 300 ? safe.substring(0, 300) : safe;
    }

    return {
      'errorType': error.runtimeType.toString(),
      'errorMessage': text(error.toString()),
      if (error is PeerApiException) ...{
        'businessCode': error.code,
        'errorMessage': text(error.tip),
      },
      if (error is DioException) ...{
        'reason': error.type.name,
        'status': error.response?.statusCode,
        'errorMessage': text(error.message ?? error.error?.toString() ?? ''),
      },
      if (error is SocketException) ...{
        'errorCode': error.osError?.errorCode,
        'errorMessage': text(error.osError?.message ?? error.message),
      },
      if (error is WebSocketException) 'errorMessage': text(error.message),
      if (error is TimeoutException)
        'errorMessage': text(error.message ?? 'timeout'),
      if (error is PlatformException) ...{
        'errorCode': error.code,
        'errorMessage': text(error.message ?? ''),
      },
      if (error is FormatException) 'errorMessage': text(error.message),
    };
  }

  void websocketConnected() {
    _connectedAt = nowMs;
  }

  void receivedMessage({required bool binary, required int bytes}) {
    messages++;
    receivedBytes += bytes;
    _lastMessage = nowMs;
    if (binary) {
      binaryMessages++;
    } else {
      textMessages++;
    }
    if (messages == 1) {
      log('ws.first_message', '接收消息', 'WebSocket 收到第一条消息', fields: {
        'reason': binary ? 'binary' : 'text',
        'bytes': bytes,
      });
    }
    if (!binary && textMessages <= 3) {
      log('ws.text_ignored', '协议解析', '收到文本消息，设备协议要求二进制；不记录文本内容',
          level: 'warning',
          fields: {'bytes': bytes, 'textMessages': textMessages});
    }
  }

  void rejected(StreamFrameInspection result) {
    invalidFrames++;
    final count =
        _rejections.update(result.rejection!, (n) => n + 1, ifAbsent: () => 1);
    if (count <= 3 || (count & (count - 1)) == 0) {
      log('packet.rejected', '协议解析', '丢弃不符合设备协议的数据包',
          level: 'warning',
          fields: {
            'reason': result.rejection,
            'frameType': result.type,
            'declaredBytes': result.declaredBytes,
            'availableBytes': result.availableBytes,
            'invalidFrames': invalidFrames,
          });
    }
  }

  void videoReceived(DeviceStreamFrame frame) {
    videoFrames++;
    _lastVideo = nowMs;
    _stamps[frame.payload] = StreamVideoStamp(attempt, videoFrames, nowMs);
    if (videoFrames == 1) {
      log('video.first_packet', '视频接收', '收到第一帧视频，下一步进入 JPEG 解码', fields: {
        'sequence': videoFrames,
        'bytes': frame.payload.length,
        'deviceTimestampMs': frame.timestamp,
      });
    }
  }

  void audioReceived(DeviceStreamFrame frame) {
    audioFrames++;
    if (audioFrames == 1) {
      log('audio.first_packet', '音频接收', '收到第一包设备 PCM 音频', fields: {
        'bytes': frame.payload.length,
        'deviceTimestampMs': frame.timestamp,
      });
    }
  }

  StreamVideoStamp? stamp(Uint8List bytes) => _stamps[bytes];
  void decodeBegin(StreamVideoStamp? stamp, String view, int bytes) {
    if (stamp == null || stamp.attempt != attempt) return;
    if (_decodeBeginViews.add(view)) {
      log('jpeg.decode.begin', 'JPEG 解码', '开始解码此视图的第一帧图片', fields: {
        'sequence': stamp.sequence,
        'bytes': bytes,
        'view': view,
      });
    }
  }

  void decoded(StreamVideoStamp? stamp, String view, int width, int height,
      int duration) {
    if (stamp == null || stamp.attempt != attempt) return;
    decodedFrames++;
    if (_decodeViews.add(view)) {
      log('jpeg.decode.ok', 'JPEG 解码', 'JPEG 已解码，等待界面绘制', fields: {
        'sequence': stamp.sequence,
        'view': view,
        'width': width,
        'height': height,
        'durationMs': duration,
      });
    }
  }

  void decodeFailed(
      StreamVideoStamp? stamp, String view, Object error, int duration) {
    if (stamp == null || stamp.attempt != attempt) return;
    decodeFailures++;
    if (decodeFailures <= 3 || (decodeFailures & (decodeFailures - 1)) == 0) {
      failure(
          'jpeg.decode.failed', 'JPEG 解码', '视频包有效，但图片解码失败；保留上一帧并等待新帧', error,
          fields: {
            'sequence': stamp.sequence,
            'view': view,
            'durationMs': duration,
            'decodeFailures': decodeFailures
          });
    }
  }

  void painted(
      StreamVideoStamp? stamp, String view, double width, double height) {
    if (stamp == null ||
        stamp.attempt != attempt ||
        width <= 0 ||
        height <= 0) {
      return;
    }
    if (identical(_lastPainted[view], stamp)) return;
    _lastPainted[view] = stamp;
    paintedFrames++;
    _lastPaint = nowMs;
    if (_paintViews.add(view)) {
      log('video.presented', '界面绘制', '第一帧图片已进入实际绘制流程', fields: {
        'sequence': stamp.sequence,
        'view': view,
        'paintWidth': width,
        'paintHeight': height,
        'durationMs': nowMs - stamp.receivedMs,
      });
    }
  }

  void serverStatus(bool? connected, int? viewers) {
    deviceConnected = connected;
    appViewerCount = viewers;
    _statusAt = nowMs;
    log('status.response', '媒体状态', '上游媒体连接状态查询完成', fields: {
      'deviceConnected': connected,
      'appViewerCount': viewers,
    });
  }

  String diagnosis(bool connected) {
    if (!connected) return 'websocket_not_connected';
    if (messages == 0) {
      if (deviceConnected == false &&
          _statusAt != null &&
          nowMs - _statusAt! < 30000) {
        return 'device_not_connected_to_relay';
      }
      return 'waiting_for_websocket_data';
    }
    if (binaryMessages == 0) return 'text_messages_only';
    if (videoFrames == 0) {
      return audioFrames > 0 ? 'audio_only_no_video' : 'protocol_rejected';
    }
    if (decodedFrames == 0) {
      return decodeFailures > 0
          ? 'jpeg_decode_failed'
          : 'waiting_for_jpeg_decode';
    }
    if (paintedFrames == 0) return 'decoded_but_not_painted';
    if (_lastVideo != null && nowMs - _lastVideo! > 5000) {
      return 'video_stalled';
    }
    if (_lastPaint != null && nowMs - _lastPaint! > 5000) {
      return 'paint_stalled_or_view_hidden';
    }
    return 'video_playing';
  }

  void health(bool connected,
      {int playingAudioChunks = 0, int talkPackets = 0}) {
    final elapsed = nowMs;
    final interval = elapsed - _healthAt;
    final reason = diagnosis(connected);
    const labels = {
      'websocket_not_connected': 'WebSocket 尚未连接',
      'device_not_connected_to_relay': '手机已连接，但设备未接入音视频中转',
      'waiting_for_websocket_data': 'WebSocket 已连接，尚未收到任何媒体消息',
      'text_messages_only': '仅收到文本消息，未收到协议要求的二进制数据',
      'audio_only_no_video': '已收到音频，但没有视频帧',
      'protocol_rejected': '已收到二进制数据，但全部被协议校验拒绝',
      'jpeg_decode_failed': '已收到视频，但 JPEG 解码失败',
      'waiting_for_jpeg_decode': '视频已到达，等待 JPEG 解码',
      'decoded_but_not_painted': 'JPEG 已解码，但尚未实际绘制到界面',
      'video_stalled': '视频已中断超过 5 秒，当前显示旧画面',
      'paint_stalled_or_view_hidden': '视频仍在接收，视图未继续绘制或已隐藏',
      'video_playing': '视频已接收、解码并绘制',
    };
    if (!_firstFrameWarning &&
        connected &&
        videoFrames == 0 &&
        elapsed - _connectedAt >= 15000) {
      _firstFrameWarning = true;
      log('video.first_frame.timeout', '等待首帧', '连接后 15 秒仍无视频帧，继续等待并查询媒体状态',
          level: 'warning', fields: {'timeoutMs': 15000, 'diagnosis': reason});
    }
    log('health', '链路巡检', labels[reason]!, fields: {
      'status': connected ? 'connected' : 'closed',
      'diagnosis': reason,
      'playingAudioChunks': playingAudioChunks,
      'talkPackets': talkPackets,
      'messages': messages,
      'binaryMessages': binaryMessages,
      'textMessages': textMessages,
      'receivedBytes': receivedBytes,
      'videoFrames': videoFrames,
      'audioFrames': audioFrames,
      'invalidFrames': invalidFrames,
      'decodedFrames': decodedFrames,
      'paintedFrames': paintedFrames,
      'decodeFailures': decodeFailures,
      'decodeDropped': decodeDropped,
      'lastMessageAgeMs': _lastMessage == null ? null : elapsed - _lastMessage!,
      'lastVideoAgeMs': _lastVideo == null ? null : elapsed - _lastVideo!,
      'lastPaintAgeMs': _lastPaint == null ? null : elapsed - _lastPaint!,
      'videoFps':
          interval <= 0 ? 0 : (videoFrames - _healthVideo) * 1000 / interval,
      'decodedFps': interval <= 0
          ? 0
          : (decodedFrames - _healthDecoded) * 1000 / interval,
      'paintedFps': interval <= 0
          ? 0
          : (paintedFrames - _healthPainted) * 1000 / interval,
      'deviceConnected': deviceConnected,
      'appViewerCount': appViewerCount,
      'statusAgeMs': _statusAt == null ? null : elapsed - _statusAt!,
    });
    _healthAt = elapsed;
    _healthVideo = videoFrames;
    _healthDecoded = decodedFrames;
    _healthPainted = paintedFrames;
  }
}
