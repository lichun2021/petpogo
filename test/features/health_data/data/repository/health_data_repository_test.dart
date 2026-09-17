import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/api_exception.dart';
import 'package:petpogo_app/core/api/result.dart';
import 'package:petpogo_app/features/health_data/data/models/health_data_models.dart';
import 'package:petpogo_app/features/health_data/data/repository/health_data_repository.dart';

/// Fake ApiClient that records the last call and returns a canned response or throws
class _FakeClient implements ApiClient {
  String? lastPath;
  dynamic lastData;
  dynamic response;
  Exception? throwOnPost;

  @override
  Future<T> post<T>(String path,
      {dynamic data, T Function(dynamic)? fromJson, Options? options}) async {
    lastPath = path;
    lastData = data;
    if (throwOnPost != null) throw throwOnPost!;
    return fromJson != null ? fromJson(response) : response as T;
  }

  @override
  Future<T> get<T>(String path,
          {Map<String, dynamic>? params, T Function(dynamic)? fromJson}) =>
      throw UnimplementedError();

  @override
  Future<T> put<T>(String path,
          {dynamic data, T Function(dynamic)? fromJson}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String path) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('HealthDataRepository', () {
    const petId = '12345';
    const date = '2026-09-16';

    // ── fetchOverview ──────────────────────────────────
    test('fetchOverview parses success response correctly', () async {
      final client = _FakeClient()
        ..response = {
          'code': 0,
          'info': {
            'pet_id': petId,
            'period': 'day',
            'report_date': date,
            'behavior_analysis': {
              'total_report_count': 288,
              'behaviors': [
                {
                  'behavior': 'sleep',
                  'name': '睡觉',
                  'category': 'rest',
                  'report_count': 120,
                  'ratio': 0.42,
                  'average_confidence': 0.88
                },
                {
                  'behavior': 'sit',
                  'name': '坐着',
                  'category': 'rest',
                  'report_count': 60,
                  'ratio': 0.21,
                  'average_confidence': null
                },
              ],
            },
            'exercise_data': {
              'walking_report_count': 48,
              'exercise_report_count': 48,
              'exercise_ratio': 0.17,
              'steps': 3200,
              'calories_kcal': 85.5
            },
            'health_status': {
              'sleep_quality': {
                'status': 'stable',
                'current_ratio': 0.42,
                'baseline_ratio': 0.40,
                'delta': 0.02,
                'reason': '睡眠时间充足'
              },
              'rest_status': {
                'status': 'changed',
                'current_ratio': 0.63,
                'baseline_ratio': null,
                'delta': null,
                'reason': '休息行为占比增加'
              },
              'feeding_regularity': {
                'status': 'unknown',
                'current_ratio': null,
                'baseline_ratio': null,
                'delta': null,
                'reason': '数据不足'
              }
            },
            'data_quality': {
              'level': 'available',
              'total_report_count': 288,
              'valid_report_count': 288,
              'unsupported_report_count': 0,
              'observed_days': 15,
              'baseline_days': 14,
              'first_observed_at': '2026-09-01T00:00:00Z',
              'last_observed_at': '2026-09-16T23:55:00Z'
            },
            'disclaimer':
                '此数据基于设备上报,仅供参考。如有健康疑虑,请咨询专业兽医。'
          },
          'tip': 'success'
        };

      final repository = HealthDataRepository(client);
      final result = await repository.fetchOverview(petId: petId, date: date);

      expect(result.isSuccess, true);
      expect(client.lastData, {'pet_id': petId, 'date': date});

      result.when(
        success: (overview) {
          expect(overview.petId, petId);
          expect(overview.period, 'day');
          expect(overview.reportDate, date);
          expect(overview.behaviorAnalysis.totalReportCount, 288);
          expect(overview.behaviorAnalysis.behaviors.length, 2);
          expect(overview.behaviorAnalysis.behaviors[0].name, '睡觉');
          expect(overview.exerciseData.exerciseRatio, 0.17);
          expect(overview.exerciseData.steps, 3200);
          expect(overview.healthStatus.sleepQuality.status,
              HealthStatus.stable);
          expect(overview.dataQuality.level, DataQualityLevel.available);
          expect(overview.disclaimer, contains('仅供参考'));
        },
        failure: (_) => fail('Expected success'),
      );
    });

    test('fetchOverview rewrites 422 validation error', () async {
      final client = _FakeClient()
        ..throwOnPost = ApiException(
          message: 'Validation error: field required',
          type: ApiErrorType.server,
          statusCode: 422,
        );

      final repository = HealthDataRepository(client);
      final result = await repository.fetchOverview(petId: petId);

      expect(result.isError, true);
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (error) {
          expect(error, isA<ApiException>());
          final apiError = error as ApiException;
          expect(apiError.statusCode, 422);
          expect(apiError.message, '请求参数有误，请重试');
        },
      );
    });

    test('fetchOverview handles data_quality.level="none"', () async {
      final client = _FakeClient()
        ..response = {
          'code': 0,
          'info': {
            'pet_id': petId,
            'period': 'day',
            'report_date': date,
            'behavior_analysis': {
              'total_report_count': 0,
              'behaviors': []
            },
            'exercise_data': {
              'walking_report_count': 0,
              'exercise_report_count': 0,
              'exercise_ratio': 0.0,
              'steps': null,
              'calories_kcal': null
            },
            'health_status': {
              'sleep_quality': {
                'status': 'unknown',
                'current_ratio': null,
                'baseline_ratio': null,
                'delta': null,
                'reason': '数据不足'
              },
              'rest_status': {
                'status': 'unknown',
                'current_ratio': null,
                'baseline_ratio': null,
                'delta': null,
                'reason': '数据不足'
              },
              'feeding_regularity': {
                'status': 'unknown',
                'current_ratio': null,
                'baseline_ratio': null,
                'delta': null,
                'reason': '数据不足'
              }
            },
            'data_quality': {
              'level': 'none',
              'total_report_count': 0,
              'valid_report_count': 0,
              'unsupported_report_count': 0,
              'observed_days': 0,
              'baseline_days': 0,
              'first_observed_at': null,
              'last_observed_at': null
            },
            'disclaimer': '此数据基于设备上报，仅供参考。'
          },
          'tip': 'success'
        };

      final repository = HealthDataRepository(client);
      final result = await repository.fetchOverview(petId: petId);

      expect(result.isSuccess, true);
      result.when(
        success: (overview) {
          expect(overview.dataQuality.level, DataQualityLevel.none);
          expect(overview.dataQuality.totalReportCount, 0);
          expect(overview.behaviorAnalysis.behaviors, isEmpty);
        },
        failure: (_) => fail('Expected success'),
      );
    });

    // ── fetchHealthReport ──────────────────────────────
    test('fetchHealthReport parses success response correctly', () async {
      final client = _FakeClient()
        ..response = {
          'code': 0,
          'info': {
            'pet_id': petId,
            'report_date': date,
            'data_overview': {
              'summary': '今日整体活动正常，休息与运动比例健康。',
              'observations': ['睡眠充足', '运动量适中'],
              'suggestions': ['保持当前作息', '适当增加互动玩耍时间'],
              'ai_generated': true
            },
            'trend': {
              'range': {
                'start': '2026-09-16T00:00:00Z',
                'end': '2026-09-16T23:59:59Z'
              },
              'total_duration_seconds': 86400,
              'categories': {
                'rest': {
                  'duration_seconds': 54432,
                  'ratio': 0.63,
                  'hourly': [
                    {'hour': '00', 'duration_seconds': 3600, 'ratio': 1.0},
                    {'hour': '01', 'duration_seconds': 3600, 'ratio': 1.0},
                  ]
                },
                'exercise': {
                  'duration_seconds': 14688,
                  'ratio': 0.17,
                  'hourly': [
                    {'hour': '00', 'duration_seconds': 0, 'ratio': 0.0},
                    {'hour': '01', 'duration_seconds': 300, 'ratio': 0.08},
                  ]
                },
                'behavior': {
                  'duration_seconds': 17280,
                  'ratio': 0.20,
                  'hourly': [
                    {'hour': '00', 'duration_seconds': 0, 'ratio': 0.0},
                    {'hour': '01', 'duration_seconds': 0, 'ratio': 0.0},
                  ]
                }
              }
            },
            'disclaimer': '此数据基于设备上报，仅供参考。'
          },
          'tip': 'success'
        };

      final repository = HealthDataRepository(client);
      final result =
          await repository.fetchHealthReport(petId: petId, date: date);

      expect(result.isSuccess, true);
      result.when(
        success: (report) {
          expect(report.petId, petId);
          expect(report.reportDate, date);
          expect(report.dataOverview.summary, contains('整体活动正常'));
          expect(report.dataOverview.observations.length, 2);
          expect(report.dataOverview.aiGenerated, true);
          expect(report.trend.totalDurationSeconds, 86400);
          expect(report.trend.categories.rest.ratio, 0.63);
          expect(report.trend.categories.rest.hourly.length, 2);
          expect(report.disclaimer, contains('仅供参考'));
        },
        failure: (_) => fail('Expected success'),
      );
    });

    // ── fetchBehaviorAnalysis ──────────────────────────
    test('fetchBehaviorAnalysis parses success response correctly', () async {
      final client = _FakeClient()
        ..response = {
          'code': 0,
          'info': {
            'pet_id': petId,
            'period': 'week',
            'range': {'start': '2026-09-10', 'end': '2026-09-16'},
            'total_report_count': 2016,
            'behaviors': [
              {
                'behavior': 'sleep',
                'name': '睡觉',
                'category': 'rest',
                'report_count': 840,
                'ratio': 0.42,
                'duration_seconds': 302400,
                'baseline_ratio': 0.40
              },
              {
                'behavior': 'walk',
                'name': '散步',
                'category': 'exercise',
                'report_count': 336,
                'ratio': 0.17,
                'duration_seconds': 120960,
                'baseline_ratio': null
              }
            ],
            'baseline': {
              'start': '2026-09-01',
              'end': '2026-09-14',
              'days': 14,
              'required_days': 14,
              'unlocked': true,
              'behaviors': {
                'sleep': {'ratio': 0.40, 'duration_seconds': 290000},
                'walk': {'ratio': null, 'duration_seconds': null}
              },
              'daily_behavior_distribution': [
                {
                  'date': '2026-09-01',
                  'total_duration_seconds': 86400,
                  'behaviors': {
                    'sleep': {'report_count': 120, 'duration_seconds': 43200}
                  }
                }
              ]
            },
            'disclaimer': '此数据基于设备上报，仅供参考。'
          },
          'tip': 'success'
        };

      final repository = HealthDataRepository(client);
      final result = await repository.fetchBehaviorAnalysis(
          petId: petId, date: date, period: 'week');

      expect(result.isSuccess, true);
      result.when(
        success: (analysis) {
          expect(analysis.petId, petId);
          expect(analysis.period, 'week');
          expect(analysis.totalReportCount, 2016);
          expect(analysis.behaviors.length, 2);
          expect(analysis.behaviors[0].name, '睡觉');
          expect(analysis.behaviors[0].baselineRatio, 0.40);
          expect(analysis.baseline.unlocked, true);
          expect(analysis.baseline.requiredDays, 14);
          expect(analysis.baseline.behaviors['sleep']?.ratio, 0.40);
          expect(analysis.baseline.dailyBehaviorDistribution.length, 1);
          expect(analysis.disclaimer, contains('仅供参考'));
        },
        failure: (_) => fail('Expected success'),
      );
    });

    // ── fetchExerciseData ──────────────────────────────
    test('fetchExerciseData parses success response correctly', () async {
      final client = _FakeClient()
        ..response = {
          'code': 0,
          'info': {
            'pet_id': petId,
            'period': 'day',
            'range': {
              'start': '2026-09-16T00:00:00Z',
              'end': '2026-09-16T23:59:59Z'
            },
            'summary': {
              'walking_report_count': 48,
              'exercise_report_count': 48,
              'exercise_ratio': 0.17,
              'steps': 3200,
              'calories_kcal': 85.5
            },
            'timeline': [
              {
                'time': '00',
                'report_count': 0,
                'behaviors': {'walk': 0, 'run': 0}
              },
              {
                'time': '08',
                'report_count': 12,
                'behaviors': {'walk': 10, 'run': 2}
              }
            ],
            'data_quality': {
              'level': 'available',
              'total_report_count': 288,
              'valid_report_count': 288,
              'unsupported_report_count': 0,
              'observed_days': 15,
              'baseline_days': 14,
              'first_observed_at': '2026-09-01T00:00:00Z',
              'last_observed_at': '2026-09-16T23:55:00Z'
            },
            'unavailable_metrics': ['步数和卡路里消耗需要设备支持计步功能'],
            'disclaimer': '此数据基于设备上报，仅供参考。'
          },
          'tip': 'success'
        };

      final repository = HealthDataRepository(client);
      final result =
          await repository.fetchExerciseData(petId: petId, period: 'day');

      expect(result.isSuccess, true);
      result.when(
        success: (data) {
          expect(data.petId, petId);
          expect(data.period, 'day');
          expect(data.summary.exerciseRatio, 0.17);
          expect(data.summary.steps, 3200);
          expect(data.timeline.length, 2);
          expect(data.timeline[1].time, '08');
          expect(data.timeline[1].behaviors['walk'], 10);
          expect(data.dataQuality.level, DataQualityLevel.available);
          expect(data.unavailableMetrics.length, 1);
          expect(data.unavailableMetrics[0], contains('计步功能'));
          expect(data.disclaimer, contains('仅供参考'));
        },
        failure: (_) => fail('Expected success'),
      );
    });
  });
}
