import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/health_data/widgets/health_charts.dart';
import 'package:petpogo_app/features/health_data/widgets/health_timeline_chart.dart';

void main() {
  testWidgets('empty hourly chart keeps full day axes and grid',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: HealthTimelineChart(
                points: [], color: Colors.green, unit: '分钟', hourly: true))));
    expect(find.text('0时'), findsOneWidget);
    expect(find.text('24时'), findsOneWidget);
    expect(find.text('待采集'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'sparse hours remain in their time slots; missing is distinct from zero',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HealthTimelineChart(
                points: List.generate(
                    24,
                    (h) => HealthChartPoint(
                        '$h时',
                        h == 8
                            ? 2
                            : h == 9
                                ? 0
                                : null,
                        h == 8
                            ? '2'
                            : h == 9
                                ? '0'
                                : '—')),
                color: Colors.green,
                unit: '分钟',
                hourly: true))));
    final plot = find.byType(GestureDetector).last;
    final rect = tester.getRect(plot);
    await tester
        .tapAt(Offset(rect.left + rect.width * 8.5 / 24, rect.center.dy));
    await tester.pump();
    expect(find.text('8时  2分钟'), findsOneWidget);
    await tester
        .tapAt(Offset(rect.left + rect.width * 9.5 / 24, rect.center.dy));
    await tester.pump();
    expect(find.text('9时  0分钟'), findsOneWidget);
    await tester
        .tapAt(Offset(rect.left + rect.width * 10.5 / 24, rect.center.dy));
    await tester.pump();
    expect(find.text('10时  —'), findsOneWidget);
  });

  testWidgets('hourly axis fits a narrow card with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: const Scaffold(
            body: Padding(
                padding: EdgeInsets.all(36),
                child: HealthTimelineChart(
                    points: [],
                    color: Colors.green,
                    unit: '分钟',
                    hourly: true)))));
    expect(tester.takeException(), isNull);
    expect(find.text('24时'), findsOneWidget);
  });
}
