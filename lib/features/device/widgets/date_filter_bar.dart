/// 横向日期选择条
///
/// 用于「自动抓拍」「自动打招呼」等记录页的日期切换：
///   - 单行横滑的日期列表（只包含有记录的天，降序）
///   - 整条包在一个圆角小描边框里，左右边缘渐变淡出营造整体感
///   - 选中态：主色 + 加粗（不加背景框），未选：次要色 + 中等字重
///   - 首次渲染后自动把选中项滚到可视区
///
/// 注意：右侧的 📅 日历按钮由调用方放在标题行，本组件只负责日期列表。
library;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_fonts.dart';

class DateFilterBar extends StatefulWidget {
  /// 可选日期（有记录的天，降序）
  final List<DateTime> availableDates;

  /// 当前选中日期（必须在 availableDates 中）
  final DateTime? selectedDate;

  /// 切换日期回调
  final ValueChanged<DateTime> onChanged;

  const DateFilterBar({
    super.key,
    required this.availableDates,
    required this.selectedDate,
    required this.onChanged,
  });

  @override
  State<DateFilterBar> createState() => _DateFilterBarState();
}

class _DateFilterBarState extends State<DateFilterBar> {
  final ScrollController _controller = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureSelectedVisible();
  }

  @override
  void didUpdateWidget(covariant DateFilterBar old) {
    super.didUpdateWidget(old);
    if (old.selectedDate != widget.selectedDate) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureSelectedVisible());
    }
  }

  void _ensureSelectedVisible() {
    if (widget.selectedDate == null || !_controller.hasClients) return;
    final idx = _indexOf(widget.selectedDate!);
    if (idx < 0) return;
    // 用估算的 item 宽度做近似滚动，避免测量开销
    const itemWidth = 64.0;
    const gap = 8.0;
    final target = idx * (itemWidth + gap) - 48;
    _controller.animateTo(
      target.clamp(0.0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  int _indexOf(DateTime d) {
    for (var i = 0; i < widget.availableDates.length; i++) {
      if (_isSameDay(widget.availableDates[i], d)) return i;
    }
    return -1;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 显示文案：今天 / 昨天 / M月d日
  String _label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(d.year, d.month, d.day);
    if (target == today) return '今天';
    if (target == yesterday) return '昨天';
    return '${d.month}月${d.day}日';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.availableDates.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.outlineVariant, width: 1),
        ),
        child: Stack(
          children: [
            // ── 可横滑的日期 Chip 列表 ──
            ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              physics: const BouncingScrollPhysics(),
              itemCount: widget.availableDates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final d = widget.availableDates[i];
                final selected = widget.selectedDate != null &&
                    _isSameDay(d, widget.selectedDate!);
                return Center(
                  child: _DateChip(
                    label: _label(d),
                    selected: selected,
                    onTap: () => widget.onChanged(d),
                  ),
                );
              },
            ),
            // ── 左右边缘渐变淡出遮罩，营造整体感 ──
            const Align(
              alignment: Alignment.centerLeft,
              child: _EdgeFade(side: _EdgeSide.left),
            ),
            const Align(
              alignment: Alignment.centerRight,
              child: _EdgeFade(side: _EdgeSide.right),
            ),
          ],
        ),
      ),
    );
  }
}

/// 右上角的日历入口按钮（轻量描边胶囊，放在标题行右侧）
class CalendarIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;

  const CalendarIconButton({
    super.key,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: compact ? 36 : 40,
        height: compact ? 36 : 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.calendar_month_rounded,
          size: compact ? 18 : 20,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// 单个日期（纯文字，选中靠主色 + 加粗，无背景框）
class _DateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (selected) return; // 避免重复点击同一天
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
            height: 1.1,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// 容器左右边缘的渐变淡出遮罩。
///
/// 颜色与「凹槽」背景一致，从不透明渐变到透明，
/// 让 chip 列表在被裁切时产生"融入容器"的整体感，而不是硬切断。
enum _EdgeSide { left, right }

class _EdgeFade extends StatelessWidget {
  final _EdgeSide side;
  const _EdgeFade({required this.side});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.surfaceContainerHighest.withValues(alpha: 0.45);
    final width = 24.0;
    return IgnorePointer(
      child: Container(
        width: width,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: side == _EdgeSide.left
                ? Alignment.centerLeft
                : Alignment.centerRight,
            end: side == _EdgeSide.left
                ? Alignment.centerRight
                : Alignment.centerLeft,
            colors: [color, color.withValues(alpha: 0)],
          ),
          // 给遮罩末端（朝向列表中心一侧）做圆角过渡，避免生硬方块感
          borderRadius: BorderRadius.only(
            topLeft: side == _EdgeSide.left ? const Radius.circular(10) : Radius.zero,
            bottomLeft: side == _EdgeSide.left ? const Radius.circular(10) : Radius.zero,
            topRight: side == _EdgeSide.right ? const Radius.circular(10) : Radius.zero,
            bottomRight: side == _EdgeSide.right ? const Radius.circular(10) : Radius.zero,
          ),
        ),
      ),
    );
  }
}
