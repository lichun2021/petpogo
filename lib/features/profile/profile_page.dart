import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/theme/app_colors.dart';
import '../../app.dart' show AppL10nX;
import '../auth/controller/auth_controller.dart';
import '../auth/data/models/auth_model.dart';
import '../community/data/post_repository.dart';
import '../pet/controller/pet_controller.dart';
import 'data/user_stats_provider.dart';
import '../../core/router/app_routes.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final l10n     = context.l10n;
    final auth     = ref.watch(authControllerProvider);
    final petState = ref.watch(petControllerProvider);
    final stats    = ref.watch(userStatsProvider).stats;

    // 登录后首次刷新数据
    if (auth.isLoggedIn && !_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(userStatsProvider.notifier).loadMyStats();
        ref.read(petControllerProvider.notifier).loadPets();
      });
    }

    if (!auth.isLoggedIn) return _GuestProfileView();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── AppBar 固定 ─────────────────────────────
          SliverAppBar(
            pinned: true,          // 固定顶部
            floating: false,
            backgroundColor: AppColors.surface.withOpacity(0.95),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            title: const SizedBox.shrink(), // 隐藏标题
            actions: [
              IconButton(icon: Icon(Icons.notifications_rounded, color: AppColors.onSurfaceVariant), onPressed: () {}),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(Icons.person_rounded, size: 20, color: AppColors.onSurface),
                ),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                _UserInfoCard(l10n: l10n, user: auth.user, stats: stats),
                const SizedBox(height: 28),

                // ── My Pets ─────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.profileMyPets,
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 20,
                            fontWeight: FontWeight.w700, color: AppColors.onSurface, letterSpacing: -0.3)),
                    TextButton.icon(
                      onPressed: () => context.push('/add-pet'),
                      icon: Icon(Icons.add_circle_rounded, size: 16, color: AppColors.primary),
                      label: Text(l10n.profileAddNew,
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                              fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 真实宠物列表 — 横向 PageView
                if (petState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (petState.pets.isEmpty)
                  _EmptyPets(l10n: l10n)
                else
                  _PetPageView(
                    pets: petState.pets,
                    speciesLabel: _speciesLabel,
                  ),

                const SizedBox(height: 10),

                // ── 菜单 ─────────────────────────────
                _MenuGroup(items: [
                  _MenuItemData(icon: Icons.devices_rounded,      label: l10n.profileBoundDevices,  onTap: () {}),
                  _MenuItemData(icon: Icons.receipt_long_rounded,  label: l10n.profileOrderHistory,  onTap: () {}),
                  _MenuItemData(icon: Icons.grid_view_rounded,     label: l10n.profileMyPosts,       onTap: () {}),
                  _MenuItemData(icon: Icons.settings_rounded,      label: l10n.profileSettings,      onTap: () => context.push('/settings')),
                ]),

                const SizedBox(height: 32),

                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                    },
                    icon: Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                    label: Text(l10n.profileLogout,
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                            fontWeight: FontWeight.w700, color: AppColors.error, letterSpacing: 0.2)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserInfoCard extends ConsumerStatefulWidget {
  final dynamic l10n;
  final UserInfo? user;
  final dynamic stats;
  const _UserInfoCard({required this.l10n, required this.user, this.stats});

  @override
  ConsumerState<_UserInfoCard> createState() => _UserInfoCardState();
}

class _UserInfoCardState extends ConsumerState<_UserInfoCard> {
  bool _uploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    // 弹出选择来源的底部菜单
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('更换头像', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          const SizedBox(height: 8),
          _AvatarSourceTile(
            icon: Icons.camera_alt_rounded,
            label: '拍照',
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          _AvatarSourceTile(
            icon: Icons.photo_library_rounded,
            label: '从相册选择',
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
          Divider(color: AppColors.onSurfaceVariant.withOpacity(0.1), height: 1),
          _AvatarSourceTile(
            icon: Icons.close_rounded,
            label: '取消',
            iconColor: AppColors.onSurfaceVariant,
            textColor: AppColors.onSurfaceVariant,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
      preferredCameraDevice: CameraDevice.front, // 默认前置（自拍）
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final file = File(picked.path);
      final repo = ref.read(postRepositoryProvider);
      final sign = await repo.getOssSign(fileType: 'image', folder: 'avatars');
      await repo.uploadToOss(uploadUrl: sign.uploadUrl, file: file, contentType: 'image/jpeg');
      final ok = await ref.read(authControllerProvider.notifier).updateAvatar(sign.cdnUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '头像更新成功 🎉' : '头像更新失败，请重试'),
          backgroundColor: ok ? AppColors.primary : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('上传失败：$e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n      = widget.l10n;
    final user      = widget.user;
    final stats     = widget.stats;
    final nickname    = user?.name.isNotEmpty == true ? user!.name : '宠友';
    final phone       = user?.account ?? '';
    final maskedPhone = phone.length == 11
        ? '${phone.substring(0, 3)}****${phone.substring(7)}'
        : phone;
    final avatarUrl   = user?.avatar ?? '';

    final postStr     = stats != null ? '${stats.postCount}'     : '0';
    final followerStr = stats != null ? '${stats.followerCount}' : '0';
    final likeStr     = stats != null ? '${stats.likeCount}'     : '0';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 24, spreadRadius: -6)],
      ),
      child: Row(
        children: [
          // ── 头像（可点击上传）───────────────────────────────
          GestureDetector(
            onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainerHigh,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12)],
                  ),
                  child: ClipOval(
                    child: _uploadingAvatar
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                        : avatarUrl.isNotEmpty
                            ? CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    const Center(child: Text('🧑', style: TextStyle(fontSize: 38))))
                            : const Center(child: Text('🧑', style: TextStyle(fontSize: 38))),
                  ),
                ),
                // 相机图标覆盖
                if (!_uploadingAvatar)
                  Positioned(
                    bottom: 2, right: 2,
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // ── 用户信息 ───────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname,
                    style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans', fontSize: 20,
                        fontWeight: FontWeight.w800, letterSpacing: -0.4,
                        color: AppColors.onSurface)),
                if (maskedPhone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(maskedPhone,
                      style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                          color: AppColors.onSurfaceVariant)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCol(value: postStr,     label: l10n.profilePosts),
                    const SizedBox(width: 20),
                    _StatCol(value: followerStr, label: l10n.profileFollowers),
                    const SizedBox(width: 20),
                    _StatCol(value: likeStr,     label: '获赞'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 工具函数 ───────────────────────────────────────────
String _speciesLabel(String type) {
  switch (type) {
    case 'cat':     return '猫';
    case 'dog':     return '狗';
    case 'rabbit':  return '兔子';
    case 'hamster': return '仓鼠';
    case 'bird':    return '鸟';
    case 'fish':    return '鱼';
    default:        return '宠物';
  }
}

// ── 宠物列表为空占位符 ────────────────────────────────
class _EmptyPets extends StatelessWidget {
  final dynamic l10n;
  const _EmptyPets({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text('🐾', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('还没有宠物，快去添加第一只吧！',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                  color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String value, label;
  const _StatCol({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17,
            fontWeight: FontWeight.w800, color: AppColors.primary)),
        Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}

// ── 宠物卡片可滑动容器（PageView + 圆点指示）──────────────────
class _PetPageView extends StatefulWidget {
  final List pets;
  final String Function(String) speciesLabel;
  const _PetPageView({required this.pets, required this.speciesLabel});

  @override
  State<_PetPageView> createState() => _PetPageViewState();
}

class _PetPageViewState extends State<_PetPageView> {
  int _page = 0;
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pets = widget.pets;
    return Column(
      children: [
        SizedBox(
          height: 88,  // 紧凑高度
          child: PageView.builder(
            controller: _ctrl,
            itemCount: pets.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final pet = pets[i] as dynamic;
              return GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed('/pet-detail'),
                  child: _PetCard(
                    name:          pet.name as String,
                    breed:         pet.breed as String,
                    type:          widget.speciesLabel(pet.type as String),
                    typeColor:     pet.type == 'cat'
                        ? AppColors.secondaryContainer
                        : AppColors.tertiaryContainer,
                    typeTextColor: pet.type == 'cat'
                        ? AppColors.onSecondaryContainer
                        : AppColors.onTertiaryFixed,
                    emoji:         pet.emoji as String,
                    gender:        pet.gender as String,
                    birthday:      pet.birthday as String,
                  ),
              );
            },
          ),
        ),
        // 圆点指示（只有多宠物时显示）
        if (pets.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pets.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width:  i == _page ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _page
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant.withOpacity(0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            )),
          ),
        ],
      ],
    );
  }
}


// ── 宠物卡片（渐变设计）────────────────────────────────────
class _PetCard extends StatelessWidget {
  final String name, breed, type, emoji, gender, birthday;
  final Color typeColor, typeTextColor;

  const _PetCard({
    required this.name,
    required this.breed,
    required this.type,
    required this.typeColor,
    required this.typeTextColor,
    required this.emoji,
    this.gender = '',
    this.birthday = '',
  });

  // 物种对应渐变色
  List<Color> get _gradients => type == '猫'
      ? [const Color(0xFF6EC6F5), const Color(0xFF4A90D9)]
      : [const Color(0xFFFFB347), const Color(0xFFE07B39)];

  String _ageText() {
    if (birthday.isEmpty) return '';
    try {
      final birth = DateTime.parse(birthday);
      final now   = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) age--;
      if (age <= 0) {
        final months = (now.year - birth.year) * 12 + now.month - birth.month;
        return months <= 0 ? '刚出生' : '$months个月';
      }
      return '$age岁';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final age    = _ageText();
    final isMale = gender == 'male';
    final isFemale = gender == 'female';
    final gLabel = isMale ? '♂ 公' : isFemale ? '♀ 母' : '';
    final gColor = isMale ? const Color(0xFF1A6BB5) : const Color(0xFFB51A6B);
    final gBg    = isMale ? const Color(0xFFDCEEFF) : const Color(0xFFFFDCEE);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: _gradients,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _gradients.first.withOpacity(0.45),
            blurRadius: 24, spreadRadius: -4, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ── 装饰圆圈（背景） ──────────────────────
          Positioned(
            right: -18, top: -18,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            right: 30, bottom: -30,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),

          // ── 内容 ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                // 左：emoji + 光晕
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.30),
                            blurRadius: 10, spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(emoji,
                            style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // 右：信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 名字 + 性别
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.3)),
                          ),
                          if (gLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: gBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(gLabel,
                                    style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: gColor)),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // 品种
                      if (breed.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(breed,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.80))),
                      ],

                      const SizedBox(height: 4),

                      // 年龄 + 生日 chips（白底半透明）
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (age.isNotEmpty)
                            _WhiteChip(
                                icon: Icons.cake_rounded, label: age),
                          if (birthday.isNotEmpty)
                            _WhiteChip(
                                icon: Icons.calendar_today_rounded,
                                label: birthday.length >= 10
                                    ? birthday.substring(0, 10)
                                    : birthday),
                        ],
                      ),
                    ],
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

