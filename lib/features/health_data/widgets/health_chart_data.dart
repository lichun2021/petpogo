import '../data/models/health_data_models.dart';
import 'health_charts.dart';

/// API dates and hours are Beijing wall time. Do not shift ISO timestamps to
/// the host's timezone when labelling their daily/hourly buckets.
int? healthHour(String value) {
  final match = RegExp(r'(?:^|T)(\d{1,2}):').firstMatch(value);
  return match == null ? int.tryParse(value) : int.tryParse(match.group(1)!);
}

String healthDateLabel(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  return match == null
      ? value
      : '${int.parse(match.group(2)!)}/${int.parse(match.group(3)!)}';
}

String healthRangeLabel(TimeRange range) {
  // [start, end): labels name the actual included dates, not the exclusive end.
  final start = range.start.split('T').first;
  final end = DateTime.tryParse(range.end.split('T').first);
  if (end == null) return '$start — ${range.end}（不含）';
  final includedEnd = end.subtract(const Duration(days: 1));
  final last =
      '${includedEnd.year}-${includedEnd.month.toString().padLeft(2, '0')}-${includedEnd.day.toString().padLeft(2, '0')}';
  return start == last ? start : '$start — $last';
}

List<HealthChartPoint> healthHourlyPoints(List<HourlyBucket> buckets) =>
    List.generate(24, (hour) {
      final matches = buckets.where((b) => healthHour(b.hour) == hour).toList();
      final value = matches.isEmpty
          ? null
          : matches.fold<int>(0, (sum, b) => sum + b.durationSeconds) / 60;
      return HealthChartPoint(
          '$hour时', value, value == null ? '—' : value.toStringAsFixed(2));
    });

List<HealthChartPoint> healthBaselinePoints(
    BehaviorAnalysis? data, String? behavior) {
  final days = [...?data?.baseline.dailyBehaviorDistribution]
    ..sort((a, b) => a.date.compareTo(b.date));
  // The server already fills the half-open baseline interval, including zero
  // days. Render exactly those buckets; never append the current period.
  return days.map((day) {
    final seconds = day.behaviors[behavior]?.durationSeconds;
    return HealthChartPoint(
        healthDateLabel(day.date),
        seconds == null ? null : seconds / 60,
        seconds == null ? '—' : (seconds / 60).toStringAsFixed(2));
  }).toList();
}

List<HealthChartPoint> healthWalkingPoints(ExerciseData? data, String period) {
  final buckets = data?.timeline ?? <TimelineBucket>[];
  if (period == 'day') {
    return List.generate(24, (hour) {
      final matches = buckets.where((b) => healthHour(b.time) == hour).toList();
      final value = matches.isEmpty
          ? null
          : matches.fold<int>(0, (sum, b) => sum + b.reportCount);
      return HealthChartPoint(
          '$hour时', value?.toDouble(), value == null ? '—' : '$value');
    });
  }
  final sorted = [...buckets]..sort((a, b) => a.time.compareTo(b.time));
  return sorted
      .map((b) => HealthChartPoint(healthDateLabel(b.time),
          b.reportCount.toDouble(), '${b.reportCount}'))
      .toList();
}
