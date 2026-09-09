import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petpogo_app/core/providers/raw_error_provider.dart';
import 'package:petpogo_app/shared/theme/app_colors.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';
import 'package:petpogo_app/shared/theme/app_theme.dart';
import 'package:petpogo_app/shared/theme/app_tokens.dart';
import 'package:petpogo_app/shared/utils/error_presenter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PetToast — 顶部滑入通知
//  · 从屏幕顶部滑下 → 显示 2 秒 → 滑回顶部消失
//  · 支持上滑手动提前关闭
//  用法：PetToast.show(context, '消息');
//       PetToast.success(context, '成功');
//       PetToast.error(context, e);          // 传错误对象，自动转设计文案
//       PetToast.error(context, '已设计好的文案');
// ─────────────────────────────────────────────────────────────────────────────

enum _ToastStyle { info, success, warning, error }

class PetToast {
  static OverlayEntry? _current;

  static void show(BuildContext context, String message,
          {Duration? duration}) =>
      _show(context, message, _ToastStyle.info, duration: duration);

  static void success(BuildContext context, String message,
          {Duration? duration}) =>
      _show(context, message, _ToastStyle.success, duration: duration);

  static void warning(BuildContext context, String message,
          {Duration? duration}) =>
      _show(context, message, _ToastStyle.warning, duration: duration);

  /// [error] 可以是 String（已设计好的文案）或任意错误对象。
  /// 错误对象经 [ErrorPresenter] 转成用户文案；「显示原始错误信息」开关
  /// 打开时在文案下方附带原始错误文本。
  static void error(BuildContext context, Object? error,
      {Duration? duration, String? fallback}) {
    if (error is String) {
      _show(context, error, _ToastStyle.error, duration: duration);
      return;
    }
    final copy = ErrorPresenter.describe(error, fallback: fallback);
    _show(
      context,
      copy.message,
      _ToastStyle.error,
      raw: _rawEnabled(context) ? copy.raw : null,
      duration: duration ?? const Duration(milliseconds: 3200),
    );
  }

  static bool _rawEnabled(BuildContext context) {
    try {
      return ProviderScope.containerOf(context, listen: false)
          .read(showRawErrorProvider);
    } catch (_) {
      return false;
    }
  }

  static void _show(
    BuildContext context,
    String message,
    _ToastStyle style, {
    String? raw,
    Duration? duration,
  }) {
    _current?.remove();
    _current = null;

    OverlayState? overlay;
    try {
      overlay = Navigator.of(context, rootNavigator: true).overlay;
    } catch (_) {}
    if (overlay == null) {
      try {
        overlay = Overlay.of(context, rootOverlay: true);
      } catch (_) {}
    }
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastBanner(
        message: message,
        raw: raw,
        style: style,
        duration: duration ?? const Duration(milliseconds: 2200),
        onClose: () {
          try {
            entry.remove();
          } catch (_) {}
          if (_current == entry) _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _ToastBanner extends StatefulWidget {
  final String message;
  final String? raw;
  final _ToastStyle style;
  final Duration duration;
  final VoidCallback onClose;

  const _ToastBanner({
    required this.message,
    required this.style,
    required this.duration,
    required this.onClose,
    this.raw,
  });

  @override
  State<_ToastBanner> createState() => _ToastBannerState();
}

class _ToastBannerState extends State<_ToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  double _dragOffset = 0;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _startFlow();
  }

  Future<void> _startFlow() async {
    await _ctrl.forward();
    if (!mounted || _dismissed) return;
    await Future.delayed(widget.duration);
    if (!mounted || _dismissed) return;
    await _dismiss();
  }

  Future<void> _dismiss() async {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    await _ctrl.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInCubic,
    );
    widget.onClose();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color pad, IconData icon) = switch (widget.style) {
      _ToastStyle.success => (
          AppColors.statusOnlineStrong,
          AppColors.statusOnlineSoft,
          Icons.check_circle_outline_rounded,
        ),
      _ToastStyle.warning => (
          AppColors.statusAlert,
          AppColors.statusAlertSoft,
          Icons.warning_amber_rounded,
        ),
      _ToastStyle.error => (
          AppColors.statusAlert,
          AppColors.statusAlertSoft,
          Icons.error_outline_rounded,
        ),
      _ToastStyle.info => (
          AppColors.brandPrimary,
          AppColors.brandPrimarySoft,
          Icons.notifications_none_rounded,
        ),
    };

    var topPad = 56.0;
    try {
      topPad = MediaQuery.of(context).padding.top + AppSpacing.x12;
    } catch (_) {}

    final raw = widget.raw;

    return Positioned(
      top: topPad + _dragOffset,
      left: AppSpacing.x16,
      right: AppSpacing.x16,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy < 0 && !_dismissed) {
            setState(() => _dragOffset += details.delta.dy);
          }
        },
        onVerticalDragEnd: (_) {
          if (_dragOffset < -30) {
            _dismiss();
          } else {
            setState(() => _dragOffset = 0);
          }
        },
        child: Semantics(
          container: true,
          liveRegion: true,
          label: widget.message,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x16, vertical: AppSpacing.x12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: AppRadius.cardRadius,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: AppColors.borderSubtle, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: pad, shape: BoxShape.circle),
                      child: Icon(icon, color: fg, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.contentGap),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                widget.message,
                                style: TextStyle(
                                  fontFamily: AppFonts.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            if (raw != null && raw.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.x4),
                              SelectableText(
                                raw,
                                maxLines: 3,
                                style: AppTheme.monoData(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.iconGap),
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
