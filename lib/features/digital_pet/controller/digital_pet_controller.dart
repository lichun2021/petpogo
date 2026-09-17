/// 数字宠状态。
///
/// v2：从纯本地演示状态改为真实宠物驱动——选中哪只宠物、它的养成
/// 属性/背景/形象全部来自业务后端（GET /sdkapi/pet/:id/status），
/// 互动/硬件动作轮询会就地更新养成属性和当前播放的动画 clip。
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../pet/data/models/pet_peer_models.dart';
import '../../pet/data/repository/pet_peer_repository.dart';
import '../data/models/pet_status_model.dart';
import '../data/models/pet_resources_model.dart';
import '../data/repository/digital_pet_repository.dart';

/// 记住用户上次选中的宠物，重开 App 后默认还是显示这只（而不是总是回到
/// 列表第一只）。非敏感数据，用 SharedPreferences（项目未接入 Hive）。
const kLastSelectedPetIdKey = 'digital_pet_last_selected_pet_id';

/// 硬件动作轮询间隔：详见 design.md Decision 7（5s，权衡响应及时性与请求量）。
const kActionPollInterval = Duration(seconds: 5);

enum DigitalPetStatus { loading, ready, error }

class DigitalPetState {
  /// 当前用户已绑定的全部宠物（来自 iPet 网关），驱动"切换宠物"面板。
  final List<PetInfoModel> pets;

  /// 当前选中的宠物 peer petId；[pets] 为空时为 null。
  final String? selectedPetId;

  /// 加载状态机：loading（首次加载 / 切换宠物中）/ ready / error。
  final DigitalPetStatus status;

  /// status 拉取成功后的完整数据；status 为 error 时可能是上一次的
  /// 陈旧数据——页面必须只看 [status] 字段决定是否展示，不能凭
  /// [petStatus] 非空就当作"已就绪"。
  final PetStatusModel? petStatus;

  /// 加载失败时的错误对象，供页面展示 + 重试。
  final Object? error;

  /// GET /sdkapi/pet/resources 的缓存结果；背景/形象/互动面板打开时用。
  final PetResourcesModel? resources;

  /// Three.js 场景是否已加载完成（petReady 事件）。
  final bool sceneReady;
  final Object? sceneError;

  /// 硬件轮询/互动最近一次驱动播放的 clip 名字，用于跟硬件轮询的
  /// "clipCode 变化才播放"去重逻辑对比（design.md Decision 8：
  /// 互动动画与硬件轮询共用同一个 playAction 通道，谁后触发谁生效）。
  final String? lastClipCode;

  const DigitalPetState({
    this.pets = const [],
    this.selectedPetId,
    this.status = DigitalPetStatus.loading,
    this.petStatus,
    this.error,
    this.resources,
    this.sceneReady = false,
    this.sceneError,
    this.lastClipCode,
  });

  PetInfoModel? get selectedPet {
    if (selectedPetId == null) return null;
    for (final p in pets) {
      if (p.petId == selectedPetId) return p;
    }
    return null;
  }

  bool get hasNoPets => pets.isEmpty;

  DigitalPetState copyWith({
    List<PetInfoModel>? pets,
    String? selectedPetId,
    DigitalPetStatus? status,
    PetStatusModel? petStatus,
    Object? error,
    PetResourcesModel? resources,
    bool? sceneReady,
    Object? sceneError,
    String? lastClipCode,
    bool clearError = false,
    bool clearSceneError = false,
  }) =>
      DigitalPetState(
        pets: pets ?? this.pets,
        selectedPetId: selectedPetId ?? this.selectedPetId,
        status: status ?? this.status,
        petStatus: petStatus ?? this.petStatus,
        error: clearError ? null : (error ?? this.error),
        resources: resources ?? this.resources,
        sceneReady: sceneReady ?? this.sceneReady,
        sceneError: clearSceneError ? null : (sceneError ?? this.sceneError),
        lastClipCode: lastClipCode ?? this.lastClipCode,
      );
}

class DigitalPetController extends StateNotifier<DigitalPetState> {
  final PetPeerRepository _peerRepo;
  final DigitalPetRepository _digitalRepo;

  Timer? _actionPollTimer;

  DigitalPetController(this._peerRepo, this._digitalRepo)
      : super(const DigitalPetState()) {
    _init();
  }

  Future<void> _init() async {
    final pets = await _loadPets();
    if (pets.isEmpty) {
      state = state.copyWith(status: DigitalPetStatus.ready, pets: pets);
      return;
    }
    final savedId = await _readLastSelectedPetId();
    final initial = pets.any((p) => p.petId == savedId)
        ? savedId
        : pets.first.petId;
    state = state.copyWith(pets: pets, selectedPetId: initial);
    await _loadStatusForSelected();
  }

  Future<List<PetInfoModel>> _loadPets() async {
    try {
      return await _peerRepo.fetchPetList();
    } catch (e) {
      debugPrint('[数字宠] ❌ 获取宠物列表失败: $e');
      return const [];
    }
  }

