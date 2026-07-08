import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

// ── 玻璃态底部导航栏 ──────────────────────────────────────
/// 底部导航栏 UI 组件
///
/// 职责：纯 UI，接收当前选中索引和点击回调，无业务逻辑。
/// 由 [MainShell] 使用，Tab 切换逻辑在 MainShell 里。
class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(
            top: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.55),
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ambientShadow.withValues(alpha: 0.22),
              blurRadius: 26,
              offset: const Offset(0, -8),
            ),
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: items.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                return Expanded(
                  child: NavButton(
                    item: item,
                    selected: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 单个导航按钮（固定尺寸）───────────────────────────────
class NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const NavButton({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        height: 58,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryContainer.withValues(alpha: 0.42)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? item.activeIcon : item.icon,
              color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
              size: 23,
            ),
            SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color:
                    selected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 数据类 ────────────────────────────────────────────────
/// 单个 Tab 的图标和文字描述
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
