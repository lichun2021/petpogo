import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../shared/theme/app_colors.dart';
import '../data/models/post_model.dart';
import '../data/post_repository.dart';
import '../controller/feed_controller.dart';

class PostViewerPage extends ConsumerStatefulWidget {
  final List<PostModel> posts;
  final int initialIndex;

  const PostViewerPage({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  @override
  ConsumerState<PostViewerPage> createState() => _PostViewerPageState();
}

class _PostViewerPageState extends ConsumerState<PostViewerPage> {
  late final PageController _pageCtrl;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听 Feed 状态（点赞同步）
    final feedState = ref.watch(feedControllerProvider);
    final posts = feedState.posts.isNotEmpty ? feedState.posts : widget.posts;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 帖子 PageView（垂直滑动切换） ───────────────
          PageView.builder(
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            itemCount: posts.length,
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
              // 接近末尾时加载更多
              if (i >= posts.length - 3) {
                ref.read(feedControllerProvider.notifier).loadMore();
              }
            },
            itemBuilder: (context, i) => _PostViewItem(
              post: posts[i],
              isActive: i == _currentIndex,
            ),
          ),

          // ── 顶部关闭按钮 ────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),

          // ── 右侧进度指示 ─────────────────────────────────
          if (posts.length > 1)
            Positioned(
              right: 12,
              top: 0, bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    posts.length.clamp(0, 8),
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      width: 3,
                      height: i == _currentIndex ? 20 : 6,
                      decoration: BoxDecoration(
                        color: i == _currentIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 单条帖子查看项 ─────────────────────────────────────────
class _PostViewItem extends ConsumerStatefulWidget {
  final PostModel post;
  final bool isActive;
  const _PostViewItem({required this.post, required this.isActive});

  @override
  ConsumerState<_PostViewItem> createState() => _PostViewItemState();
}

class _PostViewItemState extends ConsumerState<_PostViewItem> {
  int _imgIndex = 0;
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    if (widget.post.mediaType == MediaType.video && widget.post.videoUrl != null) {
      _initVideo();
    }
  }

  @override
  void didUpdateWidget(_PostViewItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _videoCtrl?.play();
    } else if (!widget.isActive && oldWidget.isActive) {
      _videoCtrl?.pause();
    }
  }

  Future<void> _initVideo() async {
    final url = widget.post.videoUrl!;
    _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
    await _videoCtrl!.initialize();
    if (widget.isActive) _videoCtrl!.play();
    _videoCtrl!.setLooping(true);
    if (mounted) setState(() => _videoReady = true);
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _toggleLike() {
    ref.read(feedControllerProvider.notifier).toggleLike(widget.post.id);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(feedControllerProvider).posts
        .firstWhere((p) => p.id == widget.post.id, orElse: () => widget.post);

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      onDoubleTap: _toggleLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 媒体内容 ─────────────────────────────────
          _buildMedia(post),

          // ── 渐变遮罩（底部信息区） ─────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── 底部信息 ──────────────────────────────────
          AnimatedOpacity(
            opacity: _showControls ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Positioned(
              left: 16, right: 64, bottom: 40,
              child: _buildInfo(post),
            ),
          ),

          // ── 右侧操作栏 ────────────────────────────────
          AnimatedOpacity(
            opacity: _showControls ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Positioned(
              right: 12, bottom: 40,
              child: _buildActions(post),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(PostModel post) {
    if (post.mediaType == MediaType.video) {
      if (_videoReady && _videoCtrl != null) {
        return Center(
          child: AspectRatio(
            aspectRatio: _videoCtrl!.value.aspectRatio,
            child: VideoPlayer(_videoCtrl!),
          ),
        );
      }
      // 封面占位
      if (post.coverUrl != null) {
        return CachedNetworkImage(imageUrl: post.coverUrl!, fit: BoxFit.cover);
      }
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    // 图片（多图横向滑动）
    if (post.mediaType == MediaType.image && post.mediaUrls.isNotEmpty) {
      if (post.mediaUrls.length == 1) {
        return InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: post.mediaUrls.first,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
        );
      }
      return Stack(
        children: [
          PageView.builder(
            itemCount: post.mediaUrls.length,
            onPageChanged: (i) => setState(() => _imgIndex = i),
            itemBuilder: (_, i) => InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: post.mediaUrls[i],
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          ),
          // 多图指示点
          Positioned(
            bottom: 56, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(post.mediaUrls.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _imgIndex ? 16 : 6, height: 6,
                decoration: BoxDecoration(
                  color: i == _imgIndex ? Colors.white : Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              )),
            ),
          ),
        ],
      );
    }

    // 纯文字帖
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(post.content,
          style: const TextStyle(fontSize: 24, color: AppColors.onSurface, height: 1.6),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildInfo(PostModel post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          _Avatar(url: post.userAvatar, name: post.nickname, size: 32),
          const SizedBox(width: 10),
          Text(post.nickname, style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 14,
            fontWeight: FontWeight.w700, color: Colors.white,
          )),
        ]),
        if (post.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(post.content,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 13,
              color: Colors.white.withOpacity(0.85), height: 1.5,
            ),
          ),
        ],
        if (post.location != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.location_on_rounded, size: 12, color: Colors.white.withOpacity(0.6)),
            const SizedBox(width: 4),
            Text(post.location!, style: TextStyle(
              fontSize: 12, color: Colors.white.withOpacity(0.6),
            )),
          ]),
        ],
      ],
    );
  }

  Widget _buildActions(PostModel post) {
    return Column(children: [
      _ActionBtn(
        icon: post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        label: '${post.likeCount}',
        color: post.isLiked ? Colors.red : Colors.white,
        onTap: _toggleLike,
      ),
      const SizedBox(height: 20),
      _ActionBtn(
        icon: Icons.chat_bubble_outline_rounded,
        label: '${post.commentCount}',
        color: Colors.white,
        onTap: () => _showComments(context, post),
      ),
      const SizedBox(height: 20),
      _ActionBtn(
        icon: Icons.share_rounded,
        label: '分享',
        color: Colors.white,
        onTap: () {},
      ),
    ]);
  }

  void _showComments(BuildContext context, PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(postId: post.id),
    );
  }
}