  Future<String?> _readLastSelectedPetId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(kLastSelectedPetIdKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLastSelectedPetId(String petId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLastSelectedPetIdKey, petId);
    } catch (_) {
      // 记忆失败不影响本次使用，只是下次打开可能回到第一只宠物
    }
  }

  /// 切换到用户在"切换宠物"面板里选中的另一只宠物。
  Future<void> switchPet(String petId) async {
    if (petId == state.selectedPetId) return;
    _stopActionPolling();
    state = state.copyWith(
      selectedPetId: petId,
      status: DigitalPetStatus.loading,
      // 切换宠物时清掉旧宠物的场景状态，避免"新宠物页面上还显示旧宠物
      // 的模型/进度条"——错误状态下也不能让旧数据看起来像属于新宠物。
      sceneReady: false,
      clearSceneError: true,
      lastClipCode: null,
    );
    await _saveLastSelectedPetId(petId);
    await _loadStatusForSelected();
  }

  /// 拉取当前选中宠物的 status。
  ///
  /// 不做任何建档/懒同步——`POST /sdkapi/pet/create` 只应该在绑定宠物
  /// （peer `pet/info/add` 成功后调用 `PetSyncRepository.syncCreate`）
  /// 时触发一次，本方法只读，查不到业务后端记录就走 error 分支。
  Future<void> _loadStatusForSelected() async {
    final pet = state.selectedPet;
    if (pet == null) return;
    state = state.copyWith(status: DigitalPetStatus.loading, clearError: true);

    final result = await _digitalRepo.fetchStatus(pet.petId);
    result.when(
      success: (status) {
        state = state.copyWith(
          status: DigitalPetStatus.ready,
          petStatus: status,
        );
        _startActionPolling();
      },
      failure: (err) {
        state = state.copyWith(status: DigitalPetStatus.error, error: err);
      },
    );
  }

  /// 页面里点击"重试"按钮时调用。
  Future<void> retry() => _loadStatusForSelected();

  // ── 互动 ──────────────────────────────────────────────

  Future<void> interact(String interactionCode) async {
    final pet = state.selectedPet;
    final current = state.petStatus;
    if (pet == null || current == null) return;
    final result = await _digitalRepo.interact(pet.petId, interactionCode);
    result.when(
      success: (r) {
        state = state.copyWith(
          petStatus: current.copyWith(
            satiety: r.satiety,
            mood: r.mood,
            cleanliness: r.cleanliness,
          ),
          lastClipCode: r.clipCode ?? state.lastClipCode,
        );
      },
      failure: (err) {
        debugPrint('[数字宠] ❌ 互动失败: $err');
        // 按 spec：养成属性和动画都保持不变，只需要页面展示错误提示，
        // 这里不写 state.error（避免整页切到错误态，只是这一次互动失败）。
      },
    );
  }

  // ── 资源选择 ──────────────────────────────────────────

  Future<void> loadResources() async {
    final result = await _digitalRepo.fetchResources();
    result.when(
      success: (res) => state = state.copyWith(resources: res),
      failure: (err) => debugPrint('[数字宠] ❌ 获取资源列表失败: $err'),
    );
  }

  Future<bool> selectBackground(PetBackgroundResource bg) async {
    final pet = state.selectedPet;
    final current = state.petStatus;
    if (pet == null || current == null) return false;
    final result = await _digitalRepo.updateResourceSelection(
      pet.petId,
      currentName: current.name,
      backgroundId: bg.id,
    );
    if (result.isSuccess) {
      state = state.copyWith(petStatus: current.copyWith(background: bg));
      return true;
    }
    debugPrint('[数字宠] ❌ 设置背景失败: ${result.error}');
    return false;
  }

  Future<bool> selectModel(PetModelResource model) async {
    final pet = state.selectedPet;
    final current = state.petStatus;
    if (pet == null || current == null) return false;
    final result = await _digitalRepo.updateResourceSelection(
      pet.petId,
      currentName: current.name,
      modelId: model.id,
    );
    if (result.isSuccess) {
      state = state.copyWith(petStatus: current.copyWith(model: model));
      return true;
    }
    debugPrint('[数字宠] ❌ 设置形象失败: ${result.error}');
    return false;
  }

  // ── 硬件动作轮询 ────────────────────────────────────────

  void _startActionPolling() {
    _stopActionPolling();
    _actionPollTimer = Timer.periodic(kActionPollInterval, (_) => _pollAction());
  }

  void _stopActionPolling() {
    _actionPollTimer?.cancel();
    _actionPollTimer = null;
  }

  Future<void> _pollAction() async {
    final pet = state.selectedPet;
    if (pet == null) return;
    final result = await _digitalRepo.fetchAction(pet.petId);
    result.when(
      success: (action) {
        if (action.clipCode != null && action.clipCode != state.lastClipCode) {
          state = state.copyWith(lastClipCode: action.clipCode);
        }
      },
      failure: (err) => debugPrint('[数字宠] ❌ 硬件动作轮询失败: $err'),
    );
  }

  // ── 场景事件 ──────────────────────────────────────────

  void onSceneReady() {
    state = state.copyWith(sceneReady: true, clearSceneError: true);
  }

  void onSceneError(Object error) {
    state = state.copyWith(sceneReady: false, sceneError: error);
  }

  @override
  void dispose() {
    _stopActionPolling();
    super.dispose();
  }
}

final digitalPetControllerProvider =
    StateNotifierProvider<DigitalPetController, DigitalPetState>((ref) {
  return DigitalPetController(
    ref.read(petPeerRepositoryProvider),
    ref.read(digitalPetRepositoryProvider),
  );
});

