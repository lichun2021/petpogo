import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../controller/ai_controller.dart';

class AiPointsHint extends ConsumerWidget {
  const AiPointsHint({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(aiPointsProvider);
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textSecondary);
    return rules.when(
      skipLoadingOnReload: false,
      loading: () => Text('正在获取积分规则…', style: style),
      data: (values) => Text(
          values[kind] == null ? '积分规则待更新' : '${values[kind]} 积分 / 次',
          style: style),
      error: (_, __) => InkWell(
        onTap: () => ref.invalidate(aiPointsProvider),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('积分规则加载失败，点击重试', style: style)),
      ),
    );
  }
}
