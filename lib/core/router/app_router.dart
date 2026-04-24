/// ════════════════════════════════════════════════════════════
///  应用路由配置 — AppRouter
///
///  这里是所有页面跳转的唯一入口。
///
///  架构职责：
///    ✅ 集中管理所有页面路由（不再散落在各个页面文件里）
///    ✅ 统一配置页面切换动画（Tab 淡入、子页面从下滑入、成功页缩放）
///    ✅ 支持路由守卫（如未登录跳登录页，见注释中的 redirect）
///    ❌ 不包含业务逻辑（业务在 Controller 里）
///
///  如何新增页面：
///    1. 在 AppRoutes 里加路径常量
///    2. 在下面的 routes 里加 GoRoute
///    3. 使用 _slide() / _fade() / _fadeScale() 指定动画类型
/// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_routes.dart';

// ── 页面导入 ──────────────────────────────────────────────
// 所有页面集中在这里导入，app.dart 不再需要导入各页面
import '../../features/home/home_page.dart';
import '../../features/message/message_page.dart';
import '../../features/community/community_page.dart';
import '../../features/mall/mall_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/settings_page.dart';
import '../../features/pet/add_pet_page.dart';
import '../../features/pet/pet_detail_page.dart';
import '../../features/bind_device/select_device_page.dart';
import '../../features/bind_device/scan_qr_page.dart';
import '../../features/bind_device/bind_success_page.dart';
import '../../features/auth/login_page.dart';
import '../../app.dart' show MainShell;

import 'package:flutter/foundation.dart';

/// 全局唯一的路由实例
///
/// 在 MaterialApp.router 里使用：routerConfig: appRouter
/// 由于 GoRouter 本身是单例设计，定义为顶层变量即可
final appRouter = GoRouter(
  // 初始页面（App 启动时显示的第一个页面）
  initialLocation: AppRoutes.home,

  // 调试模式下打印路由日志（生产环境建议关闭）
  debugLogDiagnostics: false,

  // 页面跳转日志（开发阶段）
  observers: [_NavLogger()],

  // ── 路由守卫（预留，接入登录功能时取消注释）────────────────
  // redirect: (context, state) {
  //   final isLoggedIn = ref.read(authProvider).isLoggedIn;
  //   // 未登录且不是在登录页 → 跳到登录页
  //   if (!isLoggedIn && state.matchedLocation != AppRoutes.login) {
  //     return AppRoutes.login;
  //   }
  //   // 已登录且在登录页 → 跳到首页
  //   if (isLoggedIn && state.matchedLocation == AppRoutes.login) {
  //     return AppRoutes.home;
  //   }
  //   return null; // 不拦截
  // },

  routes: [
    // ══════════════════════════════════════════════════════
    //  底部导航 Shell — 包含 5 个 Tab
    //  ShellRoute 的作用：让 5 个 Tab 共享同一个 MainShell（底部导航栏）
    //  Tab 切换时 MainShell 不会销毁重建，只换中间内容区
    // ══════════════════════════════════════════════════════
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        // Tab 切换使用淡入动画（不用 slide，避免方向混乱）
        _fade(AppRoutes.home,      const HomePage()),
        _fade(AppRoutes.message,   const MessagePage()),
        _fade(AppRoutes.community, const CommunityPage()),
        _fade(AppRoutes.mall,      const MallPage()),
        _fade(AppRoutes.profile,   const ProfilePage()),
      ],
    ),

    // ══════════════════════════════════════════════════════
    //  子页面 — 从底部滑入（符合 iOS/Android 平台习惯）
    // ══════════════════════════════════════════════════════
    _slide(AppRoutes.settings,   const SettingsPage()),
    _slide(AppRoutes.addPet,     const AddPetPage()),
    _slide(AppRoutes.bindDevice, const SelectDevicePage()),

    // ── 带参数路由 ────────────────────────────────────────
    // 设备扫码页（参数：设备类型 KeyTracker / PetPhone）
    GoRoute(
      path: AppRoutes.scanQrTemplate,
      pageBuilder: (context, state) => _slidePage(
        state,
        ScanQrPage(
          deviceType: state.pathParameters['deviceType'] ?? 'KeyTracker',
        ),
      ),
    ),

    // 绑定成功页（参数：设备类型）— 使用缩放动画，营造"成功感"
    GoRoute(
      path: AppRoutes.bindSuccessTemplate,
      pageBuilder: (context, state) => _fadeScalePage(
        state,
        BindSuccessPage(
          deviceType: state.pathParameters['deviceType'] ?? 'KeyTracker',
        ),
      ),
    ),

    // 宠物详情页（参数：宠物 ID）
    GoRoute(
      path: AppRoutes.petDetailTemplate,
      pageBuilder: (context, state) => _slidePage(
        state,
        PetDetailPage(
          petId: state.pathParameters['petId'] ?? '',
        ),
      ),
    ),
    // 子页面 — 登录页（从下滑入）
    _slide(AppRoutes.login, const LoginPage()),
  ],
);

// ══════════════════════════════════════════════════════════
//  动画工厂方法
//  为什么封装？避免每个 GoRoute 里重复写 pageBuilder 模板代码
// ══════════════════════════════════════════════════════════

/// 淡入动画 — 用于 Tab 切换
///
/// 轻量快速（200ms），不带方向性，避免 Tab 切换时的视觉混乱
GoRoute _fade(String path, Widget page) => GoRoute(
  path: path,
  pageBuilder: (context, state) => CustomTransitionPage(
    key: state.pageKey,
    child: page,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  ),
);

/// 从下滑入动画 — 用于子页面（设置、添加宠物、绑定设备等）
///
/// 符合 Material 和 iOS 两种平台的用户直觉
GoRoute _slide(String path, Widget page) => GoRoute(
  path: path,
  pageBuilder: (context, state) => _slidePage(state, page),
);

/// 构建"从下滑入 + 淡入"过渡页（子页面通用）
CustomTransitionPage _slidePage(GoRouterState state, Widget page) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: page,
      transitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (context, animation, _, child) {
        // 位移：从 y=0.06（略微偏下）到 y=0（正常位置）
        final slideTween = Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          ),
        );
      },
    );

/// 淡入 + 缩放动画 — 用于成功页（绑定成功、添加成功等）
///
/// 从 0.92 缩放到 1.0，配合 easeOutBack 曲线产生轻微弹跳感，
/// 视觉上传达"完成感"和"正向反馈"
CustomTransitionPage _fadeScalePage(GoRouterState state, Widget page) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: page,
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, _, child) {
        final scaleTween = Tween<double>(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack));

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: child,
          ),
        );
      },
    );

// ── 页面导航日志 Observer ─────────────────────────────────
/// 开发阶段记录所有页面跳转，方便排查路由问题
class _NavLogger extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    debugPrint('[路由] push → ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    debugPrint('[路由] pop  ← (返回到 ${previousRoute?.settings.name ?? "?"})');
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    debugPrint('[路由] replace: ${oldRoute?.settings.name} → ${newRoute?.settings.name}');
  }
}
