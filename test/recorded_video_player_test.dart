import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/device/recorded_video_player_page.dart';

class FakeRecordingBackend implements RecordedVideoBackend {
  final errorEvents = StreamController<String>.broadcast();
  final opened = Completer<void>();
  final frame = Completer<void>();
  Completer<void>? closing;
  Object? openError, closeError;
  String? source;
  int disposals = 0, pauses = 0;
  @override
  String get name => 'fake_software';
  @override
  bool get softwareDecoding => true;
  @override
  Stream<String> get errors => errorEvents.stream;
  @override
  Future<void> get firstFrame => frame.future;
  @override
  Future<void> open(String source) async {
    this.source = source;
    if (openError != null) throw openError!;
    await opened.future;
  }

  @override
  Widget buildVideo() => const SizedBox(key: ValueKey('recording-surface'));
  @override
  Map<String, Object?> get stats => {
        'positionMs': 500,
        'durationMs': 6000,
        'width': 640,
        'height': 480,
        'playing': true,
        'buffering': false,
      };
  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await closing?.future;
    await errorEvents.close();
    if (closeError != null) throw closeError!;
  }
}

void main() {
  final logs = <Map<String, dynamic>>[];
  late void Function(String?, {int? wrapWidth}) previous;
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
  }

  void playbackTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      logs.clear();
      previous = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message == null) return;
        try {
          final value = jsonDecode(message);
          if (value is Map<String, dynamic>) logs.add(value);
        } catch (_) {}
      };
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await flush(tester);
        debugPrint = previous;
      }
    });
  }

  Widget page(RecordedVideoBackend Function() factory) => MaterialApp(
        home: RecordedVideoPlayerPage(
          source:
              'https://cdn.example/recording.mp4?Signature=private-signature',
          mediaId: 17,
          deviceMac: 'ipet-bot-01',
          backendFactory: factory,
        ),
      );

  playbackTest('opening and first-frame futures are distinct and logged',
      (tester) async {
    final backend = FakeRecordingBackend();
    await tester.pumpWidget(page(() => backend));
    await flush(tester);
    expect(find.byKey(const ValueKey('recording-surface')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    backend.opened.complete();
    await flush(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        logs.any((e) => e['event'] == 'device.stream.record.playback.open.ok'),
        true);
    backend.frame.complete();
    await flush(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final frame = logs.singleWhere(
        (e) => e['event'] == 'device.stream.record.playback.first_frame');
    expect(frame['mediaId'], 17);
    expect(frame['width'], 640);
    expect(backend.source, contains('Signature=private-signature'),
        reason: 'Preserve the source URL for playback');
    expect(jsonEncode(logs), isNot(contains('private-signature')));
    await tester.pumpWidget(const SizedBox());
    await flush(tester);
    expect(backend.disposals, 1, reason: jsonEncode(logs));
    expect(tester.takeException(), isNull);
  });

  playbackTest('open failure shows retry and consumes the failed future',
      (tester) async {
    final backend = FakeRecordingBackend()
      ..openError = StateError(
          'Decoder init failed https://cdn.example/a?Signature=private-error');
    await tester.pumpWidget(page(() => backend));
    await flush(tester);
    expect(find.text('视频暂时无法播放，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(backend.disposals, 1, reason: jsonEncode(logs));
    final failure = logs.singleWhere(
        (e) => e['event'] == 'device.stream.record.playback.failed');
    expect(failure['stage'], '录像播放器初始化');
    expect(failure['errorMessage'], contains('Decoder init failed'));
    expect(jsonEncode(logs), isNot(contains('private-error')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'runtime errors release the old decoder before retry opens another',
      (tester) async {
    final first = FakeRecordingBackend()..closing = Completer<void>();
    final second = FakeRecordingBackend();
    var creations = 0;
    await tester.pumpWidget(page(() => creations++ == 0 ? first : second));
    first.opened.complete();
    first.frame.complete();
    await flush(tester);
    first.errorEvents.add('decoder lost');
    await flush(tester);
    expect(find.text('重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await flush(tester);
    expect(creations, 1);
    expect(second.source, isNull);
    first.closing!.complete();
    await flush(tester);
    expect(creations, 2);
    second.opened.complete();
    second.frame.complete();
    await flush(tester);
    expect(find.text('视频暂时无法播放，请重试'), findsNothing);
    expect(find.byKey(const ValueKey('recording-surface')), findsOneWidget);
    expect(second.source, contains('recording.mp4'));
    await tester.pumpWidget(const SizedBox());
    await flush(tester);
    expect(second.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  playbackTest(
      'late open and first-frame callbacks cannot update a closed page',
      (tester) async {
    final backend = FakeRecordingBackend();
    await tester.pumpWidget(page(() => backend));
    await flush(tester);
    await tester.pumpWidget(const SizedBox());
    backend.opened.complete();
    backend.frame.complete();
    await flush(tester);
    expect(backend.disposals, 1, reason: jsonEncode(logs));
    expect(
        logs.any((e) => e['event'] == 'device.stream.record.playback.open.ok'),
        false);
    expect(
        logs.any(
            (e) => e['event'] == 'device.stream.record.playback.first_frame'),
        false);
    expect(tester.takeException(), isNull);
  });

  playbackTest('video-output failure is caught separately from opening',
      (tester) async {
    final backend = FakeRecordingBackend();
    await tester.pumpWidget(page(() => backend));
    backend.frame.completeError(StateError('Surface unavailable'));
    backend.opened.complete();
    await flush(tester);
    expect(find.text('重试'), findsOneWidget);
    final failure = logs.singleWhere(
        (e) => e['event'] == 'device.stream.record.playback.failed');
    expect(failure['stage'], '录像视频输出');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  playbackTest('dispose failure is logged without escaping into Flutter',
      (tester) async {
    final backend = FakeRecordingBackend()
      ..closeError = StateError('native dispose failed');
    await tester.pumpWidget(page(() => backend));
    await flush(tester);
    await tester.pumpWidget(const SizedBox());
    await flush(tester);
    expect(
        logs.any((e) =>
            e['event'] == 'device.stream.record.playback.dispose.failed'),
        true);
    expect(tester.takeException(), isNull);
  });
}
