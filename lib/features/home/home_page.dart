import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart' show AppL10nX;
import '../../core/router/app_routes.dart';
import '../../shared/theme/app_colors.dart';
import '../auth/controller/auth_controller.dart';
import '../bind_device/select_device_page.dart';
import '../device/data/models/device_model.dart';
import '../device/data/repository/device_repository.dart';
import '../device/device_detail_page.dart';
import '../device/device_list_page.dart';
import '../device/robot_device_page.dart';
import '../pet/controller/pet_controller.dart';
import 'widgets/ai_image_panel.dart';
import 'widgets/ai_translate_panel.dart';
import 'widgets/pet_mood_section.dart';
import 'widgets/pet_picker_sheet.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _voiceKey = GlobalKey();
  final _imageKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    HapticFeedback.selectionClick();
    Scrollable.ensureVisible(
      target,
      duration: Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _HomeTopBar(),
                  SizedBox(height: 14),
                  _HomeHero(
                    onConsult: () => _openConsultation(context, ref),
                  ),
                  SizedBox(height: 14),
                  _ActionDock(
                    onConsult: () => _openConsultation(context, ref),
                    onVoice: () => _scrollTo(_voiceKey),
                    onImage: () => _scrollTo(_imageKey),
                  ),
                  const _MaybePetMoodSection(),
                  const _SectionHeader(
                    title: 'AI 解析',
                  ),
                  SizedBox(height: 12),
                  KeyedSubtree(
                    key: _voiceKey,
                    child: AiTranslatePanel(),
                  ),
                  SizedBox(height: 16),
                  KeyedSubtree(
                    key: _imageKey,
                    child: AiImagePanel(),
                  ),
                  SizedBox(height: 28),
                  const _HomeDeviceSection(),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // children: [
            //   Text(
            //     'PetPogo',
            //     style: TextStyle(
            //       fontSize: 12,
            //       fontWeight: FontWeight.w900,
            //       color: AppColors.secondary,
            //       height: 1.1,
            //     ),
            //   ),
            //   SizedBox(height: 4),
            //   Text(
            //     '今日照看',
            //     style: TextStyle(
            //       fontFamily: AppFonts.primary,
            //       fontSize: 21,
            //       fontWeight: FontWeight.w900,
            //       color: AppColors.onSurface,
            //       height: 1.15,
            //     ),
            //   ),
            // ],
          ),
        ),
        _TopIconButton(
          icon: Icons.person_rounded,
          onTap: () => context.go(AppRoutes.profile),
        ),
      ],
    );
  }
}

void _openConsultation(BuildContext context, WidgetRef ref) async {
  HapticFeedback.lightImpact();
  final deviceState = ref.read(deviceListProvider);

  if (!deviceState.isLoading && deviceState.devices.isEmpty) {
    _showNoDeviceDialog(context);
    return;
  }

  await PetPickerSheet.show(
    context,
    ref: ref,
    onPicked: (petId) {
      Future.delayed(Duration(milliseconds: 60), () {
        if (context.mounted) {
          context.push(AppRoutes.consultation, extra: petId);
        }
      });
    },
  );
}

