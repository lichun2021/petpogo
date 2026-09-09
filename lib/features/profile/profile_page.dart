import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/utils/image_pick_helper.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import '../../app.dart' show AppL10nX;
import '../auth/controller/auth_controller.dart';
import '../auth/data/models/auth_model.dart';
import '../community/data/post_repository.dart';
import '../device/device_list_page.dart';
import '../pet/controller/pet_controller.dart';
import '../pet/pet_list_page.dart';
import '../music/pet_music_page.dart';
import 'data/user_stats_provider.dart';
import 'data/points_repository.dart';
import '../../core/router/app_routes.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';
import '../../shared/utils/error_presenter.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _loaded = false;
  bool _uploadingAvatar = false;
  bool _showAllFeatures = false;
  Map<String, dynamic>? _pointsBalance;

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  Future<void> _loadPointsBalance() async {
    try {
      final balance = await ref.read(pointsRepositoryProvider).fetchBalance();
      if (!mounted) return;
      setState(() => _pointsBalance = balance);
    } catch (e) {
      debugPrint('[积分] 我的页面余额加载失败: $e');
    }
  }

  // ── 昵称编辑 ──
  void _showNicknameSheet(BuildContext context, WidgetRef ref) {
    final user = ref.read(authControllerProvider).user;
    final ctrl = TextEditingController(text: user?.name ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _NicknameInlineSheet(ctrl: ctrl),
    );
  }

  // ── 头像上传 ──
  Future<void> _pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
    if (_uploadingAvatar) return;
    final file = await ImagePickHelper.pickAndCropAvatar(context);
    if (file == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final repo = ref.read(postRepositoryProvider);
      final sign = await repo.getOssSign(fileType: 'image', folder: 'avatars');
      await repo.uploadToOss(
          uploadUrl: sign.uploadUrl, file: file, contentType: 'image/jpeg');
      final ok = await ref
          .read(authControllerProvider.notifier)
          .updateAvatar(sign.cdnUrl ?? '');
      if (!context.mounted) return;
      PetToast.show(context, ok ? '头像更新成功 🎉' : '头像更新失败，请重试');
    } catch (e) {
      if (!context.mounted) return;
      PetToast.error(context, '上传失败，请重试');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _openGiftedPointsPage() async {
    await context.push(AppRoutes.giftedPoints);
    if (!mounted) return;
    _loadPointsBalance();
  }

  void _openPointsRulesPage() {
    context.push(AppRoutes.pointsRules);
  }

  Future<void> _openPointsPage() async {
    await context.push(AppRoutes.points);
    if (!mounted) return;
    ref.read(authControllerProvider.notifier).refreshUser();
    _loadPointsBalance();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authControllerProvider);

    // 登录后首次刷新数据
    if (auth.isLoggedIn && !_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(userStatsProvider.notifier).loadMyStats();
        ref.read(petControllerProvider.notifier).loadPets();
        // 拉取最新配额（包含 aiQuota）
        ref.read(authControllerProvider.notifier).refreshUser();
        _loadPointsBalance();
      });
    }

    if (!auth.isLoggedIn) return _GuestProfileView();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── AppBar：右上角设置入口 ─────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            title: const SizedBox.shrink(),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded, size: 22),
                color: AppColors.onSurfaceVariant,
                tooltip: '通知中心',
                onPressed: () => context.go(AppRoutes.message),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded, size: 22),
                color: AppColors.onSurfaceVariant,
                tooltip: l10n.profileSettings,
                onPressed: () => context.push(AppRoutes.settings),
              ),
              const SizedBox(width: 8),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── 顶部横排资料条 ──
                _ProfileHeader(
                  user: auth.user,
                  uploadingAvatar: _uploadingAvatar,
                  onTapEdit: () => _showNicknameSheet(context, ref),
                  onTapAvatar: () => _pickAndUploadAvatar(context, ref),
                ),
                const SizedBox(height: 20),

                // ── 积分概览：余额、赠送积分、流水入口 ──
                _PointsOverviewCard(
                  points: _pointsBalance == null
                      ? auth.user?.points ?? 0
                      : _asInt(_pointsBalance?['total']),
                  permanentPoints: _pointsBalance == null
                      ? auth.user?.permanentPoints ?? 0
                      : _asInt(_pointsBalance?['permanent']),
                  giftedPoints: _pointsBalance == null
                      ? auth.user?.giftedPoints ?? 0
                      : _asInt(_pointsBalance?['expiring']),
                  onTapTotal: _openPointsPage,
                  onTapGifted: _openGiftedPointsPage,
                  onTapRules: _openPointsRulesPage,
                ),
                const SizedBox(height: 20),

                // ── 功能区 ──
                _FeatureGrid(
                  expanded: _showAllFeatures,
                  onToggleExpanded: () =>
                      setState(() => _showAllFeatures = !_showAllFeatures),
                  onNav: (route) => context.push(route),
                  onNavPush: (page) => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => page)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  积分概览卡
