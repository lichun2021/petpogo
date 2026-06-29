// ════════════════════════════════════════════════════════════
//  应用路由配置 — AppRouter
//
//  这里是所有页面跳转的唯一入口。
//
//  架构职责：
//    ✅ 集中管理所有页面路由（不再散落在各个页面文件里）
//    ✅ 统一配置页面切换动画（Tab 淡入、子页面从下滑入、成功页缩放）
//    ✅ 支持路由守卫（如未登录跳登录页，见注释中的 redirect）
//    ❌ 不包含业务逻辑（业务在 Controller 里）
//
//  如何新增页面：
//    1. 在 AppRoutes 里加路径常量
//    2. 在下面的 routes 里加 GoRoute
//    3. 使用 _slide() / _fade() / _fadeScale() 指定动画类型
// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/controller/auth_controller.dart';

// ── 页面导入 ──────────────────────────────────────────────
// 所有页面集中在这里导入，app.dart 不再需要导入各页面
import '../../features/home/home_page.dart';
import '../../features/message/message_page.dart';
import '../../features/community/community_page.dart';
import '../../features/pet_circle/pet_circle_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/settings_page.dart';
import '../../features/pet/add_pet_page.dart';
import '../../features/pet/pet_detail_page.dart';
import '../../features/bind_device/select_device_page.dart';
import '../../features/bind_device/scan_qr_page.dart';
import '../../features/bind_device/bind_success_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/message/chat_page.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_page.dart';
import '../../features/consultation/consultation_page.dart';
import '../../features/consultation/report_diagnosis_page.dart';
import '../../features/consultation/report_care_page.dart';
import '../../features/consultation/report_medical_page.dart';
import '../../features/consultation/data/models/consultation_models.dart';
import '../../features/device/robot_device_page.dart';
import '../../features/device/device_detail_page.dart';
import '../../features/device/data/repository/device_repository.dart';
import '../../features/device/data/models/device_model.dart';
import '../../features/share/share_landing_page.dart';
import '../../app.dart' show globalNavigatorKey;

// ── 路由实例和内部 ProviderContainer 用于守卫读取状态 ──────
// 为什么用 ProviderContainer：GoRouter 是顶层变量（非 Widget），
// 无法直接从建构函数访问 Riverpod。
// ProviderContainer 兑掰对应的容器即可读取最新状态。
late ProviderContainer _container;

void initAppRouter(ProviderContainer container) {
  _container = container;
}

