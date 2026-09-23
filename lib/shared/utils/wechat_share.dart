import 'package:flutter/foundation.dart';
import 'package:fluwx/fluwx.dart';

import '../../core/config/app_config.dart';

enum WechatShareScene {
  session,
  timeline,
}

final Fluwx _fluwx = Fluwx();
bool _wechatRegistered = false;

Future<void> initWechatShare() async {
  if (_wechatRegistered) return;

  try {
    _wechatRegistered = await _fluwx.registerApi(
      appId: AppConfig.wechatAppId,
      universalLink: AppConfig.wechatUniversalLink.isEmpty
          ? null
          : AppConfig.wechatUniversalLink,
    );
    debugPrint('[微信分享] SDK 注册: $_wechatRegistered');
  } catch (error) {
    debugPrint('[微信分享] SDK 注册失败: $error');
    _wechatRegistered = false;
  }
}

Future<bool> shareWechatWebPage({
  required String url,
  required String title,
  required String description,
  required WechatShareScene scene,
}) async {
  if (url.trim().isEmpty) return false;
  debugPrint('[微信分享] 准备分享 URL=${url.trim()}');

  await initWechatShare();

  try {
    final installed = await _fluwx.isWeChatInstalled;
    if (_wechatRegistered && installed) {
      final ok = await _fluwx.share(
        WeChatShareWebPageModel(
          url,
          title: title,
          description: description,
          scene: scene == WechatShareScene.timeline
              ? WeChatScene.timeline
              : WeChatScene.session,
        ),
      );
      if (ok) return true;
    }
  } catch (error) {
    debugPrint('[微信分享] SDK 分享失败: $error');
  }

  return false;
}
