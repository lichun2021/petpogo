/// 健康数据模型
///
/// 对应 AI 服务器的四个健康数据接口响应结构。

/// 数据质量等级
enum DataQualityLevel {
  none,      // 完全无上报
  partial,   // 存在不支持标签
  available; // 存在上报且标签全部受支持

  static DataQualityLevel fromString(String value) {
    return DataQualityLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DataQualityLevel.none,
    );
  }
}

/// 健康状态
enum HealthStatus {
  stable,            // 稳定
  changed,           // 变化
  significantChange, // 显著变化
  unknown;           // 未知

  static HealthStatus fromString(String value) {
    switch (value) {
      case 'stable':
        return HealthStatus.stable;
      case 'changed':
        return HealthStatus.changed;
      case 'significant_change':
        return HealthStatus.significantChange;
      case 'unknown':
      default:
        return HealthStatus.unknown;
    }
  }
}

/// 数据质量信息
class DataQuality {
  final DataQualityLevel level;
  final int totalReportCount;
  final int validReportCount;
  final int unsupportedReportCount;
  final int observedDays;
  final int baselineDays;
  final String? firstObservedAt;
  final String? lastObservedAt;

  const DataQuality({
    required this.level,
    required this.totalReportCount,
    required this.validReportCount,
    required this.unsupportedReportCount,
    required this.observedDays,
    required this.baselineDays,
    this.firstObservedAt,
    this.lastObservedAt,
  });

  factory DataQuality.fromJson(Map<String, dynamic> json) {
    return DataQuality(
      level: DataQualityLevel.fromString(json['level'] as String),
      totalReportCount: json['total_report_count'] as int,
      validReportCount: json['valid_report_count'] as int,
      unsupportedReportCount: json['unsupported_report_count'] as int,
      observedDays: json['observed_days'] as int,
      baselineDays: json['baseline_days'] as int,
      firstObservedAt: json['first_observed_at'] as String?,
      lastObservedAt: json['last_observed_at'] as String?,
    );
  }
}

/// 健康状态条目
class HealthStatusEntry {
  final HealthStatus status;
  final double? currentRatio;
  final double? baselineRatio;
  final double? delta;
  final String reason;

  const HealthStatusEntry({
    required this.status,
    this.currentRatio,
    this.baselineRatio,
    this.delta,
    required this.reason,
  });

  factory HealthStatusEntry.fromJson(Map<String, dynamic> json) {
    return HealthStatusEntry(
      status: HealthStatus.fromString(json['status'] as String),
      currentRatio: (json['current_ratio'] as num?)?.toDouble(),
      baselineRatio: (json['baseline_ratio'] as num?)?.toDouble(),
      delta: (json['delta'] as num?)?.toDouble(),
      reason: json['reason'] as String,
    );
  }
}

/// 行为条目
class BehaviorEntry {
  final String behavior;
  final String name;
  final String category;
  final int reportCount;
  final double ratio;
  final double? averageConfidence;

  const BehaviorEntry({
    required this.behavior,
    required this.name,
    required this.category,
    required this.reportCount,
    required this.ratio,
    this.averageConfidence,
  });

  factory BehaviorEntry.fromJson(Map<String, dynamic> json) {
    return BehaviorEntry(
      behavior: json['behavior'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      reportCount: json['report_count'] as int,
      ratio: (json['ratio'] as num).toDouble(),
      averageConfidence: (json['average_confidence'] as num?)?.toDouble(),
    );
  }
}

/// 健康数据概览
class HealthOverview {
  final String petId;
  final String period;
  final String reportDate;
  final BehaviorAnalysisSummary behaviorAnalysis;
  final ExerciseDataSummary exerciseData;
  final HealthStatusInfo healthStatus;
  final DataQuality dataQuality;
  final String disclaimer;

  const HealthOverview({
    required this.petId,
    required this.period,
    required this.reportDate,
    required this.behaviorAnalysis,
    required this.exerciseData,
    required this.healthStatus,
    required this.dataQuality,
    required this.disclaimer,
  });

  factory HealthOverview.fromJson(Map<String, dynamic> json) {
    return HealthOverview(
      petId: json['pet_id'] as String,
      period: json['period'] as String,
      reportDate: json['report_date'] as String,
      behaviorAnalysis: BehaviorAnalysisSummary.fromJson(
          json['behavior_analysis'] as Map<String, dynamic>),
      exerciseData: ExerciseDataSummary.fromJson(
          json['exercise_data'] as Map<String, dynamic>),
      healthStatus: HealthStatusInfo.fromJson(
          json['health_status'] as Map<String, dynamic>),
      dataQuality:
          DataQuality.fromJson(json['data_quality'] as Map<String, dynamic>),
      disclaimer: json['disclaimer'] as String,
    );
  }
}

/// 行为分析汇总（概览中的子结构）
class BehaviorAnalysisSummary {
  final int totalReportCount;
  final List<BehaviorEntry> behaviors;

