import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/api_exception.dart';
import 'package:petpogo_app/core/api/result.dart';
import 'package:petpogo_app/features/health_data/controller/health_data_controller.dart';
import 'package:petpogo_app/features/health_data/data/models/health_data_models.dart';
import 'package:petpogo_app/features/health_data/data/repository/health_data_repository.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Fake Repository
// ═════════════════════════════════════════════════════════════════════════════

class _FakeRepository extends HealthDataRepository {
  _FakeRepository() : super(ApiClient());

  int overviewCallCount = 0;
  int reportCallCount = 0;
  int behaviorCallCount = 0;
  int exerciseCallCount = 0;

  String? lastBehaviorPeriod;
  String? lastExercisePeriod;

  Future<Result<BehaviorAnalysis>> Function(String?)? behaviorHandler;
  Result<HealthOverview>? overviewResult;
  Result<HealthReport>? reportResult;
  Result<BehaviorAnalysis>? behaviorResult;
  Result<ExerciseData>? exerciseResult;

  @override
  Future<Result<HealthOverview>> fetchOverview({
    required String petId,
    String? date,
  }) async {
    overviewCallCount++;
    return overviewResult ?? Success(_mockOverview(petId));
  }

  @override
  Future<Result<HealthReport>> fetchHealthReport({
    required String petId,
    String? date,
  }) async {
    reportCallCount++;
    return reportResult ?? Success(_mockReport(petId));
  }

  @override
  Future<Result<BehaviorAnalysis>> fetchBehaviorAnalysis({
    required String petId,
    String? date,
    String? period,
  }) async {
    behaviorCallCount++;
    lastBehaviorPeriod = period;
    if (behaviorHandler != null) return behaviorHandler!(period);
    return behaviorResult ?? Success(_mockBehavior(petId));
  }

  @override
  Future<Result<ExerciseData>> fetchExerciseData({
    required String petId,
    String? date,
    String? period,
  }) async {
    exerciseCallCount++;
    lastExercisePeriod = period;
    return exerciseResult ?? Success(_mockExercise(petId));
  }

  // ── Mock 数据工厂 ────────────────────────────────────────────────────
  HealthOverview _mockOverview(String petId) {
    return HealthOverview(
      petId: petId,
      period: 'day',
      reportDate: '2026-09-17',
      behaviorAnalysis: BehaviorAnalysisSummary(
        totalReportCount: 100,
        behaviors: [
          BehaviorEntry(
            behavior: 'sleep',
            name: '睡觉',
            category: 'rest',
            reportCount: 50,
            ratio: 0.5,
            averageConfidence: 0.9,
          ),
        ],
      ),
      exerciseData: ExerciseDataSummary(
        walkingReportCount: 20,
        exerciseReportCount: 20,
        exerciseRatio: 0.2,
        steps: 1000,
        caloriesKcal: 50.0,
      ),
      healthStatus: HealthStatusInfo(
        sleepQuality: HealthStatusEntry(
          status: HealthStatus.stable,
          currentRatio: 0.5,
          baselineRatio: 0.5,
          delta: 0.0,
          reason: 'OK',
        ),
        restStatus: HealthStatusEntry(
          status: HealthStatus.stable,
          currentRatio: null,
          baselineRatio: null,
          delta: null,
          reason: 'OK',
        ),
        feedingRegularity: HealthStatusEntry(
          status: HealthStatus.unknown,
          currentRatio: null,
          baselineRatio: null,
          delta: null,
          reason: 'OK',
        ),
      ),
      dataQuality: DataQuality(
        level: DataQualityLevel.available,
        totalReportCount: 100,
        validReportCount: 100,
        unsupportedReportCount: 0,
        observedDays: 5,
        baselineDays: 7,
        firstObservedAt: null,
        lastObservedAt: null,
      ),
      disclaimer: 'Test disclaimer',
    );
  }

