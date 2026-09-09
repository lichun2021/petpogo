import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

// ── 底部导航栏 ────────────────────────────────────────────
/// 全 App 唯一的底栏激活样式：
///   brandPrimarySoft 圆角块 + brandPrimary 图标/文字；未选中 textSecondary。
///   图标始终用线性 glyph，不切换实心变体（见 docs/design-tokens.md §八）。
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
          color: AppColors.surfaceCard,
          border: Border(
            top: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ambientShadow,
              blurRadius: 26,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: AppSize.tabBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x8, vertical: AppSpacing.x8),
              child: Row(
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  return Expanded(
                    child: NavButton(
                      item: entry.value,
                      selected: currentIndex == index,
                      onTap: () => onTap(index),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final color = selected ? AppColors.brandPrimary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.controlRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: AppSize.touchMin),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4, vertical: AppSpacing.x4),
            decoration: BoxDecoration(
              color: selected ? AppColors.brandPrimarySoft : Colors.transparent,
              borderRadius: AppRadius.controlRadius,
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: color, size: AppIconSize.tabBar),
                  const SizedBox(height: AppSpacing.x4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
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
          ),
        ),
      ),
    );
  }
}

class NavItem {
  /// 线性图标；选中态只变色，不换实心 glyph
  final IconData icon;
  final String label;

  const NavItem({
    required this.icon,
    required this.label,
  });
}
