/// 数字宠首页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_tokens.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../pet/data/models/pet_peer_models.dart';
import 'data/models/pet_status_model.dart';
import 'data/models/pet_resources_model.dart';
import 'controller/digital_pet_controller.dart';
import 'widgets/digital_pet_scene_view.dart';

/// 一条"+N饱腹"浮动提示的数据；[id] 用于播完动画后从列表里精准移除。
class _DeltaPopup {
  final int id;
  final String text;
  final Color color;

  const _DeltaPopup({required this.id, required this.text, required this.color});
}

class DigitalPetPage extends ConsumerStatefulWidget {
  const DigitalPetPage({super.key});

  @override
  ConsumerState<DigitalPetPage> createState() => _DigitalPetPageState();
}

class _DigitalPetPageState extends ConsumerState<DigitalPetPage> {
  final _sceneKey = GlobalKey<DigitalPetSceneViewState>();

  // 每个悬浮按钮各自的 LayerLink：弹出面板通过 CompositedTransformFollower
  // 跟随对应按钮的锚点定位，不依赖手动估算的像素偏移，保证像素级对齐。
  final Map<_PanelKind, LayerLink> _railLinks = {
    for (final k in _PanelKind.values) k: LayerLink(),
  };

  String? _lastLoadedGlbUrl;
  String? _lastLoadedBgUrl;
  String? _lastAppliedClipCode;

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

  // 根据最新 controller 状态，把模型/背景/动作同步到 WebView 场景。
  // 用"上次已应用的值"做 diff，避免每次 build 都重复下发相同指令。
  void _syncSceneWithState(DigitalPetState state) {
    final status = state.petStatus;
    if (status == null) return;
    final scene = _sceneKey.currentState;
    if (scene == null) return;

    final glbUrl = status.model?.glbUrl;
    if (glbUrl != null && glbUrl != _lastLoadedGlbUrl) {
      _lastLoadedGlbUrl = glbUrl;
      _lastAppliedClipCode = null; // 换模型后动画状态重置，清空去重记录
      scene.loadModel(glbUrl, status.model!.id);
    }

    final bgUrl = status.background?.imageUrl;
    if (bgUrl != _lastLoadedBgUrl) {
      _lastLoadedBgUrl = bgUrl;
      scene.setBackground(bgUrl);
    }

    final clip = state.lastClipCode;
    if (clip != null && clip != _lastAppliedClipCode) {
      _lastAppliedClipCode = clip;
      scene.playAction(clip);
    }
  }

  void _switchPet(String petId) {
    ref.read(digitalPetControllerProvider.notifier).switchPet(petId);
  }

  Future<void> _interact(String code) async {
    final before = ref.read(digitalPetControllerProvider).petStatus;
    await ref.read(digitalPetControllerProvider.notifier).interact(code);
    if (!mounted || before == null) return;
    final after = ref.read(digitalPetControllerProvider).petStatus;
    if (after == null) return;
    _showVitalityDeltas(before, after);
  }

  // 互动成功后弹出"+N饱腹/+N情绪/+N清洁"提示，数值和颜色对应养成属性；
  // 每条提示自带独立的浮动+渐隐动画（见 _FloatingDeltaText），播完后
  // 自行从 _deltaPopups 里移除，不需要 controller 参与生命周期管理。
  int _deltaPopupSeq = 0;
  final List<_DeltaPopup> _deltaPopups = [];

  void _showVitalityDeltas(PetStatusModel before, PetStatusModel after) {
    final entries = <(String, int, Color)>[
      ('饱腹', after.satiety - before.satiety, AppColors.statusOnline),
      ('情绪', after.mood - before.mood, AppColors.brandPrimary),
      ('清洁', after.cleanliness - before.cleanliness, AppColors.statusWarning),
    ];
    final popups = <_DeltaPopup>[];
    for (final (label, delta, color) in entries) {
      if (delta == 0) continue;
      popups.add(_DeltaPopup(
        id: _deltaPopupSeq++,
        text: delta > 0 ? '+$delta$label' : '$delta$label',
        color: color,
      ));
    }
    if (popups.isEmpty) return;
    setState(() => _deltaPopups.addAll(popups));
  }

