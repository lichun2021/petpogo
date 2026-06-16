/// 视频流自动 AI 分析 — 数据模型（save & disable）
library;

// ── 设置模型 ──────────────────────────────────────────────

class AutoAnalysisSetting {
  final int id;
  final String account;
  final String deviceNo;
  final String effectiveStartTime; // HH:MM
  final String effectiveEndTime;   // HH:MM
  final List<int> repeatWeekdays;  // 1=周一…7=周日
  final int dailyAnalysisCount;
  final bool enabled;
  final String createdAt;
  final String updatedAt;

  const AutoAnalysisSetting({
    required this.id,
    required this.account,
    required this.deviceNo,
    required this.effectiveStartTime,
    required this.effectiveEndTime,
    required this.repeatWeekdays,
    required this.dailyAnalysisCount,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AutoAnalysisSetting.fromJson(Map<String, dynamic> j) =>
      AutoAnalysisSetting(
        id: (j['id'] as num).toInt(),
        account: j['account'] as String? ?? '',
        deviceNo: j['device_no'] as String? ?? '',
        effectiveStartTime: j['effective_start_time'] as String? ?? '',
        effectiveEndTime: j['effective_end_time'] as String? ?? '',
        repeatWeekdays: (j['repeat_weekdays'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [],
        dailyAnalysisCount: (j['daily_analysis_count'] as num?)?.toInt() ?? 1,
        enabled: j['enabled'] as bool? ?? true,
        createdAt: j['created_at'] as String? ?? '',
        updatedAt: j['updated_at'] as String? ?? '',
      );
}

// ── 保存响应（含预创建统计）────────────────────────────────

class AutoAnalysisSaveResult {
  final AutoAnalysisSetting setting;
  final int canceledPendingTasks;
  final int canceledRuntimeTasks;
  final int precreatedTasks;

  const AutoAnalysisSaveResult({
    required this.setting,
    required this.canceledPendingTasks,
    required this.canceledRuntimeTasks,
    required this.precreatedTasks,
  });

  factory AutoAnalysisSaveResult.fromJson(Map<String, dynamic> j) =>
      AutoAnalysisSaveResult(
        setting: AutoAnalysisSetting.fromJson(j),
        canceledPendingTasks: (j['canceled_pending_tasks'] as num?)?.toInt() ?? 0,
        canceledRuntimeTasks: (j['canceled_runtime_tasks'] as num?)?.toInt() ?? 0,
        precreatedTasks: (j['precreated_tasks'] as num?)?.toInt() ?? 0,
      );
}

// ── 任务摘要（tasks[] 子项）────────────────────────────────

class AutoAnalysisTaskSummary {
  final String taskId;
  final String startAt;           // YYYY-MM-DD HH:mm:ss
  final String? scheduledStartAt;
  final double durationSeconds;
  final int dailyAnalysisCount;
  final String status;            // pending / running / success / failed / canceled
  final int executedCount;

  const AutoAnalysisTaskSummary({
    required this.taskId,
    required this.startAt,
    this.scheduledStartAt,
    required this.durationSeconds,
    required this.dailyAnalysisCount,
    required this.status,
    required this.executedCount,
  });

  factory AutoAnalysisTaskSummary.fromJson(Map<String, dynamic> j) =>
      AutoAnalysisTaskSummary(
        taskId: j['task_id'] as String? ?? '',
        startAt: j['start_at'] as String? ?? '',
        scheduledStartAt: j['scheduled_start_at'] as String?,
        durationSeconds: (j['duration_seconds'] as num?)?.toDouble() ?? 0,
        dailyAnalysisCount: (j['daily_analysis_count'] as num?)?.toInt() ?? 1,
        status: j['status'] as String? ?? '',
        executedCount: (j['executed_count'] as num?)?.toInt() ?? 0,
      );
}

// ── tasks 接口响应（setting? + tasks[]）───────────────────

class AutoAnalysisTasksResult {
  final AutoAnalysisSetting? setting;
  final List<AutoAnalysisTaskSummary> tasks;

  const AutoAnalysisTasksResult({this.setting, required this.tasks});

  factory AutoAnalysisTasksResult.fromJson(Map<String, dynamic> j) =>
      AutoAnalysisTasksResult(
        setting: j['setting'] != null
            ? AutoAnalysisSetting.fromJson(
                (j['setting'] as Map).cast<String, dynamic>())
            : null,
        tasks: (j['tasks'] as List? ?? const [])
            .whereType<Map>()
            .map((e) =>
                AutoAnalysisTaskSummary.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}