/// 全局唯一的路由实例
///
/// 在 MaterialApp.router 里使用：routerConfig: appRouter
/// 由于 GoRouter 本身是单例设计，定义为顶层变量即可
final appRouter = GoRouter(
  // 全局 NavigatorKey：供 IM SDK 无 context 场景弹窗
  navigatorKey: globalNavigatorKey,

  // 初始页面 → 启动 Logo 页，认证状态恢复后由守卫自动跳转
  initialLocation: AppRoutes.splash,

  // 调试模式下打印路由日志（生产环境建议关闭）
  debugLogDiagnostics: false,

  // 页面跳转日志（开发阶段）
  observers: [_NavLogger()],

  // ── 路由守卫：强制登录 ────────────────────────────────────
  redirect: (context, state) {
    final auth = _container.read(authControllerProvider);
    final location = state.matchedLocation;

    // ① 认证状态恢复中 → 强制停在启动页，等状态确定后守卫再次触发
    //   （这是修复低端机闪屏的关键：拦截一切跳转，只允许待在 /splash）
    if (auth.isRestoring) {
      if (location == AppRoutes.splash) return null; // 已在启动页，不动
      return AppRoutes.splash; // 其余页面全部拦截到启动页
    }

    final isOnSplash = location == AppRoutes.splash;
    final isOnLogin = location == AppRoutes.login;
    final isOnShare = location == AppRoutes.share;

    // ② 在启动页时：SplashPage 自己负责跳转（保证最短展示时间），守卫不干预
    //   SplashPage 会调用 _navigate() → appRouter.go() 跳转到正确页面
    if (isOnSplash) return null;

    // ③ 未登录 且 不在登录页 → 强制跳到登录页
    if (auth.isGuest && !isOnLogin && !isOnShare) return AppRoutes.login;

    // ④ 已登录 且 在登录页 → 跳回首页
    if (auth.isLoggedIn && isOnLogin) return AppRoutes.home;

    return null; // 不拦截
  },

  routes: [
    // ══════════════════════════════════════════════════════
    //  启动页 — 认证状态恢复期间全屏展示
    //  不属于 ShellRoute，不含底部导航
    // ══════════════════════════════════════════════════════
    _fade(AppRoutes.splash, const SplashPage()),

    // ══════════════════════════════════════════════════════
    //  底部导航 Shell — 包含 5 个 Tab
    //  ShellRoute 的作用：让 5 个 Tab 共享同一个 MainShell（底部导航栏）
    //  Tab 切换时 MainShell 不会销毁重建，只换中间内容区
    // ══════════════════════════════════════════════════════
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        // Tab 切换使用淡入动画（不用 slide，避免方向混乱）
        _fade(AppRoutes.home, const HomePage()),
        _fade(AppRoutes.message, const MessagePage()),
        _fade(AppRoutes.community, const CommunityPage()),
        _fade(AppRoutes.petCircle, const PetCirclePage()),
        _fade(AppRoutes.profile, const ProfilePage()),
      ],
    ),

    // ══════════════════════════════════════════════════════
    //  子页面 — 从底部滑入（符合 iOS/Android 平台习惯）
    // ══════════════════════════════════════════════════════
    _slide(AppRoutes.settings, const SettingsPage()),
    _slide(AppRoutes.addPet, const AddPetPage()),
    _slide(AppRoutes.bindDevice, const SelectDevicePage()),

    GoRoute(
      path: AppRoutes.share,
      pageBuilder: (context, state) => _slidePage(
        state,
        ShareLandingPage(
          code: state.uri.queryParameters['code'] ?? '',
          type: state.uri.queryParameters['type'],
        ),
      ),
    ),

    // ── 带参数路由 ────────────────────────────────────────
    // 设备扫码页（参数：productKey）
    GoRoute(
      path: AppRoutes.scanQrTemplate,
      pageBuilder: (context, state) => _slidePage(
        state,
        ScanQrPage(
          productKey: state.pathParameters['productKey'] ?? '',
        ),
      ),
    ),

    // 绑定成功页（参数：设备类型）— 使用缩放动画，营造"成功感"
    GoRoute(
      path: AppRoutes.bindSuccessTemplate,
      pageBuilder: (context, state) => _fadeScalePage(
        state,
        BindSuccessPage(
          productKey: state.pathParameters['productKey'] ?? '',
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

    // IM 聊天页（参数：对方 userId = merchantId 字符串）
    GoRoute(
      path: AppRoutes.chatTemplate,
      pageBuilder: (context, state) => _slidePage(
        state,
        ChatPage(
          userId: state.pathParameters['userId'] ?? '',
        ),
      ),
    ),

    // 子页面 — 登录页（从下滑入）
    _slide(AppRoutes.login, const LoginPage()),

    // ── 宠小伊 AI 问诊 ────────────────────────────────────
    // 主聊天页（extra: petId）— 全屏，覆盖底部 tab
    GoRoute(
      path: AppRoutes.consultation,
      pageBuilder: (context, state) {
        final petId = state.extra is String ? state.extra as String : '';
        return _slidePage(state, ConsultationPage(petId: petId));
      },
    ),
    // 问诊报告详情页（extra: Map 或 ConsultationReport）
    GoRoute(
      path: AppRoutes.reportDiagnosis,
      pageBuilder: (context, state) {
        final args = _extractReportArgs(state.extra);
        return _slidePage(
            state,
            ReportDiagnosisPage(
              report: args.$1,
              petInfo: args.$2,
              petAvatar: args.$3,
            ));
      },
    ),
    // 治疗养护建议页（extra: ConsultationReport）
    GoRoute(
      path: AppRoutes.reportCare,
      pageBuilder: (context, state) {
        final report = _extractReport(state.extra);
        return _slidePage(state, ReportCarePage(report: report));
      },
    ),
    // 医疗检测方案页（extra: ConsultationReport）
    GoRoute(
      path: AppRoutes.reportMedical,
      pageBuilder: (context, state) {
        final report = _extractReport(state.extra);
        return _slidePage(state, ReportMedicalPage(report: report));
      },
    ),

    // ── 设备详情（push 通知点击跳转）─────────────────────────
    // URL: /device/:mac  → 按 mac 查找设备信息并打开 RobotDevicePage
    GoRoute(
      path: AppRoutes.deviceDetailTemplate,
      pageBuilder: (context, state) {
        final mac = state.pathParameters['mac'] ?? '';
        return _slidePage(state, _DeviceDetailWrapper(mac: mac));
      },
    ),
  ],
);

/// 报告页统一的 extra 解码 — 支持 Map 或直接 ConsultationReport
/// 返回 (report, petInfo?, petAvatar)
(
  ConsultationReport,
  PetInfoSnapshot?,
  String,
) _extractReportArgs(Object? extra) {
  if (extra is Map) {
    final report = extra['report'] as ConsultationReport?;
    final petInfo = extra['petInfo'] as PetInfoSnapshot?;
    final petAvatar = (extra['petAvatar'] as String?) ?? '';
    return (report ?? _emptyReport(), petInfo, petAvatar);
  }
  if (extra is ConsultationReport) return (extra, null, '');
  return (_emptyReport(), null, '');
}

/// 旧版兼容（其他报告子页面仍用此方法）
ConsultationReport _extractReport(Object? extra) {
  if (extra is ConsultationReport) return extra;
  if (extra is Map && extra['report'] is ConsultationReport) {
    return extra['report'] as ConsultationReport;
  }
  return _emptyReport();
}

ConsultationReport _emptyReport() {
  return const ConsultationReport(
    report: '',
    primaryDisease: '',
    symptomSummary: '',
    medicalSolutions: '',
    diseaseCards: [],
  );
}

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
    debugPrint(
        '[路由] replace: ${oldRoute?.settings.name} → ${newRoute?.settings.name}');
  }
}