  void _removeDeltaPopup(int id) {
    setState(() => _deltaPopups.removeWhere((p) => p.id == id));
  }

  // 当前展开的悬浮面板；再次点击同一按钮或点场景空白处收起。
  _PanelKind? _openPanel;

  void _togglePanel(_PanelKind kind) {
    setState(() => _openPanel = _openPanel == kind ? null : kind);
    if (kind == _PanelKind.background || kind == _PanelKind.action) {
      // 背景/形象面板依赖 resources 列表；互动面板也从 resources 里取
      // interactionTypes，打开时按需拉取（无 spec 要求预取时机）。
      ref.read(digitalPetControllerProvider.notifier).loadResources();
    }
  }

  void _closePanel() => setState(() => _openPanel = null);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(digitalPetControllerProvider);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncSceneWithState(state));

    return Scaffold(
      backgroundColor: AppColors.surfacePage,
      body: SafeArea(
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(DigitalPetState state) {
    if (state.hasNoPets) {
      return const _EmptyPetsView();
    }
    if (state.status == DigitalPetStatus.error && state.petStatus == null) {
      return _ErrorView(
        error: state.error,
        onRetry: () =>
            ref.read(digitalPetControllerProvider.notifier).retry(),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        DigitalPetSceneView(key: _sceneKey, onEvent: _onSceneEvent),
        if (state.status == DigitalPetStatus.loading)
          const Center(child: CircularProgressIndicator()),
        if (state.petStatus != null)
          Positioned(
            left: AppSpacing.x16,
            top: AppSpacing.x40,
            child: _VitalityBars(status: state.petStatus!),
          ),
        Positioned(
          right: AppSpacing.x16,
          top: AppSpacing.x24 + AppSpacing.x48,
          child: _FloatingRail(
            openPanel: _openPanel,
            onTogglePanel: _togglePanel,
            links: _railLinks,
            // 只有一只宠物时不需要"切换"入口（per spec：直接展示这只宠物）。
            showPetSwitch: state.pets.length > 1,
          ),
        ),
        if (_openPanel != null)
          Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: _railLinks[_openPanel]!,
              showWhenUnlinked: false,
              targetAnchor: Alignment.centerLeft,
              followerAnchor: Alignment.centerRight,
              offset: const Offset(-AppSpacing.x8, 0),
              child: _FloatingOptionsPanel(
                kind: _openPanel!,
                state: state,
                onPetChanged: (id) {
                  _switchPet(id);
                  _closePanel();
                },
                onInteract: (code) {
                  _interact(code);
                  _closePanel();
                },
                onBackgroundChanged: (bg) async {
                  await ref
                      .read(digitalPetControllerProvider.notifier)
                      .selectBackground(bg);
                  if (mounted) _closePanel();
                },
              ),
            ),
          ),
        // 互动数值变化提示：浮在场景中部，多条同时出现时左右错开一点。
        for (final popup in _deltaPopups)
          Positioned.fill(
            child: Align(
              alignment: Alignment(
                (_deltaPopups.indexOf(popup) - (_deltaPopups.length - 1) / 2) * 0.3,
                -0.1,
              ),
              child: _FloatingDeltaText(
                key: ValueKey(popup.id),
                popup: popup,
                onDone: () => _removeDeltaPopup(popup.id),
              ),
            ),
          ),
      ],
    );
  }
}

// 互动后的"+N饱腹"数值提示：文字上浮同时渐隐，播完后回调 [onDone] 让
// 父级把自己从列表里移除——动画结束时机完全由 flutter_animate 驱动，
// 页面不需要另外起 Timer 去猜多久该清掉。
class _FloatingDeltaText extends StatelessWidget {
  final _DeltaPopup popup;
  final VoidCallback onDone;

  const _FloatingDeltaText({
    super.key,
    required this.popup,
    required this.onDone,
  });

  static const _duration = Duration(milliseconds: 900);