// ════════════════════════════════════════════════════════════
class _PointsOverviewCard extends StatelessWidget {
  final int points;
  final int permanentPoints;
  final int giftedPoints;
  final VoidCallback onTapTotal;
  final VoidCallback onTapGifted;
  final VoidCallback onTapRules;
  const _PointsOverviewCard({
    required this.points,
    required this.permanentPoints,
    required this.giftedPoints,
    required this.onTapTotal,
    required this.onTapGifted,
    required this.onTapRules,
  });

  String _formatPoints(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surfaceSunken, AppColors.surfaceCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PointsCardEntry(
                    label: '总积分',
                    value: _formatPoints(points),
                    subtitle: '积分明细',
                    onTap: onTapTotal,
                    prominent: true,
                  ),
                ),
                const _PointsCardDivider(),
                Expanded(
                  child: _PointsCardEntry(
                    label: '永久积分',
                    value: _formatPoints(permanentPoints),
                    subtitle: '永久有效',
                  ),
                ),
                const _PointsCardDivider(),
                Expanded(
                  child: _PointsCardEntry(
                    label: '赠送积分',
                    value: _formatPoints(giftedPoints),
                    subtitle: '到期明细',
                    onTap: onTapGifted,
                  ),
                ),
              ],
            ),
          ),
          // Material(
          //   color: Colors.transparent,
          //   child: InkWell(
          //     onTap: onTapRules,
          //     child: Padding(
          //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          //       child: Row(children: [
          //         const Icon(Icons.rule_rounded,
          //             size: 16, color: AppColors.brandPrimaryStrong),
          //         const SizedBox(width: 6),
          //         Expanded(
          //           child: Text('积分消费规则',
          //               style: TextStyle(
          //                   fontFamily: AppFonts.primary,
          //                   fontSize: 11,
          //                   fontWeight: FontWeight.w700,
          //                   color: const AppColors.brandPrimaryStrong)),
          //         ),
          //         const Icon(Icons.chevron_right_rounded,
          //             size: 16, color: AppColors.brandPrimaryStrong),
          //       ]),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _PointsCardEntry extends StatelessWidget {
  final String label;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool prominent;
  const _PointsCardEntry({
    required this.label,
    this.value,
    this.subtitle,
    this.onTap,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.brandPrimaryStrong;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null) ...[
                  Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: prominent ? 22 : 15,
                      height: 1.1,
                      fontWeight: prominent ? FontWeight.w900 : FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: onTap == null
                              ? AppColors.onSurfaceVariant
                              : accent,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 9,
                          color: AppColors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PointsCardDivider extends StatelessWidget {
  const _PointsCardDivider();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 1,
        height: 32,
        color: AppColors.borderSubtle,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  顶部横排资料条（极简风，贴合页面背景）
// ════════════════════════════════════════════════════════════
class _ProfileHeader extends StatelessWidget {
  final UserInfo? user;
  final bool uploadingAvatar;
  final VoidCallback onTapEdit;
  final VoidCallback onTapAvatar;
  const _ProfileHeader({
    required this.user,
    required this.uploadingAvatar,
    required this.onTapEdit,
    required this.onTapAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final nickname = (user?.name.isNotEmpty ?? false) ? user!.name : '宠友';
    final isVip = user?.isVip ?? false;
    final vipLevel = user?.vipLevel;
    final vipLabel = vipLevel == 'pro_max'
        ? 'Pro Max'
        : vipLevel == 'pro'
            ? 'Pro'
            : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // 头像
          GestureDetector(
            onTap: onTapAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.8),
                        width: 1),
                  ),
                  child: ClipOval(
                    child: user?.avatar.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: user!.avatar,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                color: AppColors.surfaceContainerHighest),
                            errorWidget: (_, __, ___) => _avatarPlaceholder(),
                          )
                        : _avatarPlaceholder(),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surface,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: uploadingAvatar
                          ? SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.onPrimary),
                              ),
                            )
                          : Icon(Icons.camera_alt_rounded,
                              size: 12, color: AppColors.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // 昵称 + VIP 徽章
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (isVip && vipLabel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _VipBadge(label: vipLabel),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID：${user?.id ?? user?.merchantId ?? ''}',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // 编辑入口
          GestureDetector(
            onTap: onTapEdit,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('编辑',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant)),
                  Icon(Icons.chevron_right_rounded,
                      size: 14, color: AppColors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
        color: AppColors.surfaceContainerHighest,
        child: Icon(Icons.person_rounded,
            size: 30, color: AppColors.onSurfaceVariant),
      );
}

class _VipBadge extends StatelessWidget {
  final String label;
  const _VipBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandPrimary, AppColors.brandPrimaryStrong],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded,
              size: 10, color: Colors.white),
          const SizedBox(width: 2),
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  功能区：两列信息卡，默认最多 6 个功能
// ════════════════════════════════════════════════════════════
class _FeatureGrid extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onNav; // 走 AppRoutes（push）
  final ValueChanged<Widget> onNavPush; // 走 Navigator.push（传页面实例）
  const _FeatureGrid({
    required this.expanded,
    required this.onToggleExpanded,
    required this.onNav,
    required this.onNavPush,
  });

  @override
  Widget build(BuildContext context) {
    const collapsedItemCount = 6;
    // 分层规则：核心资产（宠物 / 设备）用品牌色；内容与活动类用中性色
    final items = <_FeatureItem>[
      _FeatureItem(
        icon: Icons.pets_outlined,
        label: '我的宠物',
        subtitle: '宠物档案',
        color: AppColors.brandPrimary,
        onTap: () => onNavPush(PetListPage()),
      ),
      _FeatureItem(
        icon: Icons.devices_outlined,
        label: '我的设备',
        subtitle: '硬件管理',
        color: AppColors.brandPrimary,
        onTap: () => onNavPush(DeviceListPage()),
      ),
      _FeatureItem(
        icon: Icons.grid_view_outlined,
        label: '我的帖子',
        subtitle: '发布记录',
        color: AppColors.statusNeutral,
        onTap: () => PetToast.show(context, '我的帖子功能即将上线'),
      ),
      _FeatureItem(
        icon: Icons.music_note_outlined,
        label: '宠物音乐',
        subtitle: '舒缓歌单',
        color: AppColors.statusNeutral,
        onTap: () => onNavPush(PetMusicPage()),
      ),
      _FeatureItem(
        icon: Icons.calendar_month_outlined,
        label: '每日签到',
        subtitle: '做任务领章卡',
        color: AppColors.statusNeutral,
        badge: '待签', // TODO: 接签到状态后判断是否显示
        onTap: () => onNav(AppRoutes.checkIn),
      ),
      _FeatureItem(
        icon: Icons.workspace_premium_outlined,
        label: '会员计划',
        subtitle: '解锁更多权益',
        color: AppColors.statusNeutral,
        onTap: () => onNav(AppRoutes.membership),
      ),
    ];
    final hasMore = items.length > collapsedItemCount;
    final visibleItems =
        hasMore && !expanded ? items.take(collapsedItemCount).toList() : items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 展开/收起只靠 AnimatedSize 平滑改变高度，
        // 不再用 AnimatedSwitcher 整体淡入淡出（那会抖动）。
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 12,
              childAspectRatio: 2.42,
            ),
            itemCount: visibleItems.length,
            itemBuilder: (_, i) => _FeatureTile(item: visibleItems[i]),
          ),
        ),
        if (hasMore) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _FeatureMoreButton(
              expanded: expanded,
              onTap: onToggleExpanded,
            ),
          ),
        ],
      ],
    );
  }
}