// ── 设备详情路由包装 Widget ──────────────────────────────────
/// push 通知携带 device_mac 时跳转到此，
/// 从 deviceListProvider 按 mac 查找设备信息，根据 productKey 渲染正确的设备页面：
/// 产品目录使用 productKey 精确匹配类型，页面不再根据设备名称猜测。
class _DeviceDetailWrapper extends ConsumerWidget {
  final String mac;
  const _DeviceDetailWrapper({required this.mac});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(deviceListProvider);

    if (deviceState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 按 mac 查找（忽略大小写）
    final DeviceModel? device =
        deviceState.devices.cast<DeviceModel?>().firstWhere(
              (d) => d!.mac.toLowerCase() == mac.toLowerCase(),
              orElse: () => null,
            );

    if (device != null) {
      return _buildDevicePage(device);
    }

    // 找不到时用 mac 直接打开（避免白屏），默认用项圈页
    return DeviceDetailPage(mac: mac, name: '设备 $mac');
  }

  /// 根据 productKey 判断设备类型，渲染对应页面
  Widget _buildDevicePage(DeviceModel device) {
    if (device.isRobot) {
      return RobotDevicePage(mac: device.mac, name: device.displayName);
    } else {
      return DeviceDetailPage(mac: device.mac, name: device.displayName);
    }
  }
}
