import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_colors.dart';

/// 个人中心页 — 设计稿 Image 7/8 还原
/// 布局：玻璃态 AppBar → 用户信息卡 → My Pets → 菜单列表 → 退出按钮
/// 设计特点：
///   - 用户信息区：surfaceContainerLow，头像带 LV.badge
///   - 宠物卡：surfaceContainerLowest + 品牌阴影，无分割线
///   - 状态 Badge：secondaryFixed（已接种）/ errorContainer（待复诊）
///   - 菜单区：surfaceContainerLow，逐项用色调 Hover
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // TODO: 从 Riverpod provider 读取
  static const bool _isLoggedIn = true;

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) return _GuestProfileView();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface.withOpacity(0.9),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            title: Row(
              children: [
                Icon(Icons.pets_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 6),
                Text(
                  'PetPogo',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_rounded, color: AppColors.onSurfaceVariant),
                onPressed: () {},
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    shape: BoxShape.circle,
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

                // ── 用户信息卡 ────────────────────────
                _UserInfoCard(),

                const SizedBox(height: 28),

                // ── My Pets ────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Pets',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: Icon(Icons.add_circle_rounded, size: 16, color: AppColors.primary),
                      label: Text(
                        'Add New',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _PetCard(
                  name: 'Doudou',
                  breed: 'British Shorthair',
                  type: 'CAT',
                  typeColor: AppColors.secondaryContainer,
                  typeTextColor: AppColors.onSecondaryContainer,
                  statusLabel: 'VACCINATED',
                  statusOk: true,
                  emoji: '🐱',
                ),

                const SizedBox(height: 10),

                _PetCard(
                  name: 'Max',
                  breed: 'Golden Retriever',
                  type: 'DOG',
                  typeColor: AppColors.tertiaryContainer.withOpacity(0.7),
                  typeTextColor: AppColors.onTertiaryFixed,
                  statusLabel: 'CHECKUP DUE',
                  statusOk: false,
                  emoji: '🐕',
                ),

                const SizedBox(height: 28),

                // ── 菜单列表 ──────────────────────────
                _MenuGroup(items: [
                  _MenuItemData(
                    icon: Icons.devices_rounded,
                    label: 'Bound Devices',
                    onTap: () {},
                  ),
                  _MenuItemData(
                    icon: Icons.receipt_long_rounded,
                    label: 'Order History',
                    onTap: () {},
                  ),
                  _MenuItemData(
                    icon: Icons.grid_view_rounded,
                    label: 'My Posts',
                    onTap: () {},
                  ),
                  _MenuItemData(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: () => context.push('/settings'),
                  ),
                ]),

                const SizedBox(height: 32),

                // ── 退出按钮 ──────────────────────────
                Center(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                    label: Text(
                      'Log Out',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                        letterSpacing: 0.2,
                      ),
                    ),
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

// ── 用户信息卡 ────────────────────────────────────────
class _UserInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 24,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        children: [
          // 头像 + LV 角标
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHigh,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🧑', style: TextStyle(fontSize: 38)),
                ),
              ),
              // LV badge
              Positioned(
                bottom: -4, right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: Text(
                    'LV. 12',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onTertiaryFixed,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 20),

          // 名字 + 描述 + 统计
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alex Rivera',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  'Pet Parent since 2022',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 12),

                // 统计行 — 无分割线，用 16px 间距
                Row(
                  children: [
                    _StatCol(value: '24', label: 'POSTS'),
                    const SizedBox(width: 20),
                    _StatCol(value: '1.2k', label: 'FOLLOWERS'),
                    const SizedBox(width: 20),
                    _StatCol(value: '850', label: 'FOLLOWING'),
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

class _StatCol extends StatelessWidget {
  final String value, label;
  const _StatCol({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ── 宠物卡 ─────────────────────────────────────────────
class _PetCard extends StatelessWidget {
  final String name, breed, type, statusLabel, emoji;
  final Color typeColor, typeTextColor;
  final bool statusOk;

  const _PetCard({
    required this.name,
    required this.breed,
    required this.type,
    required this.typeColor,
    required this.typeTextColor,
    required this.statusLabel,
    required this.statusOk,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 宠物头像（2rem 圆角，设计规范）
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16), // 2rem ≈ 16dp
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 36)),
            ),
          ),

          const SizedBox(width: 16),

          // 信息 — 无分割线，用 6px 间距替代
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 类型 Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: typeTextColor,
                        ),
                      ),
                    ),
                  ],
                ),

                // 白空间替代分割线 (6px)
                const SizedBox(height: 4),
                Text(
                  breed,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 8),

                // 状态 Badge
                Row(
                  children: [
                    Icon(
                      statusOk ? Icons.check_circle_rounded : Icons.warning_rounded,
                      size: 14,
                      color: statusOk ? AppColors.online : AppColors.error,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: statusOk ? AppColors.secondary : AppColors.error,
                      ),
                    ),
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

// ── 菜单组 ─────────────────────────────────────────────
class _MenuGroup extends StatelessWidget {
  final List<_MenuItemData> items;
  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isFirst = e.key == 0;
          final isLast  = e.key == items.length - 1;
          return _MenuItemRow(
            data: e.value,
            isFirst: isFirst,
            isLast: isLast,
          );
        }).toList(),
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
                // 图标 — 白色圆形背景（设计稿还原）
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(data.icon, size: 20, color: AppColors.primary),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Text(
                    data.label,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),

                Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 游客视图 ──────────────────────────────────────────
class _GuestProfileView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.person_rounded, size: 48, color: AppColors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '游客模式',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '绑定手机号，享受完整功能',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () {},
              child: const Text('登录 / 注册'),
            ),
          ],
        ),
      ),
    );
  }
}
