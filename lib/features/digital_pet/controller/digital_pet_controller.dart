/// 数字宠状态。
///
/// 首版只做「动作切换 + 背景切换」，不含喂养/饥饿值。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 支持的宠物品种；新增品种只改这里 + scene.js 的 PET_MODELS。
enum PetKind { dog, cat }

/// 猫、狗共用的 4 个动作；对应 scene.js 的 ACTIONS 数组。
enum PetAction { idle, walk, excited, look }

/// 可选背景图，文件位于 assets/digital_pet/bg/。
enum PetBackground { bg1, bg2 }

class DigitalPetState {
  final PetKind kind;
  final PetAction action;
  final PetBackground background;
  final bool sceneReady;
  final Object? sceneError;

  const DigitalPetState({
    this.kind = PetKind.dog,
    this.action = PetAction.idle,
    this.background = PetBackground.bg1,
    this.sceneReady = false,
    this.sceneError,
  });

  DigitalPetState copyWith({
    PetKind? kind,
    PetAction? action,
    PetBackground? background,
    bool? sceneReady,
    Object? sceneError,
    bool clearError = false,
  }) =>
      DigitalPetState(
        kind: kind ?? this.kind,
        action: action ?? this.action,
        background: background ?? this.background,
        sceneReady: sceneReady ?? this.sceneReady,
        sceneError: clearError ? null : (sceneError ?? this.sceneError),
      );
}

class DigitalPetController extends StateNotifier<DigitalPetState> {
  DigitalPetController() : super(const DigitalPetState());

  void switchPet(PetKind kind) {
    if (kind == state.kind) return;
    state = state.copyWith(
      kind: kind,
      action: PetAction.idle,
      sceneReady: false,
      clearError: true,
    );
  }

  void switchAction(PetAction action) {
    state = state.copyWith(action: action);
  }

  void switchBackground(PetBackground background) {
    state = state.copyWith(background: background);
  }

  void onSceneReady() {
    state = state.copyWith(sceneReady: true, clearError: true);
  }

  void onSceneError(Object error) {
    state = state.copyWith(sceneReady: false, sceneError: error);
  }
}

final digitalPetControllerProvider =
    StateNotifierProvider<DigitalPetController, DigitalPetState>(
        (ref) => DigitalPetController());

