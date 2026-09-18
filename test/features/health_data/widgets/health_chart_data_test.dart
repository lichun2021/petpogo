import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/health_data/data/models/health_data_models.dart';
import 'package:petpogo_app/features/health_data/widgets/health_chart_data.dart';

void main() {
  final examples = jsonDecode(
      File('test/features/health_data/fixtures/health_api_examples.json')
          .readAsStringSync()) as Map<String, dynamic>;
  test(
      'document report categories retain their estimated seconds and hourly zeroes',
      () {
    final report = HealthReport.fromJson(examples['report']);
    expect(report.trend.categories.rest.durationSeconds, 1200);
    expect(report.trend.categories.exercise.durationSeconds, 900);
    expect(report.trend.categories.behavior.durationSeconds, 1500);
    final rest = healthHourlyPoints(report.trend.categories.rest.hourly);
    expect(rest.length, 24);
    expect(rest[0].value, 0);
    expect(rest[1].value, 2);
    // The documentation intentionally omits these buckets; do not invent values.
    expect(rest[2].value, isNull);
  });
  test('walking curve contains only walking counts and preserves zero buckets',
      () {
    final data = ExerciseData.fromJson(examples['exercise']);
    final points = healthWalkingPoints(data, data.period);
    expect(points[0].value, 0);
    expect(points[8].value, 25);
    expect(points[9].value, 18);
    expect(data.summary.steps, isNull);
    expect(data.summary.caloriesKcal, isNull);
  });
  test('baseline uses only returned dates and preserves zero-duration days',
      () {
    final json =
        jsonDecode(jsonEncode(examples['behavior'])) as Map<String, dynamic>;
    json['baseline']['daily_behavior_distribution'].add({
      'date': '2026-09-06',
      'total_duration_seconds': 0,
      'behaviors': {
        'lying': {'report_count': 0, 'duration_seconds': 0}
      },
    });
    final data = BehaviorAnalysis.fromJson(json);
    final points = healthBaselinePoints(data, 'lying');
    expect(points.map((p) => p.label), ['9/5', '9/6']);
    expect(points[0].value, 8);
    expect(points[1].value, 0);
    expect(points.any((p) => p.label == '9/14'), isFalse);
  });
  test(
      'Beijing labels and exclusive period endpoints do not shift with timezone',
      () {
    expect(healthHour('2026-09-16T00:00:00+08:00'), 0);
    expect(healthDateLabel('2026-09-16T00:00:00+08:00'), '9/16');
    expect(
        healthRangeLabel(const TimeRange(
            start: '2026-09-14T00:00:00+08:00',
            end: '2026-09-21T00:00:00+08:00')),
        '2026-09-14 — 2026-09-20');
  });
}
