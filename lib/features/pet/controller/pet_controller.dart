/// 宠物列表状态及档案操作。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/result.dart';
import '../data/models/pet_model.dart';
import '../data/repository/pet_repository.dart';
import '../data/repository/pet_peer_repository.dart';

// ══════════════════════════════════════════════════════════
//  状态类 — PetState
// ══════════════════════════════════════════════════════════

/// Controller 管理的完整 UI 状态
///
/// 使用不可变类 + copyWith 模式，避免直接修改状态导致 bug。
/// View 通过 ref.watch(petControllerProvider) 监听状态变化自动重建。
class PetState {
  /// 宠物列表（已加载的数据）
  final List<PetModel> pets;

  /// 是否正在加载（用于显示加载指示器，禁用提交按钮）
  final bool isLoading;

  /// 错误提示消息（非 null 时 View 应弹出 SnackBar，弹后调 clearError 清除）
  ///
  /// 为什么不直接在 Controller 里弹 SnackBar？
  ///   → Controller 没有 BuildContext，无法操作 UI
  ///   → 通过状态通知 View，保持单向数据流
  final String? errorMessage;

  const PetState({
    this.pets = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  /// 不可变更新：生成新的状态对象（不改变原有字段）
  PetState copyWith({
    List<PetModel>? pets,
    bool? isLoading,
    String? errorMessage,
  }) =>
      PetState(
        pets: pets ?? this.pets,
        isLoading: isLoading ?? this.isLoading,
        // errorMessage 特殊处理：传 null 表示清除错误
        errorMessage: errorMessage,
      );
}

// ══════════════════════════════════════════════════════════
//  控制器 — PetController
// ══════════════════════════════════════════════════════════

/// 宠物功能的核心 Controller
///
/// 继承 StateNotifier<PetState> 表示它管理 PetState 类型的状态。
/// 所有状态变更必须通过 state = state.copyWith(...) 进行。
class PetController extends StateNotifier<PetState> {
  /// Repository 通过构造函数注入（依赖倒置）
  final PetRepository _repo;
  final PetPeerRepository _peerRepo;

  /// 初始状态：空列表、未加载、无错误
  PetController(this._repo, {required PetPeerRepository peerRepo}) : _peerRepo = peerRepo, super(const PetState());

  // ── 查询 ────────────────────────────────────────────────

  /// 加载宠物列表（页面 initState 或下拉刷新时调用）
  ///
  /// 流程：
  ///   1. 设置 isLoading = true（View 显示加载圈）
  ///   2. 调用 Repository 获取数据
  ///   3. 成功 → 更新 pets 列表
  ///      失败 → 写入 errorMessage（View 监听后弹出提示）
  Future<void> loadPets() async {
    // 开始加载：禁用 UI 操作
    state = state.copyWith(isLoading: true);

    final result = await _repo.fetchPets();

    result.when(
      success: (pets) {
        // 加载成功：更新列表，关闭加载状态
        state = state.copyWith(pets: pets, isLoading: false);
      },
      failure: (err) {
        // 加载失败：关闭加载状态，通知 View 显示错误
        state = state.copyWith(
          isLoading: false,
          errorMessage: err.userMessage,
        );
      },
    );
  }

  Future<Result<void>> createPet({
    required String petName,
    String? breed,
    int? age,
    String? sex,
    String? avatar,
  }) async {
    final result = await _peerRepo.createPet(
      petName: petName, breed: breed, age: age, sex: sex, avatar: avatar,
    );
    if (result.isSuccess) await loadPets();
    return result;
  }

  // ── 更新 ────────────────────────────────────────────────

  /// 更新宠物信息（修改名字、品种、健康状态等）
  ///
  /// 服务端只返回 { success: true }，不返回完整宠物数据；
  /// 成功后直接用传入的 [pet]（调用方已持有的最新数据）替换本地列表项。
  Future<Result<void>> updatePet(PetModel pet) async {
    final result = await _repo.updatePet(pet);

    result.when(
      success: (_) {
        final newList = state.pets
            .map((p) => p.id == pet.id ? pet : p)
            .toList();
        state = state.copyWith(pets: newList);
      },
      failure: (err) {
        state = state.copyWith(errorMessage: err.userMessage);
      },
    );

    return result;
  }

  // ── 工具方法 ────────────────────────────────────────────

  /// 清除错误消息
  ///
  /// View 在 ref.listen 中弹出 SnackBar 后，立即调用此方法清除，
  /// 防止页面重建时重复弹出相同错误。
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// 按 ID 获取单个宠物（纯本地查找，不发请求）
  PetModel? getPetById(String id) {
    try {
      return state.pets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null; // 未找到时返回 null
    }
  }
}

// ── Riverpod Provider ─────────────────────────────────────
/// PetController 的全局 Provider
///
/// StateNotifierProvider 的作用：
///   - 第一个泛型 PetController：控制器类型
///   - 第二个泛型 PetState：状态类型
///
/// View 使用方式：
///   // 监听状态（状态变化时自动重建 Widget）
///   final state = ref.watch(petControllerProvider);
///
///   // 调用方法（不触发重建）
///   ref.read(petControllerProvider.notifier).loadPets();
final petControllerProvider =
    StateNotifierProvider<PetController, PetState>((ref) {
  return PetController(ref.watch(petRepositoryProvider),
      peerRepo: ref.watch(petPeerRepositoryProvider));
});
