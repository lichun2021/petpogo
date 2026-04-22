import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'shared/theme/app_theme.dart';
import 'shared/theme/app_colors.dart';
import 'features/home/home_page.dart';
import 'features/message/message_page.dart';
import 'features/community/community_page.dart';
import 'features/mall/mall_page.dart';
import 'features/profile/profile_page.dart';
import 'features/bind_device/select_device_page.dart';
import 'features/bind_device/scan_qr_page.dart';
import 'features/profile/settings_page.dart';

class PetPogoApp extends ConsumerWidget {
  const PetPogoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'PetPogo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/',          builder: (_, __) => const HomePage()),
        GoRoute(path: '/message',   builder: (_, __) => const MessagePage()),
        GoRoute(path: '/community', builder: (_, __) => const CommunityPage()),
        GoRoute(path: '/mall',      builder: (_, __) => const MallPage()),
        GoRoute(path: '/profile',   builder: (_, __) => const ProfilePage()),
      ],
    ),
    GoRoute(path: '/settings',       builder: (_, __) => const SettingsPage()),
    GoRoute(path: '/bind-device',    builder: (_, __) => const SelectDevicePage()),
    GoRoute(
      path: '/scan-qr/:deviceType',
      builder: (_, state) => ScanQrPage(deviceType: state.pathParameters['deviceType'] ?? 'KeyTracker'),
    ),
  ],
);

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _tabs = ['/', '/message', '/community', '/mall', '/profile'];

  static const _navItems = [
    _NavItem(icon: Icons.home_outlined,        activeIcon: Icons.home_rounded,          label: 'Home'),
    _NavItem(icon: Icons.chat_bubble_outline,   activeIcon: Icons.chat_bubble_rounded,   label: 'Message'),
    _NavItem(icon: Icons.people_outline,        activeIcon: Icons.people_rounded,        label: 'Community'),
    _NavItem(icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded,  label: 'Mall'),
    _NavItem(icon: Icons.person_outline,        activeIcon: Icons.person_rounded,        label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: widget.child,
      // ── 玻璃态底部导航栏（Glass & Gradient rule）──────
      extendBody: true,
      bottomNavigationBar: _GlassBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          context.go(_tabs[index]);
        },
        items: _navItems,
      ),
    );
  }
}

// ── 玻璃态导航栏实现 ──────────────────────────────────
class _GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;

  const _GlassBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        decoration: BoxDecoration(
          // surface 70% 透明度 + blur 24px — 设计规范 Glass rule
          color: AppColors.surface.withOpacity(0.88),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ambientShadow,
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final selected = currentIndex == i;
                return _NavButton(
                  item: item,
                  selected: selected,
                  onTap: () => onTap(i),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 18 : 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          // Active：暖橙 pill 背景（设计稿原样）
          color: selected ? AppColors.primaryContainer.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? item.activeIcon : item.icon,
              color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
