/// 数字宠首页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_tokens.dart';
import '../../shared/theme/app_fonts.dart';
import 'controller/digital_pet_controller.dart';
import 'widgets/digital_pet_scene_view.dart';

class DigitalPetPage extends ConsumerStatefulWidget {
  const DigitalPetPage({super.key});

  @override
  ConsumerState<DigitalPetPage> createState() => _DigitalPetPageState();
}

class _DigitalPetPageState extends ConsumerState<DigitalPetPage> {
  final _sceneKey = GlobalKey<DigitalPetSceneViewState>();

  void _onSceneEvent(String event, Map<String, dynamic> data) {
    final controller = ref.read(digitalPetControllerProvider.notifier);
    switch (event) {
      case 'petReady':
        controller.onSceneReady();
        break;
      case 'petError':
        controller.onSceneError(data['message'] ?? 'unknown error');
        break;
    }
  }

  void _switchPet(PetKind kind) {
    ref.read(digitalPetControllerProvider.notifier).switchPet(kind);
    _sceneKey.currentState?.loadPet(kind);
  }

  void _switchAction(PetAction action) {
    ref.read(digitalPetControllerProvider.notifier).switchAction(action);
    _sceneKey.currentState?.playAction(action);
  }

  void _switchBackground(PetBackground bg) {
    ref.read(digitalPetControllerProvider.notifier).switchBackground(bg);
    _sceneKey.currentState?.setBackground(bg);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(digitalPetControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surfacePage,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DigitalPetSceneView(
                    key: _sceneKey,
                    onEvent: _onSceneEvent,
                  ),
                  if (!state.sceneReady)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            _ControlPanel(
              state: state,
              onPetChanged: _switchPet,
              onActionChanged: _switchAction,
              onBackgroundChanged: _switchBackground,
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final DigitalPetState state;
  final ValueChanged<PetKind> onPetChanged;
  final ValueChanged<PetAction> onActionChanged;
  final ValueChanged<PetBackground> onBackgroundChanged;

  const _ControlPanel({
    required this.state,
    required this.onPetChanged,
    required this.onActionChanged,
    required this.onBackgroundChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.card),
          topRight: Radius.circular(AppRadius.card),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _PetChip(
                label: '狗',
                selected: state.kind == PetKind.dog,
                onTap: () => onPetChanged(PetKind.dog),
              ),
              SizedBox(width: AppSpacing.x8),
              _PetChip(
                label: '猫',
                selected: state.kind == PetKind.cat,
                onTap: () => onPetChanged(PetKind.cat),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.wallpaper_rounded),
                color: AppColors.textSecondary,
                tooltip: '切换背景',
                onPressed: () => onBackgroundChanged(
                  state.background == PetBackground.bg1
                      ? PetBackground.bg2
                      : PetBackground.bg1,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.x12),
          Row(
            children: PetAction.values
                .map((a) => Expanded(
                      child: _ActionButton(
                        action: a,
                        selected: state.action == a,
                        onTap: () => onActionChanged(a),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: AppSpacing.x8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : AppColors.surfaceSunken,
          borderRadius: AppRadius.pillRadius,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.textOnBrand : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final PetAction action;
  final bool selected;
  final VoidCallback onTap;

  const _ActionButton({
    required this.action,
    required this.selected,
    required this.onTap,
  });

  static const _labels = {
    PetAction.idle: '待机',
    PetAction.walk: '走路',
    PetAction.excited: '开心',
    PetAction.look: '张望',
  };

  static const _icons = {
    PetAction.idle: Icons.pets_rounded,
    PetAction.walk: Icons.directions_walk_rounded,
    PetAction.excited: Icons.celebration_rounded,
    PetAction.look: Icons.visibility_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.x8),
        margin: EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimarySoft : Colors.transparent,
          borderRadius: AppRadius.controlRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icons[action],
              size: 22,
              color: selected ? AppColors.brandPrimary : AppColors.textSecondary,
            ),
            SizedBox(height: AppSpacing.x4),
            Text(
              _labels[action] ?? '',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.brandPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 