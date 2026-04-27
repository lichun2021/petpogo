import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';
import '../../shared/theme/app_colors.dart';
import '../../app.dart' show AppL10nX;
import '../../shared/widgets/glass_bottom_nav.dart';

/// 底部 Tab 导航的外壳 Widget
///
/// 职责：
///   - 持有当前 Tab 索引（_currentIndex）
///   - 处理 Tab 点击 → 调用 context.go 切换路由
///   - 渲染 [GlassBottomNav]（纯 UI 无逻辑）
///
/// 由 app_router.dart 的 ShellRoute 使用，
/// Tab 切换时此 Widget 不会销毁重建，只换 child 内容区。
class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 当前选中的 Tab 索引（0=首页 1=消息 2=社区 3=商城 4=我的）
  int _currentIndex = 0;

  // 使用 AppRoutes 常量，路径变更只改 AppRoutes 一处
  static const _tabs = [
    AppRoutes.home,       // '/'
    AppRoutes.message,    // '/message'
    AppRoutes.community,  // '/community'
    AppRoutes.mall,       // '/mall'
    AppRoutes.profile,    // '/profile'
  ];

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

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: widget.child,
      extendBody: false,        // 关闭：让系统自动为 body 预留导航栏高度
      bottomNavigationBar: GlassBottomNav(
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
