import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// 分享服务 — 社区帖子分享到微信/其他App
class ShareService {
  static String _postUrl(String postId) {
    final base = AppConfig.shareSiteBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/post/$postId';
  }

  /// 分享帖子（链接形式）
  ///
  /// 微信好友收到链接 → 点开 → 网页显示帖子内容
  /// 网页上有"打开App"按钮 → 跳小程序或下载App
  static Future<void> sharePost({
    required BuildContext context,
    required String postId,
    required String content,
    String? coverUrl,
  }) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;

    // 帖子落地页 URL（需要在网站上实现 /post/:id 页面）
    final shareUrl = _postUrl(postId);

    // 截取正文前 50 字作为摘要
    final summary =
        content.length > 50 ? '${content.substring(0, 50)}...' : content;

    await SharePlus.instance.share(
      ShareParams(
        text: '🐾 $summary\n\n$shareUrl',
        subject: '来自萌宠智伴的帖子',
        sharePositionOrigin: origin,
      ),
    );
  }

  /// 分享视频帖子
  static Future<void> shareVideoPost({
    required BuildContext context,
    required String postId,
    required String content,
  }) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;

    final shareUrl = _postUrl(postId);
    final summary =
        content.length > 40 ? '${content.substring(0, 40)}...' : content;

    await SharePlus.instance.share(
      ShareParams(
        text: '🎥 $summary\n\n点击查看视频：$shareUrl',
        subject: '萌宠智伴 · 视频帖子',
        sharePositionOrigin: origin,
      ),
    );
  }

  /// 复制帖子链接到剪贴板（不弹分享面板）
  static Future<void> copyPostLink({
    required BuildContext context,
    required String postId,
  }) async {
    // ignore: deprecated_member_use
    await SharePlus.instance.share(
      ShareParams(text: _postUrl(postId)),
    );
  }
}