  @override
  Widget build(BuildContext context) {
    return Text(
      popup.text,
      style: TextStyle(
        fontFamily: AppFonts.primary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: popup.color,
        shadows: const [Shadow(color: Colors.black26, blurRadius: 6)],
      ),
    )
        .animate(onComplete: (_) => onDone())
        .moveY(begin: 0, end: -36, duration: _duration, curve: Curves.easeOut)
        .fadeOut(delay: 150.ms, duration: _duration - const Duration(milliseconds: 150));
  }
}

enum _PanelKind { pet, action, background }

// ── 悬浮操作列：切换宠物 / 互动 / 背景 ──
class _FloatingRail extends StatelessWidget {
  final _PanelKind? openPanel;
  final ValueChanged<_PanelKind> onTogglePanel;
  final Map<_PanelKind, LayerLink> links;
  final bool showPetSwitch;

  const _FloatingRail({
    required this.openPanel,
    required this.onTogglePanel,
    required this.links,
    required this.showPetSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPetSwitch) ...[
          _RailButton(
            link: links[_PanelKind.pet]!,
            icon: Icons.pets_rounded,
            label: '切换',
            active: openPanel == _PanelKind.pet,
            onTap: () => onTogglePanel(_PanelKind.pet),
          ),
          SizedBox(height: AppSpacing.x16),
        ],
        _RailButton(
          link: links[_PanelKind.action]!,
          icon: Icons.emoji_emotions_rounded,
          label: '互动',
          active: openPanel == _PanelKind.action,
          onTap: () => onTogglePanel(_PanelKind.action),
        ),
        SizedBox(height: AppSpacing.x16),
        _RailButton(
          link: links[_PanelKind.background]!,
          icon: Icons.wallpaper_rounded,
          label: '背景',
          active: openPanel == _PanelKind.background,
          onTap: () => onTogglePanel(_PanelKind.background),
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  final LayerLink link;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RailButton({
    required this.link,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CompositedTransformTarget 标记锚点：弹出面板通过同一个
          // LayerLink 的 Follower 贴着这个圆形图标定位，见 build() 里的
          // CompositedTransformFollower。
          CompositedTransformTarget(
            link: link,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.brandPrimarySoft
                    : AppColors.surfaceCard.withValues(alpha: 0.88),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ambientShadow,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 22,
                color:
                    active ? AppColors.brandPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.x4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.brandPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 点击悬浮列按钮后，在其左侧弹出的选项面板 ──
class _FloatingOptionsPanel extends StatelessWidget {
  final _PanelKind kind;
  final DigitalPetState state;
  final ValueChanged<String> onPetChanged;
  final ValueChanged<String> onInteract;
  final ValueChanged<PetBackgroundResource> onBackgroundChanged;

  const _FloatingOptionsPanel({
    required this.kind,
    required this.state,
    required this.onPetChanged,
    required this.onInteract,
    required this.onBackgroundChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.x12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard.withValues(alpha: 0.95),
          borderRadius: AppRadius.cardRadius,
          boxShadow: [
            BoxShadow(
              color: AppColors.ambientShadow,
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    switch (kind) {
      case _PanelKind.pet:
        return _buildPetList();
      case _PanelKind.action:
        return _buildInteractionList();
      case _PanelKind.background:
        return _buildBackgroundList();
    }
  }

  Widget _buildPetList() {
    if (state.pets.isEmpty) {
      return Text('还没有绑定宠物',
          style: TextStyle(fontFamily: AppFonts.primary, fontSize: 13));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: state.pets
          .map((p) => Padding(
                padding: EdgeInsets.only(
                  bottom: p == state.pets.last ? 0 : AppSpacing.x8,
                ),
                child: _PetOptionTile(
                  pet: p,
                  selected: p.petId == state.selectedPetId,
                  onTap: () => onPetChanged(p.petId),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildInteractionList() {
    final types = state.resources?.interactionTypes ?? const [];
    if (types.isEmpty) {
      return const SizedBox(
        width: 88,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: types
          .map((t) => Padding(
                padding: EdgeInsets.only(
                  bottom: t == types.last ? 0 : AppSpacing.x8,
                ),
                child: _InteractionButton(
                  type: t,
                  onTap: () => onInteract(t.code),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildBackgroundList() {
    final list = state.resources?.backgrounds ?? const [];
    if (list.isEmpty) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: list
          .map((bg) => Padding(
                padding: EdgeInsets.only(
                  right: bg == list.last ? 0 : AppSpacing.x8,
                ),
                child: _ThumbOption(
                  imageUrl: bg.imageUrl,
                  selected: state.petStatus?.background?.id == bg.id,
                  onTap: () => onBackgroundChanged(bg),
                ),
              ))
          .toList(),
    );
  }
}

class _PetOptionTile extends StatelessWidget {
  final PetInfoModel pet;
  final bool selected;
  final VoidCallback onTap;

  const _PetOptionTile({
    required this.pet,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.x8,
          vertical: AppSpacing.x8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimarySoft : Colors.transparent,
          borderRadius: AppRadius.controlRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PetAvatar(imageUrl: pet.avatar, size: 32),
            SizedBox(width: AppSpacing.x8),
            Flexible(
              child: Text(
                pet.petName.isNotEmpty ? pet.petName : '未命名',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractionButton extends StatelessWidget {
  final InteractionType type;
  final VoidCallback onTap;

  const _InteractionButton({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.x12,
          vertical: AppSpacing.x8,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: AppRadius.controlRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type.iconUrl.isNotEmpty)
              Image.network(type.iconUrl,
                  width: 20,
                  height: 20,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.emoji_emotions_rounded, size: 20))
            else
              Icon(Icons.emoji_emotions_rounded,
                  size: 20, color: AppColors.textSecondary),
            SizedBox(width: AppSpacing.x8),
            Flexible(
              child: Text(
                type.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbOption extends StatelessWidget {
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  const _ThumbOption({
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: AppRadius.controlRadius,
          border: Border.all(
            color: selected ? AppColors.brandPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.control - 2),
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.surfaceSunken,
                    child: Icon(Icons.image_not_supported_rounded,
                        size: 18, color: AppColors.textSecondary),
                  ),
                )
              : Container(color: AppColors.surfaceSunken),
        ),
      ),
    );
  }
}

// ── 养成属性进度条：饱腹 / 情绪 / 清洁 ──
class _VitalityBars extends StatelessWidget {
  final PetStatusModel status;

  const _VitalityBars({required this.status});

  @override
  Widget build(BuildContext context) {
    // 不再用卡片包一层背景框，直接浮在场景上；因此每行文字加了轻微投影
    // 保证在任意背景图上都能看清，进度条轨道也用半透明而不是实色块。
    return SizedBox(
      width: 150,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VitalityBarRow(label: '饱腹', value: status.satiety, color: AppColors.statusOnline),
          SizedBox(height: AppSpacing.x4),
          _VitalityBarRow(label: '情绪', value: status.mood, color: AppColors.brandPrimary),
          SizedBox(height: AppSpacing.x4),
          _VitalityBarRow(label: '清洁', value: status.cleanliness, color: AppColors.statusWarning),
        ],
      ),
    );
  }
}

class _VitalityBarRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _VitalityBarRow({
    required this.label,
    required this.value,
    required this.color,
  });

  static const _textShadow = [
    Shadow(color: Colors.black38, blurRadius: 4),
  ];

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, 100);
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              shadows: _textShadow,
            ),
          ),
        ),
        SizedBox(width: AppSpacing.x4),
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadius.pillRadius,
            child: LinearProgressIndicator(
              value: clamped / 100,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.35),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        SizedBox(width: AppSpacing.x4),
        SizedBox(
          width: 22,
          child: Text(
            '$clamped',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              shadows: _textShadow,
            ),
          ),
        ),
      ],
    );
  }
}


class _EmptyPetsView extends StatelessWidget {
  const _EmptyPetsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.x24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_rounded, size: 48, color: AppColors.textSecondary),
            SizedBox(height: AppSpacing.x16),
            Text(
              '还没有绑定宠物',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSpacing.x8),
            Text(
              '先去「我的宠物」绑定一只宠物，再回来看它的数字形象吧',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.x24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            SizedBox(height: AppSpacing.x16),
            Text(
              '加载失败，请重试',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSpacing.x16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

