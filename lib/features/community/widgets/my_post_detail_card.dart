import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/post_model.dart';
import '../data/post_repository.dart';

/// 我的帖子直接展开正文、全部图片与统计，视频按需打开播放。
class MyPostDetailCard extends ConsumerStatefulWidget {
  const MyPostDetailCard(
      {super.key, required this.post, required this.onOpenMedia});
  final PostModel post;
  final VoidCallback onOpenMedia;
  @override
  ConsumerState<MyPostDetailCard> createState() => _MyPostDetailCardState();
}

class _MyPostDetailCardState extends ConsumerState<MyPostDetailCard> {
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

  Widget _image(String url) => CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, __) => const SizedBox(
            height: 160, child: Center(child: CircularProgressIndicator())),
        errorWidget: (_, __, ___) =>
            const SizedBox(height: 120, child: Center(child: Text('图片加载失败'))),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.nickname, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(_date(p.createdAt),
              style: Theme.of(context).textTheme.bodySmall),
          if (p.content.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(p.content),
          ],
          if (p.mediaType == MediaType.image)
            for (final url in p.mediaUrls)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GestureDetector(
                    onTap: widget.onOpenMedia,
                    child:
                        SizedBox(width: double.infinity, child: _image(url))),
              ),
          if (p.mediaType == MediaType.video) ...[
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
          if (p.location?.isNotEmpty == true)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('位置：${p.location}')),
          if (p.tag?.isNotEmpty == true)
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
          TextButton(
              onPressed: () {
                setState(() => _expanded = !_expanded);
                if (_expanded && _page == 0 && !_loading) _loadComments();
              },
              child: Text(_expanded ? '收起评论' : '查看评论')),
          if (_expanded) ...[
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
