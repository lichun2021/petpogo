import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
                return NavButton(
                  item: item,
                  selected: currentIndex == i,
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

// ── 单个导航按钮（带 scale 动画）────────────────────────────
class NavButton extends StatefulWidget {
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
  State<NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<NavButton>
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
  void didUpdateWidget(NavButton old) {
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

// ── 数据类 ────────────────────────────────────────────────
/// 单个 Tab 的图标和文字描述
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
