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
      // thumb 始终白色
      activeColor: Colors.white,
      inactiveThumbColor: Colors.white,
      // track: 开→主色，关→浅灰
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: const Color(0xFFD0D0D0),
      // 去掉 track 边框闪烁
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}
