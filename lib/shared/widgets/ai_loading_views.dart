import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

/// AI 分析上传进度视图（语音/图片面板共用）
class AiUploadProgressView extends StatelessWidget {
  final String label;
  final double progress;
  final String icon;
  const AiUploadProgressView({
    super.key,
    required this.label,
    required this.progress,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: TextStyle(fontSize: 40)),
        SizedBox(height: 12),
        Text(label,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            )),
        SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.surfaceContainerHighest,
            color: AppColors.primary,
            minHeight: 6,
          ),
        ),
        SizedBox(height: 4),
        Text('${(progress * 100).toInt()}%',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
            )),
      ],
    );
  }
}

/// AI 分析中的 spinner 视图（语音/图片面板共用）
class AiAnalyzingSpinnerView extends StatelessWidget {
  final String label;
  const AiAnalyzingSpinnerView({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
        ),
        SizedBox(height: 12),
        Text(label,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            )),
      ],
    );
  }
}

/// AI 分析失败视图（语音/图片面板共用）
class AiErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AiErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('😓', style: TextStyle(fontSize: 40)),
        SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: AppColors.textOnBrand,
          ),
          child: Text('重试'),
        ),
      ],
    );
  }
}
