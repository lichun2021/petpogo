import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Debug output is disabled in release. Operational events carry only a small
/// allowlist of metadata; request bodies and credentials never enter the log.
abstract final class AppLog {
  static void debug(String? message, {int? wrapWidth}) {
    if (!kDebugMode) return;
    debugPrint(redact(message ?? ''), wrapWidth: wrapWidth);
  }

  static void event(String event,
      {String level = 'info', Map<String, Object?> fields = const {}}) {
    const allowed = {
      'requestId',
      'method',
      'path',
      'status',
      'durationMs',
      'errorType',
      'attempt',
      'category'
    };
    _write(event, level, fields, allowed);
  }

  /// 视频链路的元数据白名单；不接受正文、帧内容、请求头或任意嵌套对象。
  static void deviceStream(String event,
      {String level = 'info', Map<String, Object?> fields = const {}}) {
    const allowed = {
      'streamId',
      'deviceMac',
      'attempt',
      'stage',
      'message',
      'elapsedMs',
      'durationMs',
      'timeoutMs',
      'platform',
      'osVersion',
      'buildMode',
      'appVersion',
      'reason',
      'errorType',
      'errorCode',
      'errorMessage',
      'method',
      'path',
      'status',
      'businessCode',
      'video',
      'audio',
      'shared',
      'fps',
      'quality',
      'wsUrl',
      'apiBaseUrl',
      'connectTimeoutMs',
      'receiveTimeoutMs',
      'hasQuery',
      'pingIntervalMs',
      'bytes',
      'frameType',
      'declaredBytes',
      'availableBytes',
      'deviceTimestampMs',
      'sequence',
      'messages',
      'binaryMessages',
      'textMessages',
      'receivedBytes',
      'videoFrames',
      'audioFrames',
      'invalidFrames',
      'decodeFailures',
      'decodedFrames',
      'paintedFrames',
      'decodeDropped',
      'width',
      'height',
      'view',
      'paintWidth',
      'paintHeight',
      'lastMessageAgeMs',
      'lastVideoAgeMs',
      'lastPaintAgeMs',
      'videoFps',
      'decodedFps',
      'paintedFps',
      'diagnosis',
      'deviceConnected',
      'appViewerCount',
      'statusAgeMs',
      'closeCode',
      'closeReason',
      'reconnectDelayMs',
      'playingAudioChunks',
      'talkPackets',
      'talkAttempt',
      'talking',
      'talkBusy',
      'socketState',
      'permissionGranted',
      'permissionRequested',
      'recorderState',
      'nativeMethod',
      'encoder',
      'sampleRate',
      'channels',
      'bitsPerSample',
      'byteOrder',
      'audioSource',
      'echoCancel',
      'noiseSuppress',
      'chunkBytes',
      'packetIntervalMs',
      'maxQueuedChunks',
      'micBatches',
      'micBytes',
      'pcmChunks',
      'queuedChunks',
      'partialBytes',
      'droppedChunks',
      'sentPackets',
      'sentBytes',
      'lastCaptureAgeMs',
      'lastSendAgeMs',
      'pcmPeak',
      'nonZeroSamples',
      'errorStack',
      'errorDetails',
      'recordingId',
      'recordFrames',
      'writtenFrames',
      'recordVideoBytes',
      'recordAudioPackets',
      'recordAudioBytes',
      'audioSamples',
      'silenceSamples',
      'pendingFrames',
      'droppedFrames',
      'recordDurationMs',
      'maxDurationMs',
      'outputBytes',
      'hasAudio',
      'sourcePreserved',
      'localFilePreserved',
      'sourceFolder',
      'uploadPercent',
      'uploadedBytes',
      'totalBytes',
      'mediaType',
      'playbackId',
      'mediaId',
      'backend',
      'softwareDecoding',
      'mediaSource',
      'mediaHost',
      'positionMs',
      'playing',
      'buffering',
    };
    _write('device.stream.$event', level, fields, allowed);
  }

  static void _write(String event, String level, Map<String, Object?> fields,
      Set<String> allowed) {
    if (!kDebugMode && level != 'warning' && level != 'error') return;
    debugPrint(jsonEncode({
      'time': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'event': event,
      for (final entry in fields.entries)
        if (allowed.contains(entry.key) &&
            (entry.value == null ||
                entry.value is String ||
                entry.value is num ||
                entry.value is bool))
          entry.key: entry.value is String
              ? redact(entry.value as String)
              : entry.value,
    }));
  }

  static String redact(String message) {
    var safe = message.replaceAllMapped(
        RegExp(r'''(?:https?|wss?|petpogo)://[^\s<>"']+'''), (match) {
      final url = Uri.tryParse(match[0]!);
      if (url == null) return '<url>';
      return '${url.scheme}://${url.host}${url.hasPort ? ':${url.port}' : ''}${url.path}';
    });
    safe = safe.replaceAll(
        RegExp(r'Bearer\s+[^\s,}]+', caseSensitive: false), 'Bearer ***');
    safe = safe.replaceAllMapped(
        RegExp(
            r'''(["']?)(password|oldPassword|newPassword|refreshToken|refresh_token|access_token|userSig|token|secret|x-signature|code)\1\s*[:=]\s*(?:"[^"]*"|'[^']*'|[^\s,}]+)''',
            caseSensitive: false),
        (match) => '${match[2]}=***');
    return safe.replaceAllMapped(RegExp(r'\b(1\d{2})\d{4}(\d{4})\b'),
        (match) => '${match[1]}****${match[2]}');
  }
}
