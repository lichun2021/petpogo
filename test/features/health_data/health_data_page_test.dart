import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/api_exception.dart';
import 'package:petpogo_app/core/api/result.dart';
import 'package:petpogo_app/features/health_data/data/models/health_data_models.dart';
import 'package:petpogo_app/features/health_data/data/repository/health_data_repository.dart';
import 'package:petpogo_app/features/health_data/health_data_page.dart';
import 'package:petpogo_app/features/health_data/widgets/health_timeline_chart.dart';

class _UnavailableRepository extends HealthDataRepository {
  _UnavailableRepository() : super(ApiClient());
  Result<T> unavailable<T>() => Failure(const ApiException(message: 'offline'));
  @override
  Future<Result<HealthOverview>> fetchOverview(
          {required String petId, String? date}) async =>
      unavailable();
  @override
  Future<Result<HealthReport>> fetchHealthReport(
          {required String petId, String? date}) async =>
      unavailable();
  @override
  Future<Result<BehaviorAnalysis>> fetchBehaviorAnalysis(
          {required String petId, String? date, String? period}) async =>
      unavailable();
  @override
  Future<Result<ExerciseData>> fetchExerciseData(
          {required String petId, String? date, String? period}) async =>
      unavailable();
}

class _DocumentRepository extends HealthDataRepository {
  _DocumentRepository() : super(ApiClient());
  final examples = jsonDecode(
      File('test/features/health_data/fixtures/health_api_examples.json')
          .readAsStringSync()) as Map<String, dynamic>;
  @override
  Future<Result<HealthOverview>> fetchOverview(
          {required String petId, String? date}) async =>
      Success(HealthOverview.fromJson(examples['overview']));
  @override
  Future<Result<HealthReport>> fetchHealthReport(
          {required String petId, String? date}) async =>
      Success(HealthReport.fromJson(examples['report']));
  @override
  Future<Result<BehaviorAnalysis>> fetchBehaviorAnalysis(
          {required String petId, String? date, String? period}) async =>
      Success(BehaviorAnalysis.fromJson(examples['behavior']));
  @override
  Future<Result<ExerciseData>> fetchExerciseData(
          {required String petId, String? date, String? period}) async =>
      Success(ExerciseData.fromJson(examples['exercise']));
}

void main() {
  testWidgets('four sections use document fields and omit unsupported metrics',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      healthDataRepositoryProvider.overrideWithValue(_DocumentRepository())
    ], child: const MaterialApp(home: HealthDataPage(petId: '123'))));
    await tester.pumpAndSettle();
    for (final title in ['健康数据概览', '健康数据报告', '行为分析详情', '运动数据详情']) {
      expect(find.text(title), findsOneWidget);
    }
    for (final unsupported in [
      '步数',
      '热量',
      '睡眠质量',
      '深睡',
      '浅睡',
      '健康评分',
      '上报次数'
    ]) {
      expect(find.text(unsupported), findsNothing);
    }
    final charts = tester
        .widgetList<HealthTimelineChart>(find.byType(HealthTimelineChart))
        .toList();
    expect(charts.length, 3);
    expect(charts[0].points[1].value, 2); // Report lying: 120 seconds.
    expect(charts[1].points.single.value, 8); // Baseline lying: 480 seconds.
    expect(charts[2].points[8].value, 25); // Exercise: 25 walking reports.
    final other = find.widgetWithText(ChoiceChip, '其他行为');
    await tester.ensureVisible(other);
    await tester.tap(other);
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<HealthTimelineChart>(find.byType(HealthTimelineChart))
            .first
            .points[0]
            .value,
        closeTo(100 / 60, .001));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unavailable data retains complete charts on a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          healthDataRepositoryProvider
              .overrideWithValue(_UnavailableRepository())
        ],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!),
            home: const HealthDataPage(petId: 'empty'))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('24时'), findsNWidgets(2));
    expect(find.text('—'), findsWidgets);
    expect(find.text('0%'), findsNothing);
    expect(find.text('重试'), findsWidgets);
  });
}
