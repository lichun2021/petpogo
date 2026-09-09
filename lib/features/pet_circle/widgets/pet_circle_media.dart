import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../data/models/pet_circle_post.dart';

/// 单图完整展示；多图缩略图点击后可查看、缩放原图。
class PetCircleMedia extends StatelessWidget {
  final PetCirclePost post;
  const PetCircleMedia({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    if (post.isVideo) {
      return AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
              borderRadius: AppRadius.controlRadius,
              child: Stack(fit: StackFit.expand, children: [
                if (post.coverUrl.isNotEmpty)
                  RetryablePetImage(url: post.coverUrl)
                else
                  ColoredBox(color: AppColors.surfaceSunken),
                Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                        margin: const EdgeInsets.all(AppSpacing.x8),
                        padding: const EdgeInsets.all(AppSpacing.x8),
                        decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: AppRadius.controlRadius),
                        child: Text(post.coverUrl.isEmpty ? '视频暂无封面' : '视频动态',
                            style: TextStyle(color: AppColors.textSecondary)))),
              ])));
    }
    final urls = post.imageUrls;
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) {
      // 固定预览边界避免加载跳动，contain 保留横图/竖图的完整画面。
      return AspectRatio(
          aspectRatio: 4 / 3,
          child: _thumbnail(context, urls, 0, fit: BoxFit.contain));
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: urls.length.clamp(0, 9),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: urls.length == 2 || urls.length == 4 ? 2 : 3,
          crossAxisSpacing: AppSpacing.x4,
          mainAxisSpacing: AppSpacing.x4),
      itemBuilder: (_, index) => _thumbnail(context, urls, index),
    );
  }

  Widget _thumbnail(BuildContext context, List<String> urls, int index,
          {BoxFit fit = BoxFit.cover}) =>
      Semantics(
        label: '查看第 ${index + 1} 张图片',
        button: true,
        child: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                  builder: (_) =>
                      _PhotoViewer(urls: urls, initialIndex: index))),
          child: ClipRRect(
              borderRadius: AppRadius.controlRadius,
              child: RetryablePetImage(url: urls[index], fit: fit)),
        ),
      );
}

class RetryablePetImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  const RetryablePetImage(
      {super.key, required this.url, this.fit = BoxFit.cover});
  @override
  State<RetryablePetImage> createState() => _RetryablePetImageState();
}

class _RetryablePetImageState extends State<RetryablePetImage> {
  int _attempt = 0;
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.surfaceSunken,
        child: CachedNetworkImage(
          key: ValueKey('${widget.url}:$_attempt'),
          imageUrl: widget.url,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          placeholder: (_, __) => const Center(
              child: SizedBox(
                  width: AppSpacing.x24,
                  height: AppSpacing.x24,
                  child: CircularProgressIndicator(strokeWidth: 2))),
          errorWidget: (_, __, error) => Center(
            child: IconButton(
              tooltip: '图片加载失败，点击重试',
              onPressed: () => setState(() => _attempt++),
              icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            ),
          ),
        ),
      );
}

class _PhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _PhotoViewer({required this.urls, required this.initialIndex});
  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surfacePage,
        appBar: AppBar(title: Text('${_index + 1} / ${widget.urls.length}')),
        body: SafeArea(
            child: PageView.builder(
          controller: _pages,
          itemCount: widget.urls.length,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (_, index) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: RetryablePetImage(
                  url: widget.urls[index], fit: BoxFit.contain)),
        )),
      );
}
