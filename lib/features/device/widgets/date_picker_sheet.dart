/// 日期选择日历弹窗
///
/// 用于「自动抓拍」「自动打招呼」等记录页的完整日历选择：
///   - 基于 Material 内置 [CalendarDatePicker]（不引入新依赖）
///   - 用 `selectableDayPredicate` 把只有 [availableDates] 里的天设为可选，
///     其他天自动置灰
///   - 风格与项目其他 Sheet（_CountPickerSheet / _SoundPickerSheet）一致：
///     圆角 24、拖拽条、标题、底部完成按钮
library;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_fonts.dart';

/// 弹出日期选择弹窗，返回用户选择的日期（取消则返回 null）。
///
/// [availableDates] 有记录的天（日历上只有这些天可选）。
/// [initialDate] 初始选中日期（应位于 availableDates 中）。
Future<DateTime?> showRecordDatePickerSheet({
  required BuildContext context,
  required List<DateTime> availableDates,
  required DateTime? initialDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecordDatePickerSheet(
      availableDates: availableDates,
      initialDate: initialDate,
    ),
  );
}

// ──────────────────────────────────────────────────────────────
class _RecordDatePickerSheet extends StatefulWidget {
  final List<DateTime> availableDates;
  final DateTime? initialDate;

  const _RecordDatePickerSheet({
    required this.availableDates,
    required this.initialDate,
  });

  @override
  State<_RecordDatePickerSheet> createState() => _RecordDatePickerSheetState();
}

class _RecordDatePickerSheetState extends State<_RecordDatePickerSheet> {
  late final Set<String> _selectableKeys;

  @override
  void initState() {
    super.initState();
    _selectableKeys = widget.availableDates
        .map((d) => _key(DateTime(d.year, d.month, d.day)))
        .toSet();
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _selectable(DateTime d) => _selectableKeys.contains(_key(d));

  /// 可选范围：availableDates 的最早天~最晚天
  DateTime get _firstDay {
    if (widget.availableDates.isEmpty) {
      return DateTime.now().subtract(const Duration(days: 365));
    }
    var min = widget.availableDates.first;
    for (final d in widget.availableDates) {
      if (d.isBefore(min)) min = d;
    }
    return DateTime(min.year, min.month, min.day);
  }

  DateTime get _lastDay {
    if (widget.availableDates.isEmpty) return DateTime.now();
    var max = widget.availableDates.first;
    for (final d in widget.availableDates) {
      if (d.isAfter(max)) max = d;
    }
    return DateTime(max.year, max.month, max.day);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottomPad),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽条
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            // 标题
            Row(
              children: [
                Text(
                  '选择日期',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '仅显示有记录的日期',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 日历
            Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      surface: AppColors.surface,
                    ),
              ),
              child: CalendarDatePicker(
                initialDate: widget.initialDate ?? _lastDay,
                firstDate: _firstDay,
                lastDate: _lastDay,
                currentDate: widget.initialDate,
                selectableDayPredicate: _selectable,
                onDateChanged: (d) {
                  // 直接选择并关闭
                  Navigator.pop(context, DateTime(d.year, d.month, d.day));
                },
              ),
            ),
            const SizedBox(height: 4),
            // 提示
            Text(
              '无记录的日期不可选',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
