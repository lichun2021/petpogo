import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart'; // context.go() / context.push() 需要

import 'shared/theme/app_theme.dart';
import 'shared/theme/app_colors.dart';
import 'core/providers/locale_provider.dart';
import 'core/router/app_router.dart';   // ← 路由集中管理
import 'core/router/app_routes.dart';   // ← 路由路径常量
import 'l10n/app_localizations.dart';

export 'l10n/app_localizations.dart';

/// 便捷扩展：任意 Widget 内用 context.l10n 获取当前语言的翻译
extension AppL10nX on BuildContext {
  AppL10n get l10n => AppL10n.of(this)!;
}

/// 应用根 Widget
///
/// 职责：
///   1. 配置全局主题
///   2. 配置多语言（中/英）
///   3. 挂载路由（来自 core/router/app_router.dart）
///   4. 监听 localeProvider，语言切换时自动重建
class PetPogoApp extends ConsumerWidget {
  const PetPogoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听语言设置（设置页切换语言后自动触发重建）
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'PetPogo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,

      // ── 多语言代理 ─────────────────────────────────────────
      localizationsDelegates: const [
        AppL10n.delegate,                      // 项目自有翻译
        GlobalMaterialLocalizations.delegate,  // Material 组件翻译
        GlobalWidgetsLocalizations.delegate,   // Widget 方向支持
        GlobalCupertinoLocalizations.delegate, // Cupertino 组件翻译
      ],
      supportedLocales: const [
        Locale('zh'), // 中文（默认）
        Locale('en'), // English
      ],

      // ── 路由配置 ───────────────────────────────────────────
      // appRouter 定义在 core/router/app_router.dart
      // 所有页面路由、过渡动画、守卫逻辑都集中在那里管理
      routerConfig: appRouter,
    );
  }
}

// ── Main Shell ────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 当前选中的底部导航 Tab 索引（0=首页 1=消息 2=社区 3=商城 4=我的）
  int _currentIndex = 0;

  // ✅ 使用 AppRoutes 常量，不硬编码字符串
  // 修改路由路径时只需改 AppRoutes，这里自动同步
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