void _showNoDeviceDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        '需要绑定设备',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.onSurface,
        ),
      ),
      content: Text(
        '绑定设备并完善宠物档案后，就可以开启 AI 问诊。',
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            '稍后',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            context.push(AppRoutes.bindDevice);
          },
          child: Text(
            '去绑定',
            style: TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _HomeHero extends ConsumerWidget {
  final VoidCallback onConsult;

  const _HomeHero({required this.onConsult});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final deviceState = ref.watch(deviceListProvider);
    final petState = ref.watch(petControllerProvider);

    final name = auth.user?.name.trim();
    final displayName = name == null || name.isEmpty ? '铲屎官' : name;
    final onlineCount = deviceState.devices.where((d) => d.isOnline).length;
    final pets = petState.pets;
    final primaryPet = pets.isEmpty ? null : pets.first;
    final primaryPetName = primaryPet?.name.trim();
    final primaryPetTitle = primaryPetName == null || primaryPetName.isEmpty
        ? '宠物档案'
        : primaryPetName;
    final petLine = petState.isLoading
        ? '正在同步你的宠物档案和设备状态。'
        : pets.isEmpty
            ? l10n.homeSubtitle
            : '今天先看看 $primaryPetTitle 的状态。';
    final quota = auth.user?.aiQuota;
    final quotaText = quota == null
        ? '--'
        : quota.isUnlimited
            ? '不限'
            : quota.remaining.toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceContainerLowest,
            AppColors.primaryContainer.withValues(alpha: 0.22),
            AppColors.secondaryContainer.withValues(alpha: 0.28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.11),
            blurRadius: 26,
            spreadRadius: -10,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '你好，$displayName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface,
                        height: 1.10,
                      ),
                    ),
                    SizedBox(height: 9),
                    Text(
                      petLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 13.5,
                        height: 1.42,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 16),
                    _HeroButton(onTap: onConsult),
                  ],
                ),
              ),
              SizedBox(width: 14),
              const _AssistantImageCard(),
            ],
          ),
          SizedBox(height: 16),
          _HeroMetricStrip(
            items: [
              _HeroMetricData(
                label: '在线设备',
                value: onlineCount.toString(),
                icon: Icons.sensors_rounded,
                color: AppColors.secondary,
              ),
              _HeroMetricData(
                label: 'AI 次数',
                value: quotaText,
                icon: Icons.auto_awesome_rounded,
                color: AppColors.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistantImageCard extends StatelessWidget {
  const _AssistantImageCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 108,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.62),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: -10,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          'assets/images/chongxiaoyi.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeroButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.medical_services_rounded, size: 17),
        label: Text('问问宠小伊'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          textStyle: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _HeroMetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HeroMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _HeroMetricStrip extends StatelessWidget {
  final List<_HeroMetricData> items;

  const _HeroMetricStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(child: _HeroMetricCell(data: items[i])),
            if (i != items.length - 1) const _MetricDivider(),
          ],
        ],
      ),
    );
  }
}

class _HeroMetricCell extends StatelessWidget {
  final _HeroMetricData data;

  const _HeroMetricCell({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, size: 17, color: data.color),
          SizedBox(width: 6),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurfaceVariant,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.outlineVariant.withValues(alpha: 0.22),
    );
  }
}

class _ActionDock extends StatelessWidget {
  final VoidCallback onConsult;
  final VoidCallback onVoice;
  final VoidCallback onImage;

  const _ActionDock({
    required this.onConsult,
    required this.onVoice,
    required this.onImage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.health_and_safety_rounded,
            title: '问诊',
            color: AppColors.secondary,
            onTap: onConsult,
          ),
        ),
        SizedBox(width: 9),
        Expanded(
          child: _ActionTile(
            icon: Icons.graphic_eq_rounded,
            title: '听懂',
            color: AppColors.primary,
            onTap: onVoice,
          ),
        ),
        SizedBox(width: 9),
        Expanded(
          child: _ActionTile(
            icon: Icons.add_photo_alternate_rounded,
            title: '表情',
            color: AppColors.tertiary,
            onTap: onImage,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color.lerp(
      AppColors.surfaceContainerLowest,
      widget.color,
      _pressed ? 0.18 : 0.09,
    )!;
    final borderColor = widget.color.withValues(alpha: _pressed ? 0.34 : 0.22);

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: 58,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _pressed ? 0.06 : 0.14),
              blurRadius: _pressed ? 7 : 14,
              spreadRadius: -10,
              offset: Offset(0, _pressed ? 2 : 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTap: () {
              _setPressed(false);
              HapticFeedback.selectionClick();
              widget.onTap();
            },
            splashColor: widget.color.withValues(alpha: 0.14),
            highlightColor: widget.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(17),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                // 固定内容：左pad(11)+图标(32)+间距(9)+右pad(10) = 62
                // 箭头区域：间距(4)+箭头(18) = 22  →  阈值 = 62 + 22 + 最小文字宽 ≈ 112
                final showArrow = constraints.maxWidth >= 112;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(11, 0, 10, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 17),
                      ),
                      SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.onSurface,
                            height: 1.0,
                          ),
                        ),
                      ),
                      if (showArrow) ...[
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            color: widget.color, size: 18),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MaybePetMoodSection extends ConsumerStatefulWidget {
  const _MaybePetMoodSection();

  @override
  ConsumerState<_MaybePetMoodSection> createState() =>
      _MaybePetMoodSectionState();
}

