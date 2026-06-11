/// lib/core/push/push_service.dart
/// 极光推送服务封装（jpush_flutter 3.x API）
/// 职责：
///   ✅ 初始化 JPush SDK
///   ✅ 登录后绑定 alias（userId）
///   ✅ 退出后清除 alias
///   ✅ 处理通知点击 → 路由跳转
///   ❌ 不持有 BuildContext（通过 appRouter 导航）

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:jpush_flutter/jpush_interface.dart';
import '../../core/config/app_config.dart';
import '../../core/router/app_router.dart';
import '../../core/router/app_routes.dart';

class PushService {
  PushService._();

  /// 通过 JPush.newJPush() 获取平台实例（3.x API）
  static final _jpush = JPush.newJPush();
  static String? _registrationId;

  /// 冷启动时 push 通知携带的目标路由，认证恢复后由 AuthController 消费并跳转
  static String? pendingRoute;

  static String? get registrationId => _registrationId;

  // ── 初始化（在 main.dart runApp 之前调用）────────────────────
  static Future<void> init() async {
    try {
      // 1. 注册事件回调（必须在 setup 之前）
      _jpush.addEventHandler(
        // 收到通知（App 在前台）
        onReceiveNotification: (Map<String, dynamic> message) async {
          debugPrint('[JPush] 收到通知: $message');
        },
        // 用户点击通知打开 App
        onOpenNotification: (Map<String, dynamic> message) async {
          debugPrint('[JPush] 点击通知: $message');
          _handleNotificationTap(message);
        },
        // 收到透传消息
        onReceiveMessage: (Map<String, dynamic> message) async {
          debugPrint('[JPush] 收到透传消息: $message');
        },
        // 极光连接状态变化
        onConnected: (Map<String, dynamic> message) async {
          debugPrint('[JPush] 连接状态: $message');
        },
      );

      // 2. 初始化 SDK
      _jpush.setup(
        appKey: AppConfig.jpushAppKey,
        channel: 'developer-default',
        production: !AppConfig.isDebug,
        debug: AppConfig.isDebug,
      );

      // 3. iOS 申请通知权限
      _jpush.applyPushAuthority(
        const NotificationSettingsIOS(sound: true, alert: true, badge: true),
      );

      // 4. 获取注册 ID
      _jpush.getRegistrationID().then((rid) {
        if (rid.isNotEmpty) {
          _registrationId = rid;
          debugPrint('[JPush] ✅ RegistrationID: $rid');
        }
      });

      // 5. 冷启动：App 从完全退出状态被通知唤起时，onOpenNotification 不会触发，
      //    需要通过 getLaunchAppNotification 拿到启动通知并处理跳转
      //    HMS 返回的数据格式: { "n_extras": {...}, "n_title": "...", "n_content": "..." }
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          final launchMsg = await _jpush.getLaunchAppNotification();
          if (launchMsg == null || launchMsg.isEmpty) return;
          debugPrint('[JPush] 冷启动通知: $launchMsg');
          // getLaunchAppNotification 返回 Map<dynamic,dynamic>，直接转换
          _handleNotificationTap(
            launchMsg.map((k, v) => MapEntry(k.toString(), v)),
          );
        } catch (e) {
          debugPrint('[JPush] getLaunchAppNotification 异常: $e');
        }
      });

      debugPrint('[JPush] ✅ 初始化成功');
    } catch (e) {
      debugPrint('[JPush] ❌ 初始化失败: $e');
    }
  }

  // ── 登录后绑定 alias（用 userId）────────────────────────────
  static Future<void> setAlias(String userId) async {
    if (userId.isEmpty) return;
    try {
      final result = await _jpush.setAlias(userId);
      debugPrint('[JPush] ✅ alias 绑定: $userId → $result');
    } catch (e) {
      debugPrint('[JPush] ⚠️ alias 绑定失败: $e');
    }
  }

  // ── 退出时清除 alias ─────────────────────────────────────────
  static Future<void> clearAlias() async {
    try {
      final result = await _jpush.deleteAlias();
      debugPrint('[JPush] ✅ alias 已清除: $result');
    } catch (e) {
      debugPrint('[JPush] ⚠️ alias 清除失败: $e');
    }
  }

  // ── 处理通知点击 → 路由跳转 ──────────────────────────────────
  static void _handleNotificationTap(Map<String, dynamic> message) {
    final extras = _extractExtras(message);
    final type      = extras['type'] ?? '';
    final deviceMacRaw = extras['device_mac'] ?? '';

    // 防御：device_mac 不应含 JSON 特殊字符（{ } " :），若含则说明解析失败，回退空值
    final deviceMac = _isValidMac(deviceMacRaw) ? deviceMacRaw : '';

    debugPrint('[JPush] 通知跳转 type=$type device_mac=$deviceMac extras=$extras');

    // 计算目标路由
    final String targetRoute;
    if (deviceMac.isNotEmpty) {
      targetRoute = AppRoutes.deviceDetail(deviceMac);
    } else {
      switch (type) {
        case 'auto_capture':
        case 'media':
          targetRoute = AppRoutes.home;
          break;
        case 'consultation':
          targetRoute = AppRoutes.consultation;
          break;
        case 'message':
          targetRoute = AppRoutes.message;
          break;
        default:
          targetRoute = AppRoutes.home;
      }
    }

    // 先存储到 pendingRoute，认证恢复后由 AuthController 消费
    pendingRoute = targetRoute;
    debugPrint('[JPush] pendingRoute 已存储: $targetRoute');

    // 延迟尝试立即跳转（App 已在运行的情况）
    Future.delayed(const Duration(milliseconds: 800), () {
      try {
        _navigateTo(targetRoute);
        pendingRoute = null; // 跳转成功，清除待命
      } catch (e) {
        debugPrint('[JPush] ⚠️ 路由跳转失败: $e，等待认证恢复后重试');
      }
    });
  }

  /// 跳转到目标路由，确保有完整的导航栈（避免返回时黑屏）
  /// - 若目标是首页，直接 go
  /// - 若目标是子页（如设备页），先 go('/') 铺首页底层，再 push 目标页
  static void _navigateTo(String route) {
    if (route == AppRoutes.home) {
      appRouter.go(route);
    } else {
      // 先确保首页在栈底，再 push 目标页（返回时可以回到首页）
      appRouter.go(AppRoutes.home);
      // 等 GoRouter 完成首页渲染后再 push
      Future.delayed(const Duration(milliseconds: 100), () {
        appRouter.push(route);
      });
    }
  }

  // ── device_mac 合法性校验（不含 JSON 特殊字符） ───────────────
  static bool _isValidMac(String mac) {
    if (mac.isEmpty) return false;
    // MAC 地址或设备标识符只含字母、数字、连字符、下划线、冒号
    // 若含 { } " 说明是整段 JSON 被误提取，视为非法
    return !mac.contains('{') && !mac.contains('}') && !mac.contains('"');
  }

  // ── 从不同结构里提取应用级 extras ──────────────────────────────
  // JPush Android 通知的数据结构（五种情况）：
  //   1. 前台/在线:  { "extras": { "cn.jpush.android.EXTRA": { device_mac: "xxx" } } }
  //   2. 后台点击:   同上
  //   3. HMS冷启动:  { "n_extras": { device_mac: "xxx" } }  或字符串
  //   4. 直接:       { "extras": { device_mac: "xxx" } }（无 cn.jpush 包装）
  //   5. HMS冷启动:  整个 message 只有一个 key，value 是整段 payload JSON 字符串
  static Map<String, String> _extractExtras(Map<String, dynamic> message) {
    // ⑤ HMS 冷启动极端情况：message 本身只有一个条目，且该 value 是整段 JSON
    //    例如: { "0": "{\"n_extras\":{...},\"n_title\":\"...\"}" }
    if (message.length == 1) {
      final onlyValue = message.values.first;
      if (onlyValue is String && onlyValue.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(onlyValue) as Map<String, dynamic>;
          return _extractExtras(decoded);
        } catch (_) {}
      }
    }

    final raw = message['extras']
             ?? message['Extras']
             ?? message['n_extras'];   // HMS 冷启动格式
    if (raw == null) return {};

    if (raw is Map) {
      // ① 优先：JPush Android 把应用自定义 extras 放在 cn.jpush.android.EXTRA 嵌套 Map 里
      final jpushExtra = raw['cn.jpush.android.EXTRA'];
      if (jpushExtra is Map && jpushExtra.isNotEmpty) {
        return Map.fromEntries(
          jpushExtra.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
        );
      }
      // ② 降级：过滤掉 JPush 内部 key，返回剩余自定义字段
      final filtered = Map.fromEntries(
        raw.entries
          .where((e) => !e.key.toString().startsWith('cn.jpush'))
          .map((e) => MapEntry(e.key.toString(), e.value.toString())),
      );
      if (filtered.isNotEmpty) return filtered;
    }

    // ③ extras 有时是 JSON 字符串（HMS 某些版本）
    if (raw is String && raw.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(raw) as Map;
        return Map.fromEntries(
          decoded.entries
            .where((e) => !e.key.toString().startsWith('cn.jpush'))
            .map((e) => MapEntry(e.key.toString(), e.value.toString())),
        );
      } catch (_) {}
    }
    return {};
  }
}
