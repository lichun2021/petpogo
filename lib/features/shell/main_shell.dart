import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';
import '../../shared/theme/app_colors.dart';
import '../../app.dart' show AppL10nX;
import '../../shared/widgets/glass_bottom_nav.dart';

/// 全局控制底部导航栏显隐（全屏视频时隐藏）
final hideBottomNavProvider = StateProvider<bool>((ref) => false);

/// 底部 Tab 导航的外壳 Widget
///
/// 职责：
///   - 持有当前 Tab 索引（_currentIndex）
///   - 处理 Tab 点击 → 调用 context.go 切换路由
///   - 渲染 [GlassBottomNav]（纯 UI 无逻辑）
///
/// 由 app_router.dart 的 ShellRoute 使用，
/// Tab 切换时此 Widget 不会销毁重建，只换 child 内容区。
class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  // 使用 AppRoutes 常量，路径变更只改 AppRoutes 一处
  static const _tabs = [
    AppRoutes.home,       // '/'
    AppRoutes.message,    // '/message'
    AppRoutes.community,  // '/community'
    AppRoutes.mall,       // '/mall'
    AppRoutes.profile,    // '/profile'
  ];

  /// 根据当前路由路径计算选中 Tab（外部 go() 跳转时也能同步）
  int _indexFromLocation(String location) {
    for (int i = _tabs.length - 1; i >= 0; i--) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final navItems = [
      NavItem(icon: Icons.home_outlined,        activeIcon: Icons.home_rounded,          label: l10n.navHome),
      NavItem(icon: Icons.chat_bubble_outline,   activeIcon: Icons.chat_bubble_rounded,   label: l10n.navMessage),
      NavItem(icon: Icons.people_outline,        activeIcon: Icons.people_rounded,        label: l10n.navCommunity),
      NavItem(icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded,  label: l10n.navMall),
      NavItem(icon: Icons.person_outline,        activeIcon: Icons.person_rounded,        label: l10n.navProfile),
    ];

    final hideNav = ref.watch(hideBottomNavProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: widget.child,
      extendBody: hideNav,   // 全屏时 body 延伸到底部边缘
      bottomNavigationBar: hideNav
          ? null
          : GlassBottomNav(
              currentIndex: currentIndex,
              onTap: (index) => context.go(_tabs[index]),
              items: navItems,
            ),
    );
  }
}