class _MaybePetMoodSectionState extends ConsumerState<_MaybePetMoodSection> {
  String? _requestedForUserId;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final petState = ref.watch(petControllerProvider);

    if (!auth.isLoggedIn) {
      _requestedForUserId = null;
      return SizedBox(height: 12);
    }

    final userId = auth.user?.id ?? '';
    if (_requestedForUserId != userId &&
        !petState.isLoading &&
        petState.pets.isEmpty) {
      _requestedForUserId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(petControllerProvider.notifier).loadPets();
        }
      });
    }

    if (petState.isLoading && petState.pets.isEmpty) {
      return const _PetMoodLoadingShell();
    }

    if (petState.pets.isEmpty) {
      return SizedBox(height: 12);
    }

    return Column(
      children: [
        SizedBox(height: 22),
        PetMoodSection(),
        SizedBox(height: 24),
      ],
    );
  }
}

class _PetMoodLoadingShell extends StatelessWidget {
  const _PetMoodLoadingShell();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 22),
        SizedBox(
          height: 88,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onAdd;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface,
                  height: 1.15,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        // + 添加设备图标
        if (onAdd != null)
          GestureDetector(
            onTap: onAdd,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child:
                  Icon(Icons.add_rounded, size: 22, color: AppColors.primary),
            ),
          ),
        // 文字行动按钮（"全部"）
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeDeviceSection extends ConsumerWidget {
  const _HomeDeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceListProvider);
    final l10n = context.l10n;
    final onlineCount = state.devices.where((d) => d.isOnline).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.homeConnectedDevices,
          subtitle: state.devices.isEmpty
              ? '还没有绑定设备'
              : l10n.homeDevicesActive(onlineCount),
          // 右边始终显示 + 图标，点击添加新设备
          onAdd: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SelectDevicePage()),
          ),
          actionLabel: state.devices.isEmpty ? null : '全部',
          onAction: state.devices.isEmpty
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DeviceListPage()),
                  ),
        ),
        SizedBox(height: 12),
        if (state.isLoading && state.devices.isEmpty)
          const _DeviceLoadingPanel()
        else if (state.devices.isEmpty)
          const _EmptyDevicePanel()
        else ...[
          ...state.devices.take(3).map(
                (device) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HomeDeviceCard(device: device),
                ),
              ),
          if (state.devices.length > 3)
            Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DeviceListPage()),
                ),
                child: Text(
                  '查看全部 ${state.devices.length} 台设备',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _DeviceLoadingPanel extends StatelessWidget {
  const _DeviceLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2.5,
      ),
    );
  }
}

class _EmptyDevicePanel extends StatelessWidget {
  const _EmptyDevicePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 18,
            spreadRadius: -8,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.add_link_rounded,
              color: AppColors.primary,
              size: 25,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '添加第一台设备',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '连接后可查看宠物位置、状态和设备控制。',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          IconButton.filled(
            onPressed: () => context.push(AppRoutes.bindDevice),
            icon: Icon(Icons.arrow_forward_rounded, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeDeviceCard extends StatelessWidget {
  final DeviceModel device;

  const _HomeDeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final isRobot = device.isRobot;
    final accent = device.isOnline ? AppColors.secondary : AppColors.outline;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => isRobot
                  ? RobotDevicePage(mac: device.mac, name: device.displayName)
                  : DeviceDetailPage(mac: device.mac, name: device.displayName),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 18,
                spreadRadius: -8,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isRobot ? Icons.smart_toy_rounded : Icons.location_on_rounded,
                  size: 23,
                  color: accent,
                ),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface,
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusDot(color: accent),
                        SizedBox(width: 6),
                        Text(
                          device.isOnline ? '在线守护中' : '暂时离线',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: device.isOnline
                                ? AppColors.secondary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  device.isOwner ? '我的' : '共享',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;

  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ScanButton extends ConsumerWidget {
  const _ScanButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TopPillButton(
      icon: Icons.qr_code_scanner_rounded,
      label: '扫码',
      onTap: () async {
        HapticFeedback.mediumImpact();
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SelectDevicePage()),
        );
        ref.read(deviceListProvider.notifier).load();
      },
    );
  }
}

class _TopPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TopPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: AppColors.primary,
                  size: 19,
                ),
                SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 21,
          ),
        ),
      ),
    );
  }
}
