import 'dart:async';
import 'package:petpogo_app/features/home/controller/hold_recording_session.dart';
import 'dart:ui' show SemanticsAction, SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/shared/widgets/glass_bottom_nav.dart';
import 'package:petpogo_app/shared/widgets/pressable.dart';

void main() {
  recordingSessionTests();
  testWidgets('PressableButton exposes one semantic label and handles tap',
      (tester) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableButton(
            semanticLabel: '保存',
            onTap: () => taps++,
            child: const Text('保存'),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('保存'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('disabled PressableButton has no tap action', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableButton(
            semanticLabel: '保存',
            child: const Text('保存'),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('保存'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('NavButton exposes selected semantic state', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NavButton(
            item: NavItem(
              icon: Icons.home_outlined,
              label: '首页',
            ),
            selected: true,
            onTap: () {},
          ),
        ),
      ),
    );

    final data =
        tester.getSemantics(find.bySemanticsLabel('首页')).getSemanticsData();
    expect(data.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
    semantics.dispose();
  });
}

void recordingSessionTests() {
  test('release during permission/start discards the eventual recording',
      () async {
    final ready = Completer<bool>();
    var stops = 0;
    var cancels = 0;
    final session = HoldRecordingSession(
        start: () => ready.future,
        stop: () async {
          stops++;
          return 'audio.wav';
        },
        cancel: () async {
          cancels++;
        });
    final begin = session.begin();
    final end = session.end(submit: true);
    ready.complete(true);
    await begin;
    expect(await end, isNull);
    expect(stops, 0);
    expect(cancels, 1);
    expect(session.isRecording, isFalse);
  });

  test('drag cancellation never submits and duplicate release ends only once',
      () async {
    final cancelled = Completer<void>();
    var stops = 0;
    var cancels = 0;
    final session = HoldRecordingSession(
        start: () async => true,
        stop: () async {
          stops++;
          return 'audio.wav';
        },
        cancel: () {
          cancels++;
          return cancelled.future;
        });
    await session.begin();
    final cancel = session.end(submit: false);
    final release = session.end(submit: true);
    cancelled.complete();
    expect(await cancel, isNull);
    expect(await release, isNull);
    expect(stops, 0);
    expect(cancels, 1);
  });

  test('successful hold yields one recording and allows the next session',
      () async {
    var stops = 0;
    final session = HoldRecordingSession(
        start: () async => true,
        stop: () async => 'audio-${++stops}.wav',
        cancel: () async {});
    await session.begin();
    expect(session.isRecording, isTrue);
    expect(await session.end(submit: true), 'audio-1.wav');
    await session.begin();
    expect(await session.end(submit: true), 'audio-2.wav');
  });

  test('denied permission does not stop or cancel an inactive recorder',
      () async {
    final session = HoldRecordingSession(
        start: () async => false,
        stop: () async => throw StateError('unexpected stop'),
        cancel: () async => throw StateError('unexpected cancel'));
    await session.begin();
    expect(await session.end(submit: true), isNull);
    expect(session.isRecording, isFalse);
  });

  test('failed startup can be retried', () async {
    var attempts = 0;
    final session = HoldRecordingSession(
        start: () async {
          if (++attempts == 1) throw StateError('microphone unavailable');
          return true;
        },
        stop: () async => 'retry.wav',
        cancel: () async {});
    await expectLater(session.begin(), throwsStateError);
    await session.begin();
    expect(await session.end(submit: true), 'retry.wav');
  });
}
