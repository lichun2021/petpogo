import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/raw_error_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../utils/error_presenter.dart';

/// 统一的行内错误视图
///
/// 传入错误对象（或已设计好的文案字符串），渲染：
///   线性告警图标 + 设计文案（statusAlert on statusAlertSoft）
///   + 原始错误文本（仅当「显示原始错误信息」开关打开；textTertiary 等宽，可选中，最多 3 行）
///
/// 两种布局：
///   - [AppErrorView] 居中块（空状态 / 整页错误），可带重试按钮
///   - [AppErrorBanner] 横条（地图底部提示、列表顶部提示）
class AppErrorView extends ConsumerWidget {
  const AppErrorView({
    super.key,
    required this.error,
    this.fallback,
    this.onRetry,
    this.retryLabel = '重试',
    this.neutral = false,
  });

  /// 错误对象或 String
  final Object? error;

  /// 未命中任何映射时的兜底文案
  final String? fallback;
  final VoidCallback? onRetry;
  final String retryLabel;

  /// 中性语义（如"暂无数据"），用 statusNeutral 而非 statusAlert
  final bool neutral;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showRaw = ref.watch(showRawErrorProvider);
    final copy = _copyOf(error, fallback);
    final fg = neutral ? AppColors.statusNeutral : AppColors.statusAlert;
    final bg = neutral ? AppColors.surfaceSunken : AppColors.statusAlertSoft;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sectionGap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(
                neutral ? Icons.info_outline_rounded : Icons.error_outline_rounded,
                color: fg,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.x12),
            Text(
              copy.message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
            if (showRaw && copy.raw.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x8),
              _RawText(copy.raw, align: TextAlign.center),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.x16),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 横条形错误提示（地图底部、列表顶部）
class AppErrorBanner extends ConsumerWidget {
  const AppErrorBanner({
    super.key,
    required this.error,
    this.fallback,
    this.neutral = false,
    this.onTap,
  });

  final Object? error;
  final String? fallback;
  final bool neutral;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showRaw = ref.watch(showRawErrorProvider);
    final copy = _copyOf(error, fallback);
    final fg = neutral ? AppColors.statusNeutral : AppColors.statusAlert;
    final bg = neutral ? AppColors.surfaceSunken : AppColors.statusAlertSoft;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.controlRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x12, vertical: AppSpacing.x8),
          decoration: BoxDecoration(color: bg, borderRadius: AppRadius.controlRadius),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  neutral ? Icons.info_outline_rounded : Icons.error_outline_rounded,
                  size: AppIconSize.card,
                  color: fg,
                ),
              ),
              const SizedBox(width: AppSpacing.iconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      copy.message,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        height: 1.4,
                      ),
                    ),
                    if (showRaw && copy.raw.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.x4),
                      _RawText(copy.raw),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RawText extends StatelessWidget {
  const _RawText(this.raw, {this.align = TextAlign.start});
  final String raw;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => SelectableText(
        raw,
        maxLines: 3,
        textAlign: align,
        style: AppTheme.monoData(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textTertiary,
        ),
      );
}

ErrorCopy _copyOf(Object? error, String? fallback) {
  if (error is String) return ErrorCopy(message: error, raw: '');
  return ErrorPresenter.describe(error, fallback: fallback);
}