// 白色半透明小 chip（用于渐变卡片上）
class _WhiteChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _WhiteChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.25),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.white),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
    ]),
  );
}




class _MenuGroup extends StatelessWidget {
  final List<_MenuItemData> items;
  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: items.asMap().entries.map((e) => _MenuItemRow(
          data: e.value, isFirst: e.key == 0, isLast: e.key == items.length - 1,
        )).toList(),
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItemData({required this.icon, required this.label, required this.onTap});
}

class _MenuItemRow extends StatelessWidget {
  final _MenuItemData data;
  final bool isFirst, isLast;
  const _MenuItemRow({required this.data, required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(20) : Radius.zero,
        bottom: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: data.onTap,
          splashColor: AppColors.primaryGlow,
          highlightColor: AppColors.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 8)]),
                  child: Icon(data.icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(data.label,
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                        fontWeight: FontWeight.w600, color: AppColors.onSurface))),
                Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 头像来源选项行 ─────────────────────────────────────────────
class _AvatarSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _AvatarSourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: iconColor ?? AppColors.primary),
          ),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 15, fontWeight: FontWeight.w600,
            color: textColor ?? AppColors.onSurface,
          )),
        ]),
      ),
    ),
  );
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
              width: 100, height: 100,
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
              child: const Center(child: Icon(Icons.person_rounded, size: 48, color: AppColors.onSurfaceVariant)),
            ),
            const SizedBox(height: 20),
            Text(l10n.profileGuestMode,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 20,
                    fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            const SizedBox(height: 8),
            Text(l10n.profileGuestSubtitle,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 28),
            ElevatedButton(
                onPressed: () => context.push(AppRoutes.login),
                child: Text(l10n.profileLoginRegister)),
          ],
        ),
      ),
    );
  }
}