  const BehaviorAnalysisSummary({
    required this.totalReportCount,
    required this.behaviors,
  });

  factory BehaviorAnalysisSummary.fromJson(Map<String, dynamic> json) {
    return BehaviorAnalysisSummary(
      totalReportCount: json['total_report_count'] as int,
      behaviors: (json['behaviors'] as List)
          .map((e) => BehaviorEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 运动数据汇总（概览中的子结构）
class ExerciseDataSummary {
  final int walkingReportCount;
  final int exerciseReportCount;
  final double exerciseRatio;
  final int? steps;
  final double? caloriesKcal;

  const ExerciseDataSummary({
    required this.walkingReportCount,
    required this.exerciseReportCount,
    required this.exerciseRatio,
    this.steps,
    this.caloriesKcal,
  });

  factory ExerciseDataSummary.fromJson(Map<String, dynamic> json) {
    return ExerciseDataSummary(
      walkingReportCount: json['walking_report_count'] as int,
      exerciseReportCount: json['exercise_report_count'] as int,
      exerciseRatio: (json['exercise_ratio'] as num).toDouble(),
      steps: json['steps'] as int?,
      caloriesKcal: (json['calories_kcal'] as num?)?.toDouble(),
    );
  }
}

/// 健康状态信息
class HealthStatusInfo {
  final HealthStatusEntry sleepQuality;
  final HealthStatusEntry restStatus;
  final HealthStatusEntry feedingRegularity;

  const HealthStatusInfo({
    required this.sleepQuality,
    required this.restStatus,
    required this.feedingRegularity,
  });

  factory HealthStatusInfo.fromJson(Map<String, dynamic> json) {
    return HealthStatusInfo(
      sleepQuality: HealthStatusEntry.fromJson(
          json['sleep_quality'] as Map<String, dynamic>),
      restStatus: HealthStatusEntry.fromJson(
          json['rest_status'] as Map<String, dynamic>),
      feedingRegularity: HealthStatusEntry.fromJson(
          json['feeding_regularity'] as Map<String, dynamic>),
    );
  }
}

/// 健康数据报告
class HealthReport {
  final String petId;
  final String reportDate;
  final DataOverview dataOverview;
  final Trend trend;
  final String disclaimer;

  const HealthReport({
    required this.petId,
    required this.reportDate,
    required this.dataOverview,
    required this.trend,
    required this.disclaimer,
  });

  factory HealthReport.fromJson(Map<String, dynamic> json) {
    return HealthReport(
      petId: json['pet_id'] as String,
      reportDate: json['report_date'] as String,
      dataOverview:
          DataOverview.fromJson(json['data_overview'] as Map<String, dynamic>),
      trend: Trend.fromJson(json['trend'] as Map<String, dynamic>),
      disclaimer: json['disclaimer'] as String,
    );
  }
}

/// AI 数据概览
class DataOverview {
  final String summary;
  final List<String> observations;
  final List<String> suggestions;
  final bool aiGenerated;

  const DataOverview({
    required this.summary,
    required this.observations,
    required this.suggestions,
    required this.aiGenerated,
  });

  factory DataOverview.fromJson(Map<String, dynamic> json) {
    return DataOverview(
      summary: json['summary'] as String,
      observations: (json['observations'] as List).cast<String>(),
      suggestions: (json['suggestions'] as List).cast<String>(),
      aiGenerated: json['ai_generated'] as bool,
    );
  }
}

/// 趋势数据
class Trend {
  final TimeRange range;
  final int totalDurationSeconds;
  final TrendCategories categories;

  const Trend({
    required this.range,
    required this.totalDurationSeconds,
    required this.categories,
  });

  factory Trend.fromJson(Map<String, dynamic> json) {
    return Trend(
      range: TimeRange.fromJson(json['range'] as Map<String, dynamic>),
      totalDurationSeconds: json['total_duration_seconds'] as int,
      categories: TrendCategories.fromJson(
          json['categories'] as Map<String, dynamic>),
    );
  }
}

/// 时间范围
class TimeRange {
  final String start;
  final String end;

  const TimeRange({
    required this.start,
    required this.end,
  });

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      start: json['start'] as String,
      end: json['end'] as String,
    );
  }
}

/// 趋势分类数据
class TrendCategories {
  final TrendCategory rest;
  final TrendCategory exercise;
  final TrendCategory behavior;

  const TrendCategories({
    required this.rest,
    required this.exercise,
    required this.behavior,
  });

  factory TrendCategories.fromJson(Map<String, dynamic> json) {
    return TrendCategories(
      rest: TrendCategory.fromJson(json['rest'] as Map<String, dynamic>),
      exercise: TrendCategory.fromJson(json['exercise'] as Map<String, dynamic>),
      behavior: TrendCategory.fromJson(json['behavior'] as Map<String, dynamic>),
    );
  }
}

/// 趋势分类（rest/exercise/behavior）
class TrendCategory {
  final int durationSeconds;
  final double ratio;
  final List<HourlyBucket> hourly;

  const TrendCategory({
    required this.durationSeconds,
    required this.ratio,
    required this.hourly,
  });

  factory TrendCategory.fromJson(Map<String, dynamic> json) {
    return TrendCategory(
      durationSeconds: json['duration_seconds'] as int,
      ratio: (json['ratio'] as num).toDouble(),
      hourly: (json['hourly'] as List)
          .map((e) => HourlyBucket.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 小时桶
class HourlyBucket {
  final String hour;
  final int durationSeconds;
  final double ratio;

  const HourlyBucket({
    required this.hour,
    required this.durationSeconds,
    required this.ratio,
  });

  factory HourlyBucket.fromJson(Map<String, dynamic> json) {
    return HourlyBucket(
      hour: json['hour'] as String,
      durationSeconds: json['duration_seconds'] as int,
      ratio: (json['ratio'] as num).toDouble(),
    );
  }
}

/// 行为分析详情
class BehaviorAnalysis {
  final String petId;
  final String period;
  final TimeRange range;
  final int totalReportCount;
  final List<BehaviorDetail> behaviors;
  final BaselineInfo baseline;
  final String disclaimer;

  const BehaviorAnalysis({
    required this.petId,
    required this.period,
    required this.range,
    required this.totalReportCount,
    required this.behaviors,
    required this.baseline,
    required this.disclaimer,
  });

  factory BehaviorAnalysis.fromJson(Map<String, dynamic> json) {
    return BehaviorAnalysis(
      petId: json['pet_id'] as String,
      period: json['period'] as String,
      range: TimeRange.fromJson(json['range'] as Map<String, dynamic>),
      totalReportCount: json['total_report_count'] as int,
      behaviors: (json['behaviors'] as List)
          .map((e) => BehaviorDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
      baseline:
          BaselineInfo.fromJson(json['baseline'] as Map<String, dynamic>),
      disclaimer: json['disclaimer'] as String,
    );
  }
}

/// 行为详细信息
class BehaviorDetail {
  final String behavior;
  final String name;
  final String category;
  final int reportCount;
  final double ratio;
  final int durationSeconds;
  final double? baselineRatio;

  const BehaviorDetail({
    required this.behavior,
    required this.name,
    required this.category,
    required this.reportCount,
    required this.ratio,
    required this.durationSeconds,
    this.baselineRatio,
  });

  factory BehaviorDetail.fromJson(Map<String, dynamic> json) {
    return BehaviorDetail(
      behavior: json['behavior'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      reportCount: json['report_count'] as int,
      ratio: (json['ratio'] as num).toDouble(),
      durationSeconds: json['duration_seconds'] as int,
      baselineRatio: (json['baseline_ratio'] as num?)?.toDouble(),
    );
  }
}

/// 基准信息
class BaselineInfo {
  final String? start;
  final String end;
  final int days;
  final int requiredDays;
  final bool unlocked;
  final Map<String, BaselineBehavior> behaviors;
  final List<DailyBehaviorDistribution> dailyBehaviorDistribution;

  const BaselineInfo({
    this.start,
    required this.end,
    required this.days,
    required this.requiredDays,
    required this.unlocked,
    required this.behaviors,
    required this.dailyBehaviorDistribution,
  });

  factory BaselineInfo.fromJson(Map<String, dynamic> json) {
    final behaviorsMap = json['behaviors'] as Map<String, dynamic>;
    return BaselineInfo(
      start: json['start'] as String?,
      end: json['end'] as String,
      days: json['days'] as int,
      requiredDays: json['required_days'] as int,
      unlocked: json['unlocked'] as bool,
      behaviors: behaviorsMap.map(
        (key, value) => MapEntry(
          key,
          BaselineBehavior.fromJson(value as Map<String, dynamic>),
        ),
      ),
      dailyBehaviorDistribution:
          (json['daily_behavior_distribution'] as List)
              .map((e) =>
                  DailyBehaviorDistribution.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

/// 基准行为数据
class BaselineBehavior {
  final double? ratio;
  final int? durationSeconds;

  const BaselineBehavior({
    this.ratio,
    this.durationSeconds,
  });

  factory BaselineBehavior.fromJson(Map<String, dynamic> json) {
    return BaselineBehavior(
      ratio: (json['ratio'] as num?)?.toDouble(),
      durationSeconds: json['duration_seconds'] as int?,
    );
  }
}

/// 每日行为分布
class DailyBehaviorDistribution {
  final String date;
  final int totalDurationSeconds;
  final Map<String, DailyBehaviorEntry> behaviors;

  const DailyBehaviorDistribution({
    required this.date,
    required this.totalDurationSeconds,
    required this.behaviors,
  });

  factory DailyBehaviorDistribution.fromJson(Map<String, dynamic> json) {
    final behaviorsMap = json['behaviors'] as Map<String, dynamic>;
    return DailyBehaviorDistribution(
      date: json['date'] as String,
      totalDurationSeconds: json['total_duration_seconds'] as int,
      behaviors: behaviorsMap.map(
        (key, value) => MapEntry(
          key,
          DailyBehaviorEntry.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }
}

/// 每日行为条目
class DailyBehaviorEntry {
  final int reportCount;
  final int durationSeconds;

  const DailyBehaviorEntry({
    required this.reportCount,
    required this.durationSeconds,
  });

  factory DailyBehaviorEntry.fromJson(Map<String, dynamic> json) {
    return DailyBehaviorEntry(
      reportCount: json['report_count'] as int,
      durationSeconds: json['duration_seconds'] as int,
    );
  }
}

/// 运动数据详情
class ExerciseData {
  final String petId;
  final String period;
  final TimeRange range;
  final ExerciseSummary summary;
  final List<TimelineBucket> timeline;
  final DataQuality dataQuality;
  final List<String> unavailableMetrics;
  final String disclaimer;

  const ExerciseData({
    required this.petId,
    required this.period,
    required this.range,
    required this.summary,
    required this.timeline,
    required this.dataQuality,
    required this.unavailableMetrics,
    required this.disclaimer,
  });

  factory ExerciseData.fromJson(Map<String, dynamic> json) {
    return ExerciseData(
      petId: json['pet_id'] as String,
      period: json['period'] as String,
      range: TimeRange.fromJson(json['range'] as Map<String, dynamic>),
      summary:
          ExerciseSummary.fromJson(json['summary'] as Map<String, dynamic>),
      timeline: (json['timeline'] as List)
          .map((e) => TimelineBucket.fromJson(e as Map<String, dynamic>))
          .toList(),
      dataQuality:
          DataQuality.fromJson(json['data_quality'] as Map<String, dynamic>),
      unavailableMetrics:
          (json['unavailable_metrics'] as List).cast<String>(),
      disclaimer: json['disclaimer'] as String,
    );
  }
}

/// 运动汇总
class ExerciseSummary {
  final int walkingReportCount;
  final int exerciseReportCount;
  final double exerciseRatio;
  final int? steps;
  final double? caloriesKcal;

  const ExerciseSummary({
    required this.walkingReportCount,
    required this.exerciseReportCount,
    required this.exerciseRatio,
    this.steps,
    this.caloriesKcal,
  });

  factory ExerciseSummary.fromJson(Map<String, dynamic> json) {
    return ExerciseSummary(
      walkingReportCount: json['walking_report_count'] as int,
      exerciseReportCount: json['exercise_report_count'] as int,
      exerciseRatio: (json['exercise_ratio'] as num).toDouble(),
      steps: json['steps'] as int?,
      caloriesKcal: (json['calories_kcal'] as num?)?.toDouble(),
    );
  }
}

/// 时间线桶
class TimelineBucket {
  final String time;
  final int reportCount;
  final Map<String, int> behaviors;

  const TimelineBucket({
    required this.time,
    required this.reportCount,
    required this.behaviors,
  });

  factory TimelineBucket.fromJson(Map<String, dynamic> json) {
    return TimelineBucket(
      time: json['time'] as String,
      reportCount: json['report_count'] as int,
      behaviors: (json['behaviors'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as int),
      ),
    );
  }
}
