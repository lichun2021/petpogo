import 'package:flutter/material.dart';

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
    // 关掉上一条
    _current?.remove();
    _current = null;

    // 尝试多种方式获取 overlay，确保在各种 context 下都能工作
    OverlayState? overlay;
    try {
      // 1. 从 rootNavigator 的 overlay 获取（最可靠）
      overlay = Navigator.of(context, rootNavigator: true).overlay;
    } catch (_) {}
    if (overlay == null) {
      try {
        // 2. 直接从 context 查找 Overlay
        overlay = Overlay.of(context, rootOverlay: true);
      } catch (_) {}
    }
    if (overlay == null) return; // 找不到 overlay 则静默失败

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastBanner(
        message: message,
        style: style,
        duration: duration ?? const Duration(milliseconds: 2200),
        onClose: () {
          try { entry.remove(); } catch (_) {}
          if (_current == entry) _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

// ── 动画 Banner widget ────────────────────────────────────
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

    // 滑入 → 等待 → 滑出
    _startFlow();
  }

  void _startFlow() async {
    await _ctrl.forward();
    if (!mounted || _dismissed) return;
    await Future.delayed(widget.duration);
    if (!mounted || _dismissed) return;
    await _dismiss();
  }

  Future<void> _dismiss() async {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    await _ctrl.animateTo(0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInCubic);
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
          const Color(0xFF60A5FA),   // 柔和蓝色，区别于红色 error
          Icons.notifications_rounded,
        ),
    };

    // 安全获取 topPadding：Overlay 里 MediaQuery 通常可用
    double topPad = 56;
    try {
      topPad = MediaQuery.of(context).padding.top + 12;
    } catch (_) {}

    return Positioned(
      top: topPad + _dragOffset,
      left: 16,
      right: 16,
      child: GestureDetector(
        onVerticalDragUpdate: (d) {
          if (d.delta.dy < 0 && !_dismissed) {
            setState(() => _dragOffset += d.delta.dy);
          }
        },
        onVerticalDragEnd: (_) {
          if (_dragOffset < -30) {
            _dismiss();
          } else {
            setState(() => _dragOffset = 0);
          }
        },
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: fg.withOpacity(0.18),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ],
                border: Border.all(color: fg.withOpacity(0.22), width: 1),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: fg.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: fg, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  widget.message,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.92),
                    height: 1.4,
                  ),
                )),
                const SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_up_rounded,
                    size: 18, color: fg.withOpacity(0.5)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
