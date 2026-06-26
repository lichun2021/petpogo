import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';
import '../../features/auth/controller/auth_controller.dart';

class DeepLinkService {
  DeepLinkService._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _subscription;
  static ProviderContainer? _container;
  static String? _pendingRoute;

  static Future<void> init(ProviderContainer container) async {
    _container = container;
    await _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (error) => debugPrint('[DeepLink] 链接监听失败: $error'),
    );

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);
    } catch (error) {
      debugPrint('[DeepLink] 初始链接读取失败: $error');
    }
  }

  static void _handleUri(Uri uri) {
    final route = _routeFromUri(uri);
    if (route == null) return;

    final auth = _container?.read(authControllerProvider);
    if (auth == null || auth.isRestoring) {
      _pendingRoute = route;
      debugPrint('[DeepLink] 等待认证恢复后跳转: $route');
      return;
    }

    _pendingRoute = null;
    _go(route);
  }

  static void consumePendingRoute() {
    final route = _pendingRoute;
    if (route == null) return;
    final auth = _container?.read(authControllerProvider);
    if (auth == null || auth.isRestoring) return;

    _pendingRoute = null;
    _go(route);
  }

  static void _go(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        appRouter.go(route);
        debugPrint('[DeepLink] 跳转: $route');
      } catch (error) {
        debugPrint('[DeepLink] 跳转失败: $error');
      }
    });
  }

  static String? _routeFromUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final isAppScheme = scheme == AppConfig.appScheme.toLowerCase();
    final isWebsite = scheme == 'https' &&
        uri.host.toLowerCase() == Uri.parse(AppConfig.shareSiteBaseUrl).host &&
        (uri.path == '/share' || uri.path.endsWith('/share.html'));

    if (!isAppScheme && !isWebsite) return null;

    final isShare = isAppScheme && uri.host == 'share';
    if (!isShare && !isWebsite) return null;

    final code = uri.queryParameters['code']?.trim() ?? '';
    if (code.isEmpty) return null;

    final type = uri.queryParameters['type']?.trim();
    return AppRoutes.shareLanding(code: code, type: type);
  }
}
