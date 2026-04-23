/// ════════════════════════════════════════════════════════════
///  结果封装类 — Result<T>
///
///  设计目的：
///    让 Controller 的返回值统一为 Result，而不是抛异常。
///    View 层用 .when() 处理成功/失败，不需要写 try/catch。
///
///  使用示例（Controller 里）：
///    Future<Result<PetModel>> addPet(PetModel pet) async {
///      return guardResult(() => _repo.addPet(pet));
///    }
///
///  使用示例（View 里）：
///    final result = await ref.read(petControllerProvider.notifier).addPet(pet);
///    result.when(
///      success: (_) => context.go(AppRoutes.profile),   // 成功 → 跳转
///      failure: (err) => showSnackBar(err.userMessage), // 失败 → 提示
///    );
/// ════════════════════════════════════════════════════════════

import 'api_exception.dart';

// ── 密封类（Dart 3 sealed）─────────────────────────────────
// sealed 保证只有 Success 和 Failure 两种子类
sealed class Result<T> {
  const Result();

  /// 是否成功
  bool get isSuccess => this is Success<T>;

  /// 是否失败
  bool get isError => this is Failure<T>;

  /// 成功时的数据（失败时返回 null）
  T? get value => isSuccess ? (this as Success<T>).data : null;

  /// 失败时的异常（成功时返回 null）
  ApiException? get error => isError ? (this as Failure<T>).exception : null;

  /// 链式处理：强制调用者同时处理成功和失败分支
  ///
  /// 类似 Kotlin 的 fold / Swift 的 switch，
  /// 比 isSuccess 判断更安全，不会漏掉错误处理。
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException error) failure,
  }) {
    if (this is Success<T>) return success((this as Success<T>).data);
    return failure((this as Failure<T>).exception);
  }
}

/// 成功状态 — 携带业务数据
class Success<T> extends Result<T> {
  /// 实际业务数据（如 PetModel、List<DeviceModel> 等）
  final T data;
  const Success(this.data);
}

/// 失败状态 — 携带统一的 ApiException
class Failure<T> extends Result<T> {
  /// 包含错误类型、状态码、用户友好提示
  final ApiException exception;
  const Failure(this.exception);
}

// ── 便捷包装方法 ──────────────────────────────────────────
/// guardResult — Repository 层统一使用此方法包装 API 调用
///
/// 自动捕获 ApiException（由 ApiClient 的拦截器转换）
/// 其他未知异常也会被转为 Failure 返回，不会 crash
///
/// 用法：
///   Future<Result<List<PetModel>>> fetchPets() =>
///     guardResult(() async {
///       final data = await _client.get(...);
///       return data.map(PetModel.fromJson).toList();
///     });
Future<Result<T>> guardResult<T>(Future<T> Function() fn) async {
  try {
    return Success(await fn());
  } on ApiException catch (e) {
    // ApiClient 拦截器抛出的业务异常（401、404、网络超时等）
    return Failure(e);
  } catch (e) {
    // 兜底：JSON 解析失败、空指针等未预期异常
    return Failure(ApiException(message: e.toString()));
  }
}