class _FeatureMoreButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  const _FeatureMoreButton({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 文字颜色随展开状态平滑过渡
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              child: Text(expanded ? '收起' : '更多'),
            ),
            const SizedBox(width: 2),
            // 箭头方向旋转过渡
            AnimatedRotation(
              turns: expanded ? -0.5 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge; // 右上角小气泡（如"待签"）
  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });
}

class _FeatureTile extends StatelessWidget {
  final _FeatureItem item;
  const _FeatureTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.color == AppColors.statusNeutral
                          ? AppColors.surfaceSunken
                          : AppColors.brandPrimarySoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(item.icon, size: 22, color: item.color),
                  ),
                  if (item.badge != null)
                    Positioned(
                      top: -7,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statusAlert,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.surfaceContainerLowest,
                            width: 1.5,
                          ),
                        ),
                        child: Text(item.badge!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                height: 1.2)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestProfileView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
              child: Center(
                  child: Icon(Icons.person_rounded,
                      size: 48, color: AppColors.onSurfaceVariant)),
            ),
            SizedBox(height: 20),
            Text(l10n.profileGuestMode,
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface)),
            SizedBox(height: 8),
            Text(l10n.profileGuestSubtitle,
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant)),
            SizedBox(height: 28),
            ElevatedButton(
                onPressed: () => context.push(AppRoutes.login),
                child: Text(l10n.profileLoginRegister)),
          ],
        ),
      ),
    );
  }
}

// ── 昵称编辑 Sheet（内联在 profile_page 中）───────────────
class _NicknameInlineSheet extends ConsumerStatefulWidget {
  final TextEditingController ctrl;
  const _NicknameInlineSheet({required this.ctrl});

  @override
  ConsumerState<_NicknameInlineSheet> createState() =>
      _NicknameInlineSheetState();
}

class _NicknameInlineSheetState extends ConsumerState<_NicknameInlineSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final name = widget.ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '昵称不能为空');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateNickname(name);
      if (!mounted) return;
      Navigator.pop(context);
      PetToast.success(context, '昵称已更新');
    } catch (e) {
      setState(() {
        _loading = false;
        _error = ErrorPresenter.message(e, fallback: '昵称更新失败，请稍后重试');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('修改昵称',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14)),
            child: TextField(
              controller: widget.ctrl,
              autofocus: true,
              style: TextStyle(fontFamily: AppFonts.primary, fontSize: 15),
              decoration: InputDecoration(
                hintText: '输入新昵称',
                hintStyle: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontFamily: AppFonts.primary,
                    fontSize: 14),
                prefixIcon: Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 20),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                elevation: 0,
              ),
              child: _loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('保存',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}