  HealthReport _mockReport(String petId) {
    return HealthReport(
      petId: petId,
      reportDate: '2026-09-17',
      dataOverview: DataOverview(
        summary: 'Summary',
        observations: ['Obs1'],
        suggestions: ['Sug1'],
        aiGenerated: true,
      ),
      trend: Trend(
        range: TimeRange(start: '2026-09-17', end: '2026-09-18'),
        totalDurationSeconds: 86400,
        categories: TrendCategories(
          rest: TrendCategory(durationSeconds: 40000, ratio: 0.46, hourly: []),
          exercise:
              TrendCategory(durationSeconds: 20000, ratio: 0.23, hourly: []),
          behavior:
              TrendCategory(durationSeconds: 26400, ratio: 0.31, hourly: []),
        ),
      ),
      disclaimer: 'Test disclaimer',
    );
  }

  BehaviorAnalysis _mockBehavior(String petId) {
    return BehaviorAnalysis(
      petId: petId,
      period: 'day',
      range: TimeRange(start: '2026-09-17', end: '2026-09-18'),
      totalReportCount: 100,
      behaviors: [
        BehaviorDetail(
          behavior: 'sleep',
          name: '睡觉',
          category: 'rest',
          reportCount: 50,
          ratio: 0.5,
          durationSeconds: 18000,
          baselineRatio: 0.5,
        ),
        BehaviorDetail(
          behavior: 'walk',
          name: '散步',
          category: 'exercise',
          reportCount: 30,
          ratio: 0.3,
          durationSeconds: 10800,
          baselineRatio: 0.3,
        ),
      ],
      baseline: BaselineInfo(
        start: '2026-09-10',
        end: '2026-09-17',
        days: 7,
        requiredDays: 7,
        unlocked: true,
        behaviors: {},
        dailyBehaviorDistribution: [],
      ),
      disclaimer: 'Test disclaimer',
    );
  }

