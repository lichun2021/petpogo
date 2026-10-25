import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/peer_api_client.dart';
import 'stream_diagnostics.dart';

class DeviceStreamStatus {
  final bool? deviceConnected;
  final int? appViewerCount;
  const DeviceStreamStatus({this.deviceConnected, this.appViewerCount});
}

bool? _flag(Object? value) => value == true || value == 'true'
    ? true
    : value == false || value == 'false'
        ? false
        : null;

class DeviceStreamApi {
  final PeerApiClient peer;
  DeviceStreamApi(this.peer);

  Future<Uri> start(String mac, {StreamDiagnostics? diagnostics}) async {
    final watch = Stopwatch()..start();
    final attempt = diagnostics?.attempt;
    diagnostics?.log('start.request', '启动推流 HTTP', '开始请求硬件后台启动音视频', fields: {
      'method': 'POST',
      'path': '/sdkapi/peer/pet/stream/start',
      'video': true,
      'audio': true,
      'fps': 10,
      'quality': 20,
      'connectTimeoutMs': 10000,
      'receiveTimeoutMs': 30000,
    });
    final response = await peer.post<Map<String, dynamic>>('/pet/stream/start',
        params: {
          'mac': mac,
          'video': 'true',
          'audio': 'true',
          'fps': 10,
          'quality': 20
        }, fromInfo: (data) {
      if (data is! Map) throw const FormatException('启动接口 info 不是对象');
      return data.cast<String, dynamic>();
    });
    final info = response.info;
    final url = Uri.tryParse(info?['wsAppUrl']?.toString() ?? '');
    if (url == null ||
        !['ws', 'wss'].contains(url.scheme) ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty) {
      diagnostics?.log(
          'start.invalid_address', '启动响应校验', 'HTTP 请求成功，但没有可用的 WebSocket 地址',
          level: 'warning',
          fields: {
            'businessCode': response.code,
            'durationMs': watch.elapsedMilliseconds
          },
          forAttempt: attempt,
          elapsedMs: watch.elapsedMilliseconds);
      throw const FormatException('设备视频地址无效');
    }
    diagnostics?.log(
        'start.response', '启动推流 HTTP', '启动接口成功；下一步连接返回的 WebSocket 地址',
        fields: {
          'businessCode': response.code,
          'durationMs': watch.elapsedMilliseconds,
          'video': _flag(info?['video']),
          'audio': _flag(info?['audio']),
          'shared': _flag(info?['shared']),
          'wsUrl': url.toString(),
          'hasQuery': url.hasQuery,
        },
        forAttempt: attempt,
        elapsedMs: watch.elapsedMilliseconds);
    return url; // 使用完整地址；日志输出会剥离地址中的凭证参数。
  }

  Future<DeviceStreamStatus> status(String mac,
      {StreamDiagnostics? diagnostics}) async {
    final watch = Stopwatch()..start();
    final attempt = diagnostics?.attempt;
    final beganAt = diagnostics?.nowMs ?? 0;
    diagnostics
        ?.log('status.request', '媒体状态', '首帧未到或画面中断，查询设备是否接入媒体中转', fields: {
      'method': 'GET',
      'path': '/sdkapi/peer/pet/stream/status',
      'connectTimeoutMs': 10000,
      'receiveTimeoutMs': 30000,
    });
    final response = await peer.get<Map<String, dynamic>>('/pet/stream/status',
        params: {'mac': mac},
        fromInfo: (data) => (data as Map).cast<String, dynamic>());
    diagnostics?.log('status.http.ok', '媒体状态', '媒体状态 HTTP 请求成功',
        fields: {
          'businessCode': response.code,
          'durationMs': watch.elapsedMilliseconds,
        },
        forAttempt: attempt,
        elapsedMs: beganAt + watch.elapsedMilliseconds);
    final viewers =
        int.tryParse(response.info?['appViewerCount']?.toString() ?? '');
    return DeviceStreamStatus(
        deviceConnected: _flag(response.info?['deviceConnected']),
        appViewerCount: viewers != null && viewers >= 0 ? viewers : null);
  }

  Future<void> stop(String mac, {StreamDiagnostics? diagnostics}) async {
    final watch = Stopwatch()..start();
    diagnostics
        ?.log('stop.request', '停止推流 HTTP', '本机连接关闭后，通知硬件后台结束本次观看', fields: {
      'method': 'POST',
      'path': '/sdkapi/peer/pet/stream/stop',
    });
    await peer.post('/pet/stream/stop', params: {'mac': mac});
    diagnostics?.log('stop.response', '停止推流 HTTP', '停止观看请求成功',
        fields: {'durationMs': watch.elapsedMilliseconds});
  }
}

final deviceStreamApiProvider = Provider<DeviceStreamApi>(
    (ref) => DeviceStreamApi(ref.watch(peerApiClientProvider)));
