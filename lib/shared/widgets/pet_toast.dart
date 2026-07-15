import 'package:flutter/material.dart';
import 'package:petpogo_app/shared/theme/app_colors.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PetToast — 顶部滑入通知
//  · 从屏幕顶部滑下 → 显示 2 秒 → 滑回顶部消失
//  · 支持上滑手动提前关闭
//  用法：PetToast.show(context, '消息');
//       PetToast.success(context, '成功');
//       PetToast.error(context, '错误');
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

  static void error(BuildContext context, String message,
          {Duration? duration}) =>
      _show(context, message, _ToastStyle.error, duration: duration);

  static void _show(
    BuildContext context,
    String message,
    _ToastStyle style, {
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
  final _ToastStyle style;
  final Duration duration;
  final VoidCallback onClose;

  const _ToastBanner({
    required this.message,
    required this.style,
    required this.duration,
    required this.onClose,
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
    final (Color bg, Color fg, IconData icon) = switch (widget.style) {
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
          const Color(0xFF60A5FA),
          Icons.notifications_rounded,
        ),
    };

    var topPad = 56.0;
    try {
      topPad = MediaQuery.of(context).padding.top + 12;
    } catch (_) {}

    return Positioned(
      top: topPad + _dragOffset,
      left: 16,
      right: 16,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ambientShadow.withValues(alpha: 0.28),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: fg.withValues(alpha: 0.18),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ],
                  border: Border.all(
                    color: fg.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: fg, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onPrimary.withValues(alpha: 0.92),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 18,
                      color: fg.withValues(alpha: 0.5),
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