  ExerciseData _mockExercise(String petId) {
    return ExerciseData(
      petId: petId,
      period: 'day',
      range: TimeRange(start: '2026-09-17', end: '2026-09-18'),
      summary: ExerciseSummary(
        walkingReportCount: 20,
        exerciseReportCount: 20,
        exerciseRatio: 0.2,
        steps: 1000,
        caloriesKcal: 50.0,
      ),
      timeline: [],
      dataQuality: DataQuality(
        level: DataQualityLevel.available,
        totalReportCount: 100,
        validReportCount: 100,
        unsupportedReportCount: 0,
        observedDays: 5,
        baselineDays: 7,
        firstObservedAt: null,
        lastObservedAt: null,
      ),
      unavailableMetrics: [],
      disclaimer: 'Test disclaimer',
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tests
// ═════════════════════════════════════════════════════════════════════════════

void main() {
  group('HealthDataController', () {
    late _FakeRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = _FakeRepository();
      container = ProviderContainer(
        overrides: [
          healthDataRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('初始化时加载全部四个段', () async {
      container.read(healthDataControllerProvider('pet123').notifier);

      // 等待初始化完成
      await Future.delayed(Duration.zero);

      expect(fakeRepo.overviewCallCount, 1);
      expect(fakeRepo.reportCallCount, 1);
      expect(fakeRepo.behaviorCallCount, 1);
      expect(fakeRepo.exerciseCallCount, 1);

      final state = container.read(healthDataControllerProvider('pet123'));
      expect(state.overview.data, isNotNull);
      expect(state.report.data, isNotNull);
      expect(state.behavior.data, isNotNull);
      expect(state.exercise.data, isNotNull);
    });

    test('setPeriod 只重新加载 behavior + exercise', () async {
      final controller =
          container.read(healthDataControllerProvider('pet123').notifier);
      await Future.delayed(Duration.zero); // 等待初始化

      fakeRepo.overviewCallCount = 0;
      fakeRepo.reportCallCount = 0;
      fakeRepo.behaviorCallCount = 0;
      fakeRepo.exerciseCallCount = 0;

      await controller.setPeriod('week');

      expect(fakeRepo.overviewCallCount, 0, reason: 'overview 不应重新加载');
      expect(fakeRepo.reportCallCount, 0, reason: 'report 不应重新加载');
      expect(fakeRepo.behaviorCallCount, 1, reason: 'behavior 应重新加载');
      expect(fakeRepo.exerciseCallCount, 1, reason: 'exercise 应重新加载');
      expect(fakeRepo.lastBehaviorPeriod, 'week');
      expect(fakeRepo.lastExercisePeriod, 'week');
    });

    test('rapid period changes ignore the earlier response', () async {
      final controller =
          container.read(healthDataControllerProvider('pet123').notifier);
      await Future.delayed(Duration.zero);
      final week = Completer<Result<BehaviorAnalysis>>();
      final month = Completer<Result<BehaviorAnalysis>>();
      fakeRepo.behaviorHandler =
          (period) => period == 'week' ? week.future : month.future;
      final first = controller.setPeriod('week');
      final second = controller.setPeriod('month');
      final latest = fakeRepo._mockBehavior('month-result');
      month.complete(Success(latest));
      await second;
      week.complete(Success(fakeRepo._mockBehavior('week-result')));
      await first;
      expect(
          container.read(healthDataControllerProvider('pet123')).behavior.data,
          same(latest));
    });

    test('setDate 重新加载全部四个段', () async {
      final controller =
          container.read(healthDataControllerProvider('pet123').notifier);
      await Future.delayed(Duration.zero);

      fakeRepo.overviewCallCount = 0;
      fakeRepo.reportCallCount = 0;
      fakeRepo.behaviorCallCount = 0;
      fakeRepo.exerciseCallCount = 0;

      final initialDate =
          container.read(healthDataControllerProvider('pet123')).selectedDate;
      final targetDate = DateTime.parse(initialDate)
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      await controller.setDate(targetDate);

      expect(fakeRepo.overviewCallCount, 1);
      expect(fakeRepo.reportCallCount, 1);
      expect(fakeRepo.behaviorCallCount, 1);
      expect(fakeRepo.exerciseCallCount, 1);

      final state = container.read(healthDataControllerProvider('pet123'));
      expect(state.selectedDate, targetDate);
    });

    test('selectBehavior 不发起网络请求', () async {
      final controller =
          container.read(healthDataControllerProvider('pet123').notifier);
      await Future.delayed(Duration.zero);

      fakeRepo.overviewCallCount = 0;
      fakeRepo.reportCallCount = 0;
      fakeRepo.behaviorCallCount = 0;
      fakeRepo.exerciseCallCount = 0;

      controller.selectBehavior('walk');

      expect(fakeRepo.overviewCallCount, 0);
      expect(fakeRepo.reportCallCount, 0);
      expect(fakeRepo.behaviorCallCount, 0);
      expect(fakeRepo.exerciseCallCount, 0);

      final state = container.read(healthDataControllerProvider('pet123'));
      expect(state.selectedBehavior, 'walk');
    });

    test('单个段失败不影响其他段的数据', () async {
      fakeRepo.reportResult = Failure(ApiException(
        message: 'Network error',
        statusCode: 500,
      ));

      container.read(healthDataControllerProvider('pet123').notifier);
      await Future.delayed(Duration.zero);

      final state = container.read(healthDataControllerProvider('pet123'));

      expect(state.overview.data, isNotNull, reason: 'overview 应成功');
      expect(state.report.error, isNotNull, reason: 'report 应失败');
      expect(state.behavior.data, isNotNull, reason: 'behavior 应成功');
      expect(state.exercise.data, isNotNull, reason: 'exercise 应成功');
    });

    test('retryOverview 只重新加载 overview 段', () async {
      final controller =
          container.read(healthDataControllerProvider('pet123').notifier);
      await Future.delayed(Duration.zero);

      fakeRepo.overviewCallCount = 0;
      fakeRepo.reportCallCount = 0;
      fakeRepo.behaviorCallCount = 0;
      fakeRepo.exerciseCallCount = 0;

      await controller.retryOverview();

      expect(fakeRepo.overviewCallCount, 1);
      expect(fakeRepo.reportCallCount, 0);
      expect(fakeRepo.behaviorCallCount, 0);
      expect(fakeRepo.exerciseCallCount, 0);
    });
  });
}
