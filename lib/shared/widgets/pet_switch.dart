/// 统一风格的滑动开关
/// 开启：主色 track + 白色 thumb
/// 关闭：灰色 track + 白色 thumb
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PetSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const PetSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      // thumb 始终白色（textOnBrand）
      activeThumbColor: AppColors.textOnBrand,
      inactiveThumbColor: AppColors.textOnBrand,
      // track: 开→品牌色，关→暖色分隔线
      activeTrackColor: AppColors.brandPrimary,
      inactiveTrackColor: AppColors.borderSubtle,
      // 去掉 track 边框闪烁
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}
