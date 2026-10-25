import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:petpogo_app/core/logging/app_log.dart';
import 'package:petpogo_app/features/device/stream/stream_diagnostics.dart';
import 'package:petpogo_app/features/device/stream/jpeg_stream_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/peer_api_client.dart';
import 'package:petpogo_app/features/device/stream/device_stream_api.dart';
import 'package:petpogo_app/features/device/stream/device_stream_session.dart';
import 'package:petpogo_app/features/device/stream/device_audio_io.dart';
import 'package:petpogo_app/features/device/stream/http_motor_controller.dart';
import 'package:petpogo_app/features/device/stream/local_stream_recorder.dart';
import 'package:petpogo_app/features/device/stream/recording_diagnostics.dart';
import 'package:petpogo_app/features/device/stream/stream_protocol.dart';
import 'package:petpogo_device_media/petpogo_device_media.dart';
import 'package:record/record.dart';

Uint8List packet(int type, List<int> payload, {int timestamp = 12345}) {
  final data = Uint8List(9 + payload.length);
  final header = ByteData.sublistView(data);
  header.setUint8(0, type);
  header.setUint32(1, timestamp);
  header.setUint32(5, payload.length);
  data.setAll(9, payload);
  return data;
}

class Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, Object?>? response;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    requests.add(options);
    return ResponseBody.fromString(
        jsonEncode(response ??
            {
              'code': 0,
              'info': options.path.endsWith('/start')
                  ? {
                      'wsAppUrl':
                          'ws://49.234.39.11:8006/ws/app/ipet-bot-01?ticket=keep%2Bme',
                      'shared': true
                    }
                  : 'success'
            }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

class FakeApi extends DeviceStreamApi {
  final Uri url;
  int starts = 0, stops = 0;
  Completer<void>? pending;
  FakeApi(this.url) : super(PeerApiClient(ApiClient()));
  @override
  Future<Uri> start(String mac, {StreamDiagnostics? diagnostics}) async {
    starts++;
    await pending?.future;
    return url;
  }

  @override
  Future<void> stop(String mac, {StreamDiagnostics? diagnostics}) async {
    stops++;
  }

  @override
  Future<DeviceStreamStatus> status(String mac,
          {StreamDiagnostics? diagnostics}) async =>
      const DeviceStreamStatus(deviceConnected: false, appViewerCount: 1);
}

class FakeAudio extends DeviceAudioIo {
  final received = <Uint8List>[];
  @override
  Future<void> open() async {}
  @override
  void play(Uint8List pcm) {
    received.add(pcm);
  }

  @override
  Future<void> volume(double value) async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> dispose() async {}
}

class FakeSocket extends Stream<dynamic> implements WebSocket {
  final input = StreamController<dynamic>();
  bool closed = false;
  int state = WebSocket.open;
  Object? sendError;
  final sent = <dynamic>[];
  @override
  Duration? pingInterval;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  int get readyState => state;
  @override
  void add(dynamic data) {
    if (sendError != null) throw sendError!;
    sent.add(data);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    unawaited(input.close());
  }

  @override
  StreamSubscription<dynamic> listen(void Function(dynamic)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      input.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMic implements AudioRecorder {
  final input = StreamController<Uint8List>();
  int stops = 0;
  bool permission = true;
  Object? startError;
  bool started = false;
  final permissionRequests = <bool>[];
  @override
  Future<bool> hasPermission({bool request = true}) async {
    permissionRequests.add(request);
    return permission;
  }

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    if (startError != null) throw startError!;
    started = true;
    return input.stream;
  }

  @override
  Stream<RecordState> onStateChanged() => const Stream.empty();
  @override
  Future<String?> stop() async {
    stops++;
    return null;
  }

  @override
  Future<void> dispose() async {
    if (!started) input.stream.listen((_) {});
    await input.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMedia extends DeviceMedia {
  @override
  Future<void> openAudio() async {}
  @override
  Future<void> closeAudio() async {}
  @override
  Future<void> setVolume(double volume) async {}
}

class FakeExporter extends DeviceMedia {
  Map<String, dynamic>? manifest;
  Object? error;
  bool emptyOutput = false;
  @override
  Future<String> encodeRecording(String path) async {
    manifest =
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    if (error != null) throw error!;
    final output = manifest!['outputPath'] as String;
    await File(output).writeAsBytes(emptyOutput ? [] : [0, 0, 0, 1]);
    return output;
  }
}

class StreamLogs {
  final entries = <Map<String, dynamic>>[];
  final previous = debugPrint;
  StreamLogs() {
    debugPrint = (message, {wrapWidth}) {
      if (message == null) return;
      try {
        final value = jsonDecode(message);
        if (value is Map<String, dynamic>) entries.add(value);
      } catch (_) {}
    };
  }
  void close() {
    debugPrint = previous;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.record/messages'),
            (_) async => null);
  });
  test('binary header is big endian and preserves little endian PCM bytes', () {
    final frame = DeviceStreamFrame.parse(
        packet(2, [0, 128, 255, 127], timestamp: 0x12345678))!;
    expect(frame.timestamp, 0x12345678);
    expect(frame.payload, [0, 128, 255, 127]);
    expect(DeviceStreamFrame.parse(packet(1, [255, 216, 255, 217]))!.type, 1);
  });
  test('truncated, unsupported and odd PCM frames are discarded', () {
    expect(DeviceStreamFrame.parse([1, 2]), isNull);
    final short = packet(1, [255]);
    ByteData.sublistView(short).setUint32(5, 1000);
    expect(DeviceStreamFrame.parse(short), isNull);
    expect(DeviceStreamFrame.parse(packet(2, [1])), isNull);
    expect(DeviceStreamFrame.parse(packet(4, [1, 2])), isNull);
    expect(DeviceStreamFrame.parse(packet(1, [])), isNull);
  });
  test('talk frames are 20ms PCM with downlink type and unsigned timestamp',
      () {
    final data = buildTalkFrame(0x100000001, Uint8List(640));
    expect(data.length, 649);
    expect(data[0], 3);
    expect(ByteData.sublistView(data).getUint32(1), 1);
    expect(ByteData.sublistView(data).getUint32(5), 640);
    expect(() => buildTalkFrame(0, Uint8List(320)), throwsArgumentError);
  });
  test('start and stop use signed gateway and preserve the returned WS URL',
      () async {
    final adapter = Adapter();
    final api = DeviceStreamApi(
        PeerApiClient(ApiClient(token: 'test-token', adapter: adapter)));
    final url = await api.start('ipet-bot-01');
    await api.stop('ipet-bot-01');
    expect(url.toString(),
        'ws://49.234.39.11:8006/ws/app/ipet-bot-01?ticket=keep%2Bme');
    final request = adapter.requests.first;
    expect(request.path, '/sdkapi/peer/pet/stream/start');
    expect(request.method, 'POST');
    expect(Uri.splitQueryString(utf8.decode(request.data as List<int>)), {
      'mac': 'ipet-bot-01',
      'video': 'true',
      'audio': 'true',
      'fps': '10',
      'quality': '20'
    });
    expect(request.headers['Authorization'], 'Bearer test-token');
    expect(request.headers['x-signature-version'], '2');
    expect(adapter.requests.last.path, '/sdkapi/peer/pet/stream/stop');
  });
  test('HTTP movement coalesces slow commands and sends stop last', () async {
    final first = Completer<void>();
    final calls = <List<int>>[];
    final motor = HttpMotorController((a, b, c, d) async {
      calls.add([a, b, c, d]);
      if (calls.length == 1) await first.future;
    });
    motor.update(1, 20, 1, 20);
    motor.update(1, 30, 1, 30);
    motor.update(1, 40, 1, 40);
    final stopped = motor.stop();
    expect(calls, [
      [1, 20, 1, 20]
    ]);
    first.complete();
    await stopped;
    expect(calls, [
      [1, 20, 1, 20],
      [0, 0, 0, 0]
    ]);
    await motor.close();
    motor.update(1, 100, 1, 100);
    expect(calls.length, 2);
  });
  test('leaving during start ignores the late response without opening WS',
      () async {
    final api = FakeApi(Uri.parse('ws://127.0.0.1/'))
      ..pending = Completer<void>();
    var connections = 0;
    final session = DeviceStreamSession(
        mac: 'ipet-bot-01',
        api: api,
        audio: FakeAudio(),
        connect: (_) async {
          connections++;
          throw StateError('must not connect');
        });
    final opening = session.start();
    await Future<void>.delayed(Duration.zero);
    await session.stop();
    api.pending!.complete();
    await opening;
    expect(connections, 0);
    expect(session.connected, isFalse);
    await session.release();
  });
  test('WS session routes JPEG and PCM and closes before HTTP stop', () async {
    final socket = FakeSocket();
    final audio = FakeAudio();
    final api = FakeApi(Uri.parse('ws://127.0.0.1/'));
    final session = DeviceStreamSession(
        mac: 'ipet-bot-01',
        api: api,
        audio: audio,
        connect: (_) async => socket);
    await session.start();
    socket.input.add(packet(1, [255, 216, 255, 217]));
    socket.input.add(packet(2, [0, 128, 255, 127]));
    socket.input.add('ignored text');
    await Future<void>.delayed(Duration.zero);
    expect(session.latestJpeg.value, [255, 216, 255, 217]);
    expect(audio.received.single, [0, 128, 255, 127]);
    expect(socket.pingInterval, const Duration(seconds: 15));
    await session.stop();
    expect(socket.closed, isTrue);
    expect(api.stops, 1);
    await session.release();
  });
  test('microphone batches are paced and stop discards queued speech',
      () async {
    final mic = FakeMic();
    final audio = DeviceAudioIo(recorder: mic);
    final sent = <Uint8List>[];
    expect(
        await audio
            .startTalking(sent.add, (_) {})
            .timeout(const Duration(seconds: 2)),
        isTrue);
    mic.input.add(Uint8List(3200));
    await Future<void>.delayed(Duration.zero);
    expect(sent, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(sent.length, inInclusiveRange(1, 4));
    await audio.stopTalking().timeout(const Duration(seconds: 2));
    final count = sent.length;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(sent.length, count);
    expect(mic.stops, 1);
    await mic.dispose().timeout(const Duration(seconds: 2));
  });
  test('talk logs permission denial before native capture is started',
      () async {
    final logs = StreamLogs();
    final mic = FakeMic()..permission = false;
    final trace = StreamDiagnostics('bot')..begin('test');
    final audio = DeviceAudioIo(recorder: mic)..diagnostics = trace;
    try {
      expect(await audio.startTalking((_) => fail('must not send'), (_) {}),
          isFalse);
      expect(mic.permissionRequests, [false, true]);
      expect(mic.stops, 0);
      expect(
          logs.entries
              .where(
                  (e) => e['event'] == 'device.stream.talk.permission.result')
              .last['permissionGranted'],
          isFalse);
      expect(
          logs.entries.any(
              (e) => e['event'] == 'device.stream.talk.capture.start.request'),
          isFalse);
    } finally {
      await audio.stopTalking();
      await mic.dispose();
      logs.close();
    }
  });
  test('talk native failures retain stage code details and sanitized stack',
      () async {
    final logs = StreamLogs();
    final mic = FakeMic()
      ..startError = PlatformException(
          code: 'microphone_busy',
          message: 'AudioRecord initialization failed',
          details: 'device busy token=private-value');
    final audio = DeviceAudioIo(recorder: mic)
      ..diagnostics = (StreamDiagnostics('bot')..begin('test'));
    try {
      await expectLater(audio.startTalking((_) {}, (_) {}),
          throwsA(isA<PlatformException>()));
      final failure = logs.entries.singleWhere(
          (e) => e['event'] == 'device.stream.talk.capture.start.failed');
      expect(failure['stage'], '原生麦克风初始化');
      expect(failure['errorCode'], 'microphone_busy');
      expect(failure['errorMessage'], contains('AudioRecord'));
      expect(failure['errorDetails'], isNot(contains('private-value')));
      expect(failure['errorStack'], contains('FakeMic.startStream'));
      expect(mic.stops, 1);
      expect(audio.capturing, isFalse);
    } finally {
      await audio.stopTalking();
      await mic.dispose();
      logs.close();
    }
  });
  test(
      'talk sends catch socket exceptions and clear pending microphone packets',
      () async {
    final logs = StreamLogs();
    final mic = FakeMic();
    final audio = DeviceAudioIo(recorder: mic)
      ..diagnostics = (StreamDiagnostics('bot')..begin('test'));
    final failed = Completer<Object>();
    var sends = 0;
    try {
      await audio.startTalking((_) {
        sends++;
        throw StateError('WebSocket is closed');
      }, failed.complete);
      mic.input.add(Uint8List(640 * 5));
      final error = await failed.future.timeout(const Duration(seconds: 2));
      expect(error,
          isA<DeviceTalkFailure>().having((e) => e.phase, 'phase', 'send'));
      await audio.stopTalking();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(sends, 1);
      expect(mic.stops, 1);
      expect(audio.capturing, isFalse);
      final event = logs.entries
          .singleWhere((e) => e['event'] == 'device.stream.talk.send.failed');
      expect(event['stage'], 'WebSocket 对讲发送');
      expect(event['sentPackets'], 0);
      expect(event['errorMessage'], contains('WebSocket is closed'));
      expect(
          logs.entries
              .any((e) => e['event'] == 'device.stream.talk.cleanup.ok'),
          isTrue);
    } finally {
      await audio.stopTalking();
      await mic.dispose();
      logs.close();
    }
  });
  test('talk capture errors produce one failure and stop recording', () async {
    final logs = StreamLogs();
    final mic = FakeMic();
    final audio = DeviceAudioIo(recorder: mic)
      ..diagnostics = (StreamDiagnostics('bot')..begin('test'));
    final failed = Completer<Object>();
    try {
      await audio.startTalking((_) {}, failed.complete);
      mic.input.addError(PlatformException(
          code: 'capture_lost', message: 'Input disconnected'));
      final error = await failed.future.timeout(const Duration(seconds: 2));
      expect(error,
          isA<DeviceTalkFailure>().having((e) => e.phase, 'phase', 'capture'));
      await audio.stopTalking();
      expect(mic.stops, 1);
      expect(
          logs.entries.singleWhere((e) =>
              e['event'] == 'device.stream.talk.capture.failed')['errorCode'],
          'capture_lost');
    } finally {
      await audio.stopTalking();
      await mic.dispose();
      logs.close();
    }
  });
  test('talk logs PCM batching queue drops and signal metadata without audio',
      () async {
    final logs = StreamLogs();
    final mic = FakeMic();
    final audio = DeviceAudioIo(recorder: mic)
      ..diagnostics = (StreamDiagnostics('bot')..begin('test'));
    try {
      await audio.startTalking((_) {}, (_) {});
      mic.input.add(Uint8List.fromList([1]));
      mic.input.add(Uint8List(639));
      mic.input.add(Uint8List(640 * 20));
      await Future<void>.delayed(Duration.zero);
      await audio.stopTalking(reason: 'test_stop');
      final fields = logs.entries
          .singleWhere((e) => e['event'] == 'device.stream.talk.cleanup.ok');
      expect(fields['micBytes'], 640 * 21);
      expect(fields['pcmChunks'], 21);
      expect(fields['queuedChunks'], lessThanOrEqualTo(10));
      expect(fields['droppedChunks'], greaterThanOrEqualTo(10));
      expect(fields['partialBytes'], 0);
      expect(fields['pcmPeak'], 1);
      expect(fields['nonZeroSamples'], 1);
      expect(
          logs.entries
              .any((e) => e.containsKey('pcm') || e.containsKey('payload')),
          isFalse);
    } finally {
      await audio.stopTalking();
      await mic.dispose();
      logs.close();
    }
  });
  test('talk watchdog identifies a microphone that returns no PCM', () async {
    final logs = StreamLogs();
    final mic = FakeMic();
    final audio = DeviceAudioIo(recorder: mic)
      ..diagnostics = (StreamDiagnostics('bot')..begin('test'));
    try {
      await audio.startTalking((_) {}, (_) {});
      await Future<void>.delayed(const Duration(milliseconds: 5050));
      final health = logs.entries
          .singleWhere((e) => e['event'] == 'device.stream.talk.health');
      expect(health['diagnosis'], 'microphone_no_data');
      expect(health['micBatches'], 0);
      expect(health['sentPackets'], 0);
      expect(health['level'], 'warning');
    } finally {
      await audio.stopTalking();
      await mic.dispose();
      logs.close();
    }
  });
  test('talk closed socket is diagnosed without stopping video session',
      () async {
    final logs = StreamLogs();
    final mic = FakeMic();
    final socket = FakeSocket();
    final session = DeviceStreamSession(
        mac: 'bot',
        api: FakeApi(Uri.parse('ws://localhost/')),
        audio: DeviceAudioIo(recorder: mic, media: FakeMedia()),
        connect: (_) async => socket);
    try {
      await session.start();
      await session.toggleTalk();
      socket.state = WebSocket.closed;
      mic.input.add(Uint8List(640));
      for (var i = 0; i < 100 && session.talking; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(session.talking, isFalse);
      expect(session.connected, isTrue);
      expect(session.audioError, '对讲发送失败，请重新开启');
      expect(socket.sent, isEmpty);
      final failure = logs.entries.singleWhere(
          (e) => e['event'] == 'device.stream.talk.socket.unavailable');
      expect(failure['socketState'], WebSocket.closed);
      expect(failure['talkAttempt'], 1);
    } finally {
      await session.release();
      logs.close();
    }
  });
  test(
      'recording exports timestamped frames and PCM then clears temporary sources',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('petpogo-record-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => directory.path);
    final exporter = FakeExporter();
    final logs = StreamLogs();
    final recorder = LocalStreamRecorder(media: exporter)
      ..diagnostics = (StreamDiagnostics('bot')..begin('test'));
    try {
      await recorder.start(Uint8List.fromList([255, 216, 255, 217]));
      recorder.addAudio(Uint8List(640));
      recorder.addVideo(Uint8List.fromList([255, 216, 255, 217]));
      final output = await recorder.finish();
      expect(await File(output).exists(), isTrue);
      final frames = exporter.manifest!['frames'] as List;
      expect(frames.length, 2);
      expect((frames.last as Map)['timeUs'],
          greaterThanOrEqualTo((frames.first as Map)['timeUs']));
      expect(await File(exporter.manifest!['audioPath'] as String).exists(),
          isFalse);
      expect(await File((frames.first as Map)['path'] as String).exists(),
          isFalse);
      final events = logs.entries
          .where(
              (e) => (e['event'] as String).startsWith('device.stream.record.'))
          .toList();
      expect(events.map((e) => e['recordingId']).toSet(), hasLength(1));
      expect(
          events.map((e) => e['event']),
          containsAllInOrder([
            'device.stream.record.local.start.begin',
            'device.stream.record.local.start.ok',
            'device.stream.record.sources.flushed',
            'device.stream.record.manifest.ready',
            'device.stream.record.encode.begin',
            'device.stream.record.encode.ok',
            'device.stream.record.sources.cleanup.ok',
          ]));
      final encoded = events
          .singleWhere((e) => e['event'] == 'device.stream.record.encode.ok');
      expect(encoded['outputBytes'], 4);
      expect(encoded['hasAudio'], true);
      expect(exporter.manifest!['recordingId'], encoded['recordingId']);
      expect(
          events.any(
              (e) => e.containsKey('frames') || e.containsKey('audioPath')),
          isFalse);
    } finally {
      await recorder.cancel();
      await directory.delete(recursive: true);
      logs.close();
    }
  });
  for (final emptyOutput in [false, true]) {
    test(
        emptyOutput
            ? 'record diagnostics identify empty native output and retain sources'
            : 'record diagnostics identify native encoding failure and retain sources',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('petpogo-record-error-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => directory.path);
      final logs = StreamLogs();
      final exporter = FakeExporter()..emptyOutput = emptyOutput;
      if (!emptyOutput)
        exporter.error = PlatformException(
            code: 'EXPORT_FAILED', message: 'hardware encoder unavailable');
      final recorder = LocalStreamRecorder(media: exporter)
        ..diagnostics = (StreamDiagnostics('bot')..begin('test'));
      try {
        await recorder.start(Uint8List.fromList([255, 216, 255, 217]));
        final firstId = recorder.trace!.recordingId;
        await expectLater(
            recorder.finish(),
            throwsA(
                emptyOutput ? isA<StateError>() : isA<PlatformException>()));
        final failure = logs.entries.singleWhere(
            (e) => e['event'] == 'device.stream.record.finish.failed');
        expect(failure['stage'], emptyOutput ? 'MP4 输出校验' : '原生 MP4 编码');
        expect(failure['sourcePreserved'], true);
        if (!emptyOutput) expect(failure['errorCode'], 'EXPORT_FAILED');
        final sources = exporter.manifest!['frames'] as List;
        expect(await File((sources.first as Map)['path'] as String).exists(),
            true);
        expect(await File(exporter.manifest!['audioPath'] as String).exists(),
            true);
        expect(recorder.active, false);
        await recorder.start(Uint8List.fromList([255, 216, 255, 217]));
        expect(recorder.trace!.recordingId, isNot(firstId));
        await recorder.cancel();
      } finally {
        await recorder.cancel();
        await directory.delete(recursive: true);
        logs.close();
      }
    });
  }
  test('record cancellation logs its reason and removes unexported sources',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('petpogo-record-cancel-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => directory.path);
    final logs = StreamLogs();
    final exporter = FakeExporter();
    final recorder = LocalStreamRecorder(media: exporter)
      ..diagnostics = (StreamDiagnostics('bot')..begin('test'));
    try {
      await recorder.start(Uint8List.fromList([255, 216, 255, 217]));
      recorder.addAudio(Uint8List(640));
      await recorder.cancel(reason: 'page_closed_during_start');
      expect(exporter.manifest, isNull);
      expect(
          Directory('${directory.path}/device-recordings').listSync(), isEmpty);
      final cancelled = logs.entries
          .singleWhere((e) => e['event'] == 'device.stream.record.cancel.ok');
      expect(cancelled['reason'], 'page_closed_during_start');
      expect(cancelled['sourcePreserved'], false);
    } finally {
      await recorder.cancel();
      await directory.delete(recursive: true);
      logs.close();
    }
  });
  test('record upload logs retain original context and redact credentials', () {
    final logs = StreamLogs();
    try {
      final stream = StreamDiagnostics('bot', streamId: 'watch')..begin('test');
      final first = RecordingDiagnostics(stream, recordingId: 'clip-1');
      first.log('album.save.ok', '保存系统相册', 'saved');
      stream.begin('reconnect');
      final second = RecordingDiagnostics(stream, recordingId: 'clip-2');
      second.log('start.begin', '录像入口', 'start');
      first.failure(
          'upload.failed',
          'OSS 文件上传',
          'failed',
          const FormatException(
              'https://viewer:private-password@oss.example/file?Signature=private-signature'),
          fields: {'body': 'private-body', 'payload': Uint8List(1)});
      final events = logs.entries
          .where(
              (e) => (e['event'] as String).startsWith('device.stream.record.'))
          .toList();
      expect(events.last['recordingId'], 'clip-1');
      expect(events.last['attempt'], 1);
      expect(events[1]['recordingId'], 'clip-2');
      expect(events[1]['attempt'], 2);
      final encoded = jsonEncode(events);
      expect(encoded, isNot(contains('private-password')));
      expect(encoded, isNot(contains('private-signature')));
      expect(encoded, isNot(contains('private-body')));
      expect(events.last.containsKey('payload'), false);
    } finally {
      logs.close();
    }
  });
  test('stream diagnostics identify each stalled stage and correlate attempts',
      () {
    final logs = StreamLogs();
    try {
      var time = 0;
      final trace = StreamDiagnostics('ipet-bot-01',
          streamId: 'watch-1', clock: () => time);
      trace.begin('test');
      expect(trace.diagnosis(true), 'waiting_for_websocket_data');
      trace.serverStatus(false, 1);
      expect(trace.diagnosis(true), 'device_not_connected_to_relay');
      time = 15000;
      trace.health(true);
      trace.health(true);
      expect(
          logs.entries.where(
              (e) => e['event'] == 'device.stream.video.first_frame.timeout'),
          hasLength(1));
      final bytes = Uint8List.fromList([255, 216, 255, 217]);
      trace.receivedMessage(binary: true, bytes: 13);
      trace.videoReceived(DeviceStreamFrame(1, 0, bytes));
      final stamp = trace.stamp(bytes)!;
      expect(trace.diagnosis(true), 'waiting_for_jpeg_decode');
      trace.decodeFailed(
          stamp, 'inline', const FormatException('JPEG invalid'), 3);
      expect(trace.diagnosis(true), 'jpeg_decode_failed');
      trace.decoded(stamp, 'inline', 640, 480, 5);
      expect(trace.diagnosis(true), 'decoded_but_not_painted');
      trace.painted(stamp, 'inline', 320, 240);
      expect(trace.diagnosis(true), 'video_playing');
      time += 6000;
      expect(trace.diagnosis(true), 'video_stalled');
      trace.health(true);
      expect(
          logs.entries
              .every((e) => e['streamId'] == 'watch-1' && e['attempt'] == 1),
          isTrue);
      trace.begin('retry');
      trace.decoded(stamp, 'inline', 640, 480, 1);
      expect(trace.decodedFrames, 0,
          reason:
              'A late decode from the old attempt must not update the new attempt');
    } finally {
      logs.close();
    }
  });
  test('stream log allowlist removes WS credentials and media contents', () {
    final logs = StreamLogs();
    try {
      AppLog.deviceStream('test', fields: {
        'wsUrl':
            'ws://viewer:private-password@media.example/ws/app/bot?ticket=private-ticket&token=private-token#private-fragment',
        'body': 'private-body',
        'payload': Uint8List.fromList([1, 2, 3]),
        'errorMessage':
            'Failed wss://viewer:private-userinfo@media.example/ws?token=private-query',
        'stage': 'WebSocket 握手',
      });
      final text = jsonEncode(logs.entries.single);
      for (final secret in [
        'private-password',
        'private-ticket',
        'private-token',
        'private-fragment',
        'private-body',
        'private-userinfo',
        'private-query'
      ]) {
        expect(text, isNot(contains(secret)));
      }
      expect(logs.entries.single['wsUrl'], 'ws://media.example/ws/app/bot');
      expect(logs.entries.single.containsKey('payload'), isFalse);
    } finally {
      logs.close();
    }
  });
  test('HTTP business failure retains its code even with non-map info',
      () async {
    final adapter = Adapter()
      ..response = {'code': 12003, 'info': 'not a map', 'tip': '用户未绑定该设备'};
    final api = DeviceStreamApi(PeerApiClient(ApiClient(adapter: adapter)));
    await expectLater(api.start('bot'),
        throwsA(isA<PeerApiException>().having((e) => e.code, 'code', 12003)));
  });
  test('status probe logs upstream device connectivity without stopping WS',
      () async {
    final logs = StreamLogs();
    final socket = FakeSocket();
    final session = DeviceStreamSession(
        mac: 'ipet-bot-01',
        api: FakeApi(Uri.parse('ws://localhost/')),
        audio: FakeAudio(),
        connect: (_) async => socket);
    try {
      await session.start();
      await session.probeStatus();
      final health =
          logs.entries.lastWhere((e) => e['event'] == 'device.stream.health');
      expect(health['diagnosis'], 'device_not_connected_to_relay');
      expect(health['deviceConnected'], false);
      expect(health['appViewerCount'], 1);
      expect(session.connected, isTrue);
    } finally {
      await session.release();
      logs.close();
    }
  });
  test('protocol rejection logs contain header details without payload', () {
    final logs = StreamLogs();
    try {
      final trace = StreamDiagnostics('bot')..begin('test');
      final bytes = packet(1, [99, 88]);
      ByteData.sublistView(bytes).setUint32(5, 500);
      final inspection = DeviceStreamFrame.inspect(bytes);
      expect(inspection.rejection, 'payload_truncated');
      trace.rejected(inspection);
      final rejected = logs.entries
          .singleWhere((e) => e['event'] == 'device.stream.packet.rejected');
      expect(rejected['declaredBytes'], 500);
      expect(rejected['availableBytes'], 2);
      expect(rejected.containsKey('payload'), isFalse);
    } finally {
      logs.close();
    }
  });
  testWidgets('JPEG diagnostics distinguish decoding from an actual paint',
      (tester) async {
    final logs = StreamLogs();
    final trace = StreamDiagnostics('bot')..begin('test');
    final bytes = File('assets/digital_pet/bg/bg1.jpg').readAsBytesSync();
    trace.videoReceived(DeviceStreamFrame(1, 0, bytes));
    final frames = ValueNotifier<Uint8List?>(bytes);
    try {
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
            home: SizedBox(
                width: 100,
                height: 100,
                child: JpegStreamView(frames: frames, diagnostics: trace))));
        for (var i = 0;
            i < 100 && trace.decodedFrames == 0 && trace.decodeFailures == 0;
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
      await tester.pump();
      expect(
          logs.entries.any((e) => e['event'] == 'device.stream.jpeg.decode.ok'),
          isTrue,
          reason: jsonEncode(logs.entries));
      expect(
          logs.entries
              .any((e) => e['event'] == 'device.stream.video.presented'),
          isTrue);
      expect(trace.paintedFrames, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    } finally {
      frames.dispose();
      logs.close();
    }
  });
}