// ── 右侧操作按钮 ───────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Icon(icon, color: color, size: 30),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
    ]),
  );
}

// ── 头像 ────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  const _Avatar({this.url, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: CachedNetworkImageProvider(url!),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primaryContainer,
      child: Text(name.isNotEmpty ? name[0] : '?',
        style: TextStyle(fontSize: size * 0.4, color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── 评论面板 ────────────────────────────────────────────────
class _CommentsSheet extends ConsumerStatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _ctrl = TextEditingController();
  List<CommentModel> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(postRepositoryProvider);
      final list = await repo.fetchComments(widget.postId);
      if (mounted) setState(() { _comments = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    FocusScope.of(context).unfocus();
    try {
      final repo = ref.read(postRepositoryProvider);
      await repo.addComment(widget.postId, text);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.65 + bottom,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // 把手
        Container(margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(2))),

        const Text('评论', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),

        const Divider(),

        // 评论列表
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _comments.isEmpty
                  ? const Center(child: Text('暂无评论，来说第一句吧 💬',
                      style: TextStyle(color: AppColors.onSurfaceVariant)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, i) => _CommentItem(comment: _comments[i]),
                    ),
        ),

        // 输入框
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14),
                decoration: InputDecoration(
                  hintText: '说点什么…',
                  hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withOpacity(0.5), fontSize: 14),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _submit,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final CommentModel comment;
  const _CommentItem({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Avatar(url: comment.userAvatar, name: comment.nickname, size: 36),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(comment.nickname, style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        const SizedBox(height: 4),
        Text(comment.content, style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: AppColors.onSurface, height: 1.4)),
      ])),
    ]);
  }
}
