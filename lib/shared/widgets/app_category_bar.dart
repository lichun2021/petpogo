import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_tokens.dart';

/// 由文字和内边距决定高度，避免横向列表的固定高度裁掉放大后的文字。
class AppCategoryBar extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  const AppCategoryBar(
      {super.key,
      required this.labels,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal, vertical: AppSpacing.x4),
          child: Row(children: [
            for (var index = 0; index < labels.length; index++) ...[
              if (index > 0) const SizedBox(width: AppSpacing.x8),
              Semantics(
                selected: selected == index,
                button: true,
                child: Material(
                  color: selected == index
                      ? AppColors.brandPrimarySoft
                      : AppColors.surfaceCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillRadius,
                    side: BorderSide(
                      color: selected == index
                          ? AppColors.brandPrimary.withValues(alpha: 0.35)
                          : AppColors.borderSubtle,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelected(index),
                    borderRadius: AppRadius.pillRadius,
                    child: Container(
                      constraints:
                          const BoxConstraints(minHeight: AppSize.touchMin),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x16, vertical: AppSpacing.x8),
                      child: Text(labels[index],
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 13,
                              fontWeight: selected == index
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected == index
                                  ? AppColors.brandPrimaryStrong
                                  : AppColors.textSecondary)),
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
      );
}
