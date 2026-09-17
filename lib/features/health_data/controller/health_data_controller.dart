import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petpogo_app/features/health_data/data/models/health_data_models.dart';
import 'package:petpogo_app/features/health_data/data/repository/health_data_repository.dart';

// ═════════════════════════════════════════════════════════════════════════════
// State
// ═════════════════════════════════════════════════════════════════════════════

/// 单个数据段的加载状态（overview/report/behavior/exercise 各自独立）
class SectionState<T> {
  final bool isLoading;
  final T? data;
  final Exception? error;

  const SectionState({
    this.isLoading = false,
    this.data,
    this.error,
  });

  SectionState<T> copyWith({
    bool? isLoading,
    T? data,
    Exception? error,
  }) {
    return SectionState<T>(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }

  /// 设置为加载中（清除旧错误）
  SectionState<T> loading() => SectionState<T>(isLoading: true, data: data);

  /// 设置为成功（清除错误和 loading）
  SectionState<T> success(T newData) =>
      SectionState<T>(isLoading: false, data: newData, error: null);

  /// 设置为失败（保留旧数据，清除 loading）
  SectionState<T> failure(Exception e) =>
      SectionState<T>(isLoading: false, data: data, error: e);
}

/// HealthDataController 的完整状态
class HealthDataState {
  final String petId;
  final String selectedDate; // YYYY-MM-DD，默认今天
  final String selectedPeriod; // 'day' | 'week' | 'month'，默认 'day'
  final String? selectedBehavior; // 当前选中的行为代码（从已加载的 behavior analysis 读取）

  final SectionState<HealthOverview> overview;
  final SectionState<HealthReport> report;
  final SectionState<BehaviorAnalysis> behavior;
  final SectionState<ExerciseData> exercise;

  const HealthDataState({
    required this.petId,
    required this.selectedDate,
    this.selectedPeriod = 'day',
    this.selectedBehavior,
    this.overview = const SectionState(),
    this.report = const SectionState(),
    this.behavior = const SectionState(),
    this.exercise = const SectionState(),
  });

  HealthDataState copyWith({
    String? selectedDate,
    String? selectedPeriod,
    String? selectedBehavior,
    SectionState<HealthOverview>? overview,
    SectionState<HealthReport>? report,
    SectionState<BehaviorAnalysis>? behavior,
    SectionState<ExerciseData>? exercise,
  }) {
    return HealthDataState(
      petId: petId,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      selectedBehavior: selectedBehavior ?? this.selectedBehavior,
      overview: overview ?? this.overview,
      report: report ?? this.report,
      behavior: behavior ?? this.behavior,
      exercise: exercise ?? this.exercise,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Controller
// ═════════════════════════════════════════════════════════════════════════════

class HealthDataController extends StateNotifier<HealthDataState> {
  final HealthDataRepository _repository;

  HealthDataController(String petId, this._repository)
      : super(HealthDataState(
          petId: petId,
          selectedDate: _todayString(),
        )) {
    // 初始化时加载全部四个段（overview/report 不依赖 period，behavior/exercise 依赖 period）
    _fetchAll();
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── 初始加载全部四段 ────────────────────────────────────────────────────
  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchOverview(),
      _fetchReport(),
      _fetchBehavior(),
      _fetchExercise(),
    ]);
  }

  // ── 独立 fetch 方法（供初始化和 retry 使用）──────────────────────────
  Future<void> _fetchOverview() async {
    state = state.copyWith(overview: state.overview.loading());
    final result = await _repository.fetchOverview(
      petId: state.petId,
      date: state.selectedDate,
    );
    state = state.copyWith(
      overview: result.when(
        success: (data) => state.overview.success(data),
        failure: (error) => state.overview.failure(error),
      ),
    );
  }

  Future<void> _fetchReport() async {
    state = state.copyWith(report: state.report.loading());
    final result = await _repository.fetchHealthReport(
      petId: state.petId,
      date: state.selectedDate,
    );
    state = state.copyWith(
      report: result.when(
        success: (data) => state.report.success(data),
        failure: (error) => state.report.failure(error),
      ),
    );
  }

  Future<void> _fetchBehavior() async {
    state = state.copyWith(behavior: state.behavior.loading());
    final result = await _repository.fetchBehaviorAnalysis(
      petId: state.petId,
      date: state.selectedDate,
      period: state.selectedPeriod,
    );
    state = state.copyWith(
      behavior: result.when(
        success: (data) => state.behavior.success(data),
        failure: (error) => state.behavior.failure(error),
      ),
    );
  }

  Future<void> _fetchExercise() async {
    state = state.copyWith(exercise: state.exercise.loading());
    final result = await _repository.fetchExerciseData(
      petId: state.petId,
      date: state.selectedDate,
      period: state.selectedPeriod,
    );
    state = state.copyWith(
      exercise: result.when(
        success: (data) => state.exercise.success(data),
        failure: (error) => state.exercise.failure(error),
      ),
    );
  }

  // ── 公共方法：设置日期（触发全部四段重新加载）─────────────────────────
  Future<void> setDate(String date) async {
    if (date == state.selectedDate) return;
    state = state.copyWith(selectedDate: date);
    await _fetchAll();
  }

  // ── 公共方法：设置 period（只重新加载 behavior + exercise）─────────────
  Future<void> setPeriod(String period) async {
    if (period == state.selectedPeriod) return;
    state = state.copyWith(selectedPeriod: period);
    await Future.wait([_fetchBehavior(), _fetchExercise()]);
  }

  // ── 公共方法：选择行为标签（纯本地状态更新，不重新加载）───────────────
  void selectBehavior(String behaviorCode) {
    state = state.copyWith(selectedBehavior: behaviorCode);
  }

  // ── 公共方法：按段重试（单独重新加载某一段）────────────────────────────
  Future<void> retryOverview() => _fetchOverview();
  Future<void> retryReport() => _fetchReport();
  Future<void> retryBehavior() => _fetchBehavior();
  Future<void> retryExercise() => _fetchExercise();
}

// ═════════════════════════════════════════════════════════════════════════════
// Provider
// ═════════════════════════════════════════════════════════════════════════════

final healthDataControllerProvider = StateNotifierProvider.family<
    HealthDataController, HealthDataState, String>(
  (ref, petId) {
    return HealthDataController(
      petId,
      ref.read(healthDataRepositoryProvider),
    );
  },
);
