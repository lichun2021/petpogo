import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:share_plus/share_plus.dart';

/// 直接拉起微信好友分享文字。
/// Android: 定向到 com.tencent.mm.ui.tools.ShareImgUI（好友）。
/// 微信未安装时降级系统分享。
Future<void> shareToWechat(String text, {String subject = ''}) async {
  if (Platform.isAndroid) {
    try {
      await AndroidIntent(
        action: 'android.intent.action.SEND',
        package: 'com.tencent.mm',
        componentName: 'com.tencent.mm.ui.tools.ShareImgUI',
        type: 'text/plain',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        arguments: <String, dynamic>{
          'android.intent.extra.TEXT': text,
          'android.intent.extra.SUBJECT': subject,
        },
      ).launch();
    } catch (_) {
      await Share.share(text, subject: subject);
    }
  } else {
    await Share.share(text, subject: subject);
  }
}

/// 直接拉起微信朋友圈分享文字。
/// Android: 定向到 com.tencent.mm.ui.tools.ShareToTimeLineUI（朋友圈）。
/// 微信未安装时降级系统分享。
Future<void> shareToWechatTimeline(String text, {String subject = ''}) async {
  if (Platform.isAndroid) {
    try {
      await AndroidIntent(
        action: 'android.intent.action.SEND',
        package: 'com.tencent.mm',
        componentName: 'com.tencent.mm.ui.tools.ShareToTimeLineUI',
        type: 'text/plain',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        arguments: <String, dynamic>{
          'android.intent.extra.TEXT': text,
        },
      ).launch();
    } catch (_) {
      await Share.share(text, subject: subject);
    }
  } else {
    await Share.share(text, subject: subject);
  }
}
