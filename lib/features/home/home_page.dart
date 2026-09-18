import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart' show AppL10nX;
import '../../core/router/app_routes.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../auth/controller/auth_controller.dart';
import '../bind_device/select_device_page.dart';
import '../device/data/models/device_model.dart';
import '../device/data/repository/device_repository.dart';
import '../device/device_detail_page.dart';
import '../device/device_list_page.dart';
import '../device/robot_device_page.dart';
import '../profile/data/points_repository.dart';
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
                  const _HomeHero(),
                  SizedBox(height: 14),
                  _HomeCheckInCard(),
                  SizedBox(height: 14),
                  const _MaybePetMoodSection(),
                  const _SectionHeader(
                    title: 'AI 解析',
                  ),
                  SizedBox(height: 12),
                  AiTranslatePanel(),
                  SizedBox(height: 16),
                  AiImagePanel(),
                  SizedBox(height: 16),
                  _AiConsultCard(onTap: () => _openConsultation(context, ref)),
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
        '绑定设备并完善宠物档案后，就可以开启 AI 健康顾问。',
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
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _HomeHero extends ConsumerWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final deviceState = ref.watch(deviceListProvider);

    final user = auth.user;
    final displayName = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name
        : '铲屎官';
    final avatar = user?.avatar ?? '';
    final onlineCount = deviceState.devices.where((d) => d.isOnline).length;
    final points = user?.points ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceContainerLowest,
            AppColors.brandPrimarySoft.withValues(alpha: 0.55),
            AppColors.surfaceSunken,
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
          // 第一行：头像+昵称(→我的) | 🔔通知(→消息页)
          Row(children: [
            _HeroTap(
              onTap: () => context.go(AppRoutes.profile),
              child: Row(children: [
                PetAvatar(imageUrl: avatar, size: 40, fallbackEmoji: '🐾'),
                SizedBox(width: 10),
                Text(displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    )),
              ]),
            ),
            Spacer(),
            _HeroTap(
              onTap: () => context.push(AppRoutes.message),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_rounded,
                    size: 20, color: AppColors.onSurface),
              ),
            ),
          ]),
          SizedBox(height: 14),
          // 第二行：在线设备(→我的设备页) | 积分(→积分明细页)
          Row(children: [
            Expanded(
              child: _HeroTap(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DeviceListPage())),
                child: _HeroMetric(
                  icon: Icons.sensors_rounded,
                  value: '$onlineCount',
                  label: '在线设备',
                  color: AppColors.statusOnline,
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _HeroTap(
                onTap: () => context.push(AppRoutes.points),
                child: _HeroMetric(
                  icon: Icons.account_balance_wallet_rounded,
                  value: '$points',
                  label: '积分',
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── 账号展示位热区包装（独立可点击，互不重叠）──────────────
class _HeroTap extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _HeroTap({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
      );
}

// ── 账号展示位指标格 ──────────────────────────────────────
class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _HeroMetric(
      {required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface)),
                Text(label,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ]),
      );
}

// ── AI 健康顾问卡片（整卡可点 → 问诊页）──────────────────
class _AiConsultCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AiConsultCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: [
              BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 16,
                  spreadRadius: -6,
                  offset: Offset(0, 6)),
            ],
          ),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.brandPrimarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/images/chongxiaoyi.png',
                  fit: BoxFit.cover, alignment: Alignment.topCenter),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI健康顾问',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface)),
                  SizedBox(height: 3),
                  Text('问问宠小伊，基于宠物档案给建议',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                size: 20, color: AppColors.textTertiary),
          ]),
        ),
      ),
    );
  }
}

// ── 首页签到卡片（调 checkin status 显示连续签到天数）──────────
final _homeCheckInProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  try {
    return await ref.read(pointsRepositoryProvider).fetchStatus();
  } catch (e) {
    return null;
  }
});

class _HomeCheckInCard extends ConsumerWidget {
  const _HomeCheckInCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStreak = ref.watch(_homeCheckInProvider);
    final streak = asyncStreak.valueOrNull;
    final signedToday = streak?['signedInToday'] == true;
    final currentStreak = streak == null
        ? null
        : (streak['currentStreak'] is int
            ? streak['currentStreak'] as int
            : int.tryParse(streak['currentStreak'].toString()) ?? 0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(AppRoutes.checkIn),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.calendar_month_rounded,
                  size: 20, color: AppColors.primary),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signedToday ? '今日已签到' : '每日签到',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface),
                  ),
                  SizedBox(height: 2),
                  Text(
                    currentStreak == null
                        ? '点击查看签到奖励'
                        : '已连续签到 $currentStreak 天',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.onSurfaceVariant),
          ]),
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
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isLoggedIn) return SizedBox(height: 12);

    // PetMoodSection 内部处理加载/空状态，外层不再判断，避免反复切换导致抖动
    return Column(
      children: [
        SizedBox(height: 22),
        PetMoodSection(),
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
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.textOnBrand,
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
    final accent = device.isOnline ? AppColors.statusOnline : AppColors.statusNeutral;

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
                                ? AppColors.statusOnline
                                : AppColors.statusNeutral,
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
