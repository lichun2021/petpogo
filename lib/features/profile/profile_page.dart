import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_colors.dart';
import '../../app.dart' show AppL10nX;

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const bool _isLoggedIn = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!_isLoggedIn) return _GuestProfileView();

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

                _UserInfoCard(l10n: l10n),
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

                GestureDetector(
                  onTap: () => context.push('/pet-detail'),
                  child: _PetCard(name: '豆豆', breed: '英短豆', type: '猫',
                    typeColor: AppColors.secondaryContainer, typeTextColor: AppColors.onSecondaryContainer,
                    statusLabel: l10n.profileVaccinated, statusOk: true, emoji: '🐱'),
                ),

                const SizedBox(height: 10),

                GestureDetector(
                  onTap: () => context.push('/pet-detail'),
                  child: _PetCard(name: '麦克斯', breed: '金毛寻回犬', type: '狗',
                    typeColor: AppColors.tertiaryContainer.withOpacity(0.7), typeTextColor: AppColors.onTertiaryFixed,
                    statusLabel: l10n.profileCheckupDue, statusOk: false, emoji: '🐕'),
                ),

                const SizedBox(height: 28),

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
                    onPressed: () {},
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

class _UserInfoCard extends StatelessWidget {
  final dynamic l10n;
  const _UserInfoCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 24, spreadRadius: -6)],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.surfaceContainerHigh,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12)],
                ),
                child: const Center(child: Text('🧑', style: TextStyle(fontSize: 38))),
              ),
              Positioned(
                bottom: -4, right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryContainer, borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: Text('LV. 12',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9,
                          fontWeight: FontWeight.w800, color: AppColors.onTertiaryFixed)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('李小明',
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 20,
                        fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.onSurface)),
                Text(l10n.profilePetParentSince('2022'),
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCol(value: '24',   label: l10n.profilePosts),
                    const SizedBox(width: 20),
                    _StatCol(value: '1.2k', label: l10n.profileFollowers),
                    const SizedBox(width: 20),
                    _StatCol(value: '850',  label: l10n.profileFollowing),
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
        Text(value, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17,
            fontWeight: FontWeight.w800, color: AppColors.primary)),
        Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}

class _PetCard extends StatelessWidget {
  final String name, breed, type, statusLabel, emoji;
  final Color typeColor, typeTextColor;
  final bool statusOk;

  const _PetCard({required this.name, required this.breed, required this.type,
    required this.typeColor, required this.typeTextColor,
    required this.statusLabel, required this.statusOk, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 20, spreadRadius: -5, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17,
                        fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(999)),
                      child: Text(type, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9,
                          fontWeight: FontWeight.w900, letterSpacing: 0.8, color: typeTextColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(breed, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(statusOk ? Icons.check_circle_rounded : Icons.warning_rounded,
                        size: 14, color: statusOk ? AppColors.online : AppColors.error),
                    const SizedBox(width: 5),
                    Text(statusLabel,
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                            fontWeight: FontWeight.w700, letterSpacing: 0.5,
                            color: statusOk ? AppColors.secondary : AppColors.error)),
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
            ElevatedButton(onPressed: () {}, child: Text(l10n.profileLoginRegister)),
          ],
        ),
      ),
    );
  }
}
