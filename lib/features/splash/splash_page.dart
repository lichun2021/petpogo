/// ════════════════════════════════════════════════════════════
///  启动页 — SplashPage
///
///  职责：
///    ✅ 在认证状态恢复期间（isRestoring）全屏展示品牌 Logo
///    ✅ Logo 动画：淡入 + 轻微上移，体现品牌质感
///    ✅ 认证状态一旦确定（loggedIn / guest），路由守卫自动跳转
///    ✅ 保底超时（3 秒）防止极端情况卡在启动页
///    ❌ 不手动调 context.go()，全部由路由守卫 redirect 决定去向
///
///  与路由守卫的配合：
///    - isRestoring → 守卫返回 null，留在 /splash
///    - loggedIn   → 守卫跳到 /
///    - guest      → 守卫跳到 /login
/// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/controller/auth_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/router/app_routes.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  // ── 动画控制器 ─────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  // ── 品牌主色 ───────────────────────────────────────────
  static const _primaryOrange = Color(0xFFFF6B35);

  // 最短展示时间（确保 Logo 动画完整播放）
  static const _minShowDuration = Duration(milliseconds: 1600);

  // 记录认证状态是否已确定
  bool _authResolved = false;
  // 记录最短时间是否已到
  bool _minTimeReached = false;

  @override
  void initState() {
    super.initState();

    // Logo 入场动画：700ms，先快后慢
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _logoCtrl,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _logoCtrl,
      curve: Curves.easeOutCubic,
    ));

    // 启动入场动画
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _logoCtrl.forward();
    });

    // ── 最短展示时间计时 ──────────────────────────────────
    Future.delayed(_minShowDuration, () {
      if (!mounted) return;
      _minTimeReached = true;
      debugPrint('[SplashPage] ✅ 最短时间到达，_authResolved=$_authResolved');
      if (_authResolved) _navigate();
    });

    // ── 保底超时：5 秒强制跳转 ────────────────────────────
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      debugPrint('[SplashPage] ⚠️ 超时兜底，强制跳转');
      _navigate();
    });
  }

  // 统一跳转逻辑，由路由守卫决定去哪
  void _navigate() {
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (auth.isLoggedIn) {
      appRouter.go(AppRoutes.home);
    } else {
      appRouter.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听认证状态变化：等最短时间到再跳转
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      debugPrint('[SplashPage] Auth 状态: ${prev?.status} → ${next.status}');
      if (!next.isRestoring && !_authResolved) {
        _authResolved = true;
        debugPrint('[SplashPage] Auth 已确定，_minTimeReached=$_minTimeReached');
        if (_minTimeReached) _navigate();
        // 否则等 _minShowDuration 到了再跳
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Stack(
            children: [
              // ── Logo 铺满全屏 ──────────────────────────
              Positioned.fill(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) {
                    debugPrint('[SplashPage] ❌ Logo 加载失败: $err');
                    return const Center(
                      child: Icon(Icons.pets, color: Color(0xFFFF6B35), size: 120),
                    );
                  },
                ),
              ),

              // ── 底部加载指示 ───────────────────────────
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(child: _BreathingDots(color: _primaryOrange)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 呼吸点动画（三个小圆点依次跳动）────────────────────────
class _BreathingDots extends StatefulWidget {
  final Color color;
  const _BreathingDots({required this.color});

  @override
  State<_BreathingDots> createState() => _BreathingDotsState();
}

class _BreathingDotsState extends State<_BreathingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>>   _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    ));
    _anims = _ctrls.map((c) => Tween<double>(begin: 0, end: -6)
        .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();

    // 依次启动，间隔 180ms
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) {
          _ctrls[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
