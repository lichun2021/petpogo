import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'shared/theme/app_theme.dart';
import 'shared/theme/app_colors.dart';
import 'core/providers/locale_provider.dart';
import 'features/home/home_page.dart';
import 'features/message/message_page.dart';
import 'features/community/community_page.dart';
import 'features/mall/mall_page.dart';
import 'features/profile/profile_page.dart';
import 'features/bind_device/select_device_page.dart';
import 'features/bind_device/scan_qr_page.dart';
import 'features/bind_device/bind_success_page.dart';
import 'features/profile/settings_page.dart';
import 'features/pet/add_pet_page.dart';
import 'features/pet/pet_detail_page.dart';
import 'l10n/app_localizations.dart';

export 'l10n/app_localizations.dart';

/// 便捷扩展：直接 context.l10n 获取本地化实例
extension AppL10nX on BuildContext {
  AppL10n get l10n => AppL10n.of(this)!;
}

class PetPogoApp extends ConsumerWidget {
  const PetPogoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'PetPogo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,
      // 多语言支持
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh'),
        Locale('en'),
      ],
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
    GoRoute(path: '/settings',      builder: (_, __) => const SettingsPage()),
    GoRoute(path: '/bind-device',   builder: (_, __) => const SelectDevicePage()),
    GoRoute(
      path: '/scan-qr/:deviceType',
      builder: (_, state) => ScanQrPage(
        deviceType: state.pathParameters['deviceType'] ?? 'KeyTracker',
      ),
    ),
    GoRoute(path: '/bind-success/:deviceType',
      builder: (_, state) => BindSuccessPage(
        deviceType: state.pathParameters['deviceType'] ?? 'KeyTracker',
      ),
    ),
    GoRoute(path: '/add-pet',       builder: (_, __) => const AddPetPage()),
    GoRoute(path: '/pet-detail',    builder: (_, __) => const PetDetailPage()),
  ],
);

// ── Main Shell ────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _tabs = ['/', '/message', '/community', '/mall', '/profile'];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final navItems = [
      _NavItem(icon: Icons.home_outlined,        activeIcon: Icons.home_rounded,          label: l10n.navHome),
      _NavItem(icon: Icons.chat_bubble_outline,   activeIcon: Icons.chat_bubble_rounded,   label: l10n.navMessage),
      _NavItem(icon: Icons.people_outline,        activeIcon: Icons.people_rounded,        label: l10n.navCommunity),
      _NavItem(icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded,  label: l10n.navMall),
      _NavItem(icon: Icons.person_outline,        activeIcon: Icons.person_rounded,        label: l10n.navProfile),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: widget.child,
      extendBody: true,
      bottomNavigationBar: _GlassBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          context.go(_tabs[index]);
        },
        items: navItems,
      ),
    );
  }
}

// ── 玻璃态导航栏 ──────────────────────────────────────────────
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
          color: AppColors.surface.withOpacity(0.92),
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

class _NavButton extends StatefulWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(_NavButton old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _ctrl.forward(from: 0);
    } else if (!widget.selected && old.selected) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: widget.selected ? 18 : 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: widget.selected
              ? AppColors.primaryContainer.withOpacity(0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Icon(
                widget.selected ? widget.item.activeIcon : widget.item.icon,
                color: widget.selected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 10,
                fontWeight:
                    widget.selected ? FontWeight.w700 : FontWeight.w500,
                color: widget.selected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
              child: Text(widget.item.label),
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
