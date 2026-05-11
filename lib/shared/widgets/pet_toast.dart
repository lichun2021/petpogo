import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PetToast — 全局精美提示
//  用法：PetToast.show(context, '消息内容');
//       PetToast.success(context, '操作成功');
//       PetToast.warning(context, '警告内容');
//       PetToast.error(context, '错误内容');
// ─────────────────────────────────────────────────────────────────────────────

enum _ToastStyle { info, success, warning, error }

class PetToast {
  // ── 工厂方法 ─────────────────────────────────────────────
  static void show(BuildContext context, String message, {Duration? duration}) =>
      _show(context, message, _ToastStyle.info, duration: duration);

  static void success(BuildContext context, String message, {Duration? duration}) =>
      _show(context, message, _ToastStyle.success, duration: duration);

  static void warning(BuildContext context, String message, {Duration? duration}) =>
      _show(context, message, _ToastStyle.warning, duration: duration);

  static void error(BuildContext context, String message, {Duration? duration}) =>
      _show(context, message, _ToastStyle.error, duration: duration);

  // ── 内部实现 ─────────────────────────────────────────────
  static void _show(
    BuildContext context,
    String message,
    _ToastStyle style, {
    Duration? duration,
  }) {
    // 移除上一个同类 toast
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final (Color bg, Color fg, IconData icon) = switch (style) {
      _ToastStyle.success => (
          const Color(0xFF1A1A2E),
          const Color(0xFF4ADE80),
          Icons.check_circle_rounded,
        ),
      _ToastStyle.warning => (
          const Color(0xFF1A1A2E),
          const Color(0xFFFBBF24),
          Icons.warning_amber_rounded,
        ),
      _ToastStyle.error => (
          const Color(0xFF1A1A2E),
          const Color(0xFFFF6B6B),
          Icons.error_outline_rounded,
        ),
      _ToastStyle.info => (
          const Color(0xFF1A1A2E),
          AppColors.primary,
          Icons.info_outline_rounded,
        ),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 160,
          left: 20,
          right: 20,
        ),
        duration: duration ?? const Duration(milliseconds: 2200),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: fg.withOpacity(0.15),
                blurRadius: 16,
                spreadRadius: -2,
              ),
            ],
            border: Border.all(
              color: fg.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: fg.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: fg, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.92),
                height: 1.4,
              ),
            )),
          ]),
        ),
      ),
    );
  }
}
