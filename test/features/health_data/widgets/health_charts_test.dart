import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/health_data/widgets/health_charts.dart';

void main() {
  testWidgets('empty ratio keeps its chart track and does not imply zero',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: HealthRatioBar(
                label: '休息', ratio: null, color: Colors.green))));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        0);
  });

  testWidgets('zero readings remain distinct from missing observations',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HealthColumnChart(
      title: '每日记录',
      unit: '秒',
      color: Colors.green,
      points: const [
        HealthChartPoint('9/1', 0, '0'),
        HealthChartPoint('9/2', null, '无数据')
      ],
    ))));
    expect(find.text('0'), findsOneWidget);
    expect(find.text('无数据'), findsOneWidget);
    expect(find.text('每日记录：暂无数据'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing series shows an empty state instead of a zero chart',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HealthColumnChart(
      title: '每日记录',
      unit: '秒',
      color: Colors.green,
      points: const [HealthChartPoint('9/1', null, '无数据')],
    ))));
    expect(find.text('每日记录'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('待采集 · 秒'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'month data can scroll to its last day on a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
        home: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
          const HealthRing(ratios: [1], value: '100%', label: '运动上报占比'),
          HealthColumnChart(
              title: '每日记录',
              unit: '秒',
              color: Colors.green,
              points: List.generate(31,
                  (i) => HealthChartPoint('9/${i + 1}', i.toDouble(), '$i'))),
        ])))));
    expect(tester.takeException(), isNull);
    await tester.drag(
        find.byType(SingleChildScrollView).last, const Offset(-2500, 0));
    await tester.pumpAndSettle();
    expect(find.text('9/31').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
