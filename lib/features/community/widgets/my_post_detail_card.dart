import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/post_model.dart';
import '../data/post_repository.dart';

/// 默认显示摘要和缩略图，展开后查看完整正文、媒体与评论入口。
class MyPostDetailCard extends ConsumerStatefulWidget {
  const MyPostDetailCard(
      {super.key, required this.post, required this.onOpenMedia});
  final PostModel post;
  final VoidCallback onOpenMedia;
  @override
  ConsumerState<MyPostDetailCard> createState() => _MyPostDetailCardState();
}

class _MyPostDetailCardState extends ConsumerState<MyPostDetailCard> {
  bool _detailsExpanded = false;
  bool _expanded = false, _loading = false, _hasMore = true;
  String? _error;
  int _page = 0;
  final List<CommentModel> _comments = [];

  Future<void> _loadComments() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(postRepositoryProvider)
          .fetchComments(widget.post.id, page: _page + 1);
      if (!mounted) return;
      setState(() {
        final ids = _comments.map((c) => c.id).toSet();
        _comments.addAll(result.where((c) => ids.add(c.id)));
        _page++;
        _hasMore = result.length >= 20;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '评论加载失败，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(DateTime value) {
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _image(String url, {BoxFit fit = BoxFit.contain}) =>
      CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: (_, __) => const SizedBox(
            height: 160, child: Center(child: CircularProgressIndicator())),
        errorWidget: (_, __, ___) =>
            const SizedBox(height: 120, child: Center(child: Text('图片加载失败'))),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final colors = Theme.of(context).colorScheme;
    final previewUrl = p.mediaType == MediaType.image
        ? (p.mediaUrls.isEmpty ? null : p.mediaUrls.first)
        : p.coverUrl;
    final hasMedia = p.mediaUrls.isNotEmpty || p.mediaType == MediaType.video;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.nickname, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(_date(p.createdAt),
              style: Theme.of(context).textTheme.bodySmall),
          if (!_detailsExpanded) ...[
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (hasMedia) ...[
                Semantics(
                  button: true,
                  label: p.mediaType == MediaType.video ? '播放视频' : '查看图片',
                  child: InkWell(
                    onTap: widget.onOpenMedia,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: Stack(fit: StackFit.expand, children: [
                          if (previewUrl?.isNotEmpty == true)
                            _image(previewUrl!, fit: BoxFit.cover)
                          else
                            ColoredBox(color: colors.surfaceContainerHighest),
                          if (p.mediaType == MediaType.video)
                            const Center(
                                child: Icon(Icons.play_circle_fill,
                                    color: Colors.white, size: 32)),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.content.isEmpty ? '分享生活瞬间' : p.content,
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (hasMedia) ...[
                    const SizedBox(height: 6),
                    Text(
                        p.mediaType == MediaType.video
                            ? '视频'
                            : '${p.mediaUrls.length} 张图片',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              )),
            ]),
          ],
          if (_detailsExpanded && p.content.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(p.content),
          ],
          if (_detailsExpanded && p.mediaType == MediaType.image)
            for (final url in p.mediaUrls)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GestureDetector(
                    onTap: widget.onOpenMedia,
                    child:
                        SizedBox(width: double.infinity, child: _image(url))),
              ),
          if (_detailsExpanded && p.mediaType == MediaType.video) ...[
            const SizedBox(height: 12),
            InkWell(
                onTap: widget.onOpenMedia,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (p.coverUrl?.isNotEmpty == true)
                      SizedBox(
                          width: double.infinity, child: _image(p.coverUrl!))
                    else
                      Container(
                          height: 180, color: colors.surfaceContainerHighest),
                    const CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.play_arrow, color: Colors.white)),
                  ],
                )),
            TextButton.icon(
                onPressed: widget.onOpenMedia,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('播放视频')),
          ],
          if (_detailsExpanded && p.location?.isNotEmpty == true)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('位置：${p.location}')),
          if (_detailsExpanded && p.tag?.isNotEmpty == true)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('分类：${{
                      'cat': '猫咪',
                      'dog': '狗狗',
                      'other': '其他'
                    }[p.tag] ?? p.tag}')),
          const Divider(height: 28),
          Wrap(spacing: 20, runSpacing: 8, children: [
            Text('点赞 ${p.likeCount}'),
            Text('评论 ${p.commentCount}'),
            Text('浏览 ${p.viewCount}'),
          ]),
          TextButton.icon(
            onPressed: () => setState(() {
              _detailsExpanded = !_detailsExpanded;
            }),
            icon:
                Icon(_detailsExpanded ? Icons.expand_less : Icons.expand_more),
            label: Text(_detailsExpanded ? '收起详情' : '展开详情'),
          ),
          if (_detailsExpanded)
            TextButton(
                onPressed: () {
                  setState(() => _expanded = !_expanded);
                  if (_expanded && _page == 0 && !_loading) _loadComments();
                },
                child: Text(_expanded ? '收起评论' : '查看评论')),
          if (_detailsExpanded && _expanded) ...[
            for (final c in _comments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c.nickname} · ${_date(c.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(c.content),
                    ]),
              ),
            if (_loading)
              const LinearProgressIndicator()
            else if (_error != null)
              TextButton(onPressed: _loadComments, child: Text(_error!))
            else if (_comments.isEmpty)
              const Text('暂无评论')
            else if (_hasMore)
              TextButton(onPressed: _loadComments, child: const Text('加载更多评论')),
          ],
        ]),
      ),
    );
  }
}
