/// 媒体库页面
///
/// - 支持「只看我的」/ 「设备共享」切换
/// - 不同用户头像/昵称标记
/// - 本地文件优先，点击下载后播放/查看
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/pet_toast.dart';
import '../auth/controller/auth_controller.dart';
import 'data/models/media_model.dart';
import 'data/repository/media_repository.dart';

class MediaGalleryPage extends ConsumerStatefulWidget {
  final String deviceId;
  final String deviceName;

  const MediaGalleryPage({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  ConsumerState<MediaGalleryPage> createState() => _MediaGalleryPageState();
}

class _MediaGalleryPageState extends ConsumerState<MediaGalleryPage> {
  bool _showOnlyMine = false;
  int  _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  final List<MediaItem> _items = [];
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ── 数据加载 ───────────────────────────────────────────
  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _page = 1;
      _hasMore = true;
      _items.clear();
    }
    setState(() => _loading = true);
    try {
      final me = ref.read(authControllerProvider).user?.id;
      // 两种模式都传 deviceId 查设备图库，只看我的时在客户端再按 userId 过滤
      final result = await ref.read(mediaRepositoryProvider).fetchList(
        deviceId: widget.deviceId,
        page: _page,
      );
      setState(() {
        _items.addAll(_showOnlyMine
            ? result.list.where((i) => i.userId == me).toList()
            : result.list);
        _hasMore = result.hasMore;
        _page++;
      });
    } catch (e) {
      if (mounted) PetToast.error(context, '加载失败，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    await _load();
  }

  // ── 删除 ───────────────────────────────────────────────
  Future<void> _delete(MediaItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text('删除文件',
            style: TextStyle(fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w700)),
        content: Text('确定删除这个${item.isVideo ? '视频' : '照片'}？此操作不可恢复。',
            style: TextStyle(fontFamily: AppFonts.primary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消',
                style: TextStyle(fontFamily: AppFonts.primary,
                    color: AppColors.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除',
                style: TextStyle(fontFamily: AppFonts.primary,
                    color: AppColors.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(mediaRepositoryProvider).deleteRecord(item.id);
      setState(() => _items.removeWhere((i) => i.id == item.id));
      if (mounted) PetToast.success(context, '已删除');
    } catch (e) {
      if (mounted) PetToast.error(context, '删除失败');
    }
  }

  // ── 两段式滑块切换按钮 ────────────────────────────────────
  Widget _buildSegmentedControl() {
    const h = 32.0;
    const btnW = 72.0; // 每段宽度
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _showOnlyMine = !_showOnlyMine);
        _load(reset: true);
      },
      child: Container(
        height: h,
        width: btnW * 2 + 4,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(h / 2),
        ),
        child: Stack(
          children: [
            // 滑动白色药丸
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              left: _showOnlyMine ? btnW : 2,
              top: 2, bottom: 2,
              width: btnW,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular((h - 4) / 2),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 6, offset: const Offset(0, 1),
                  )],
                ),
              ),
            ),
            // 文字层
            Row(children: [
              _segLabel('全部',    !_showOnlyMine, btnW),
              _segLabel('只看我的', _showOnlyMine,  btnW),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _segLabel(String label, bool active, double w) {
    return SizedBox(
      width: w,
      child: Center(
        child: Text(label,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? AppColors.onSurface : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).user?.id ?? '';
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.deviceName,
            style: TextStyle(fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildSegmentedControl(),
          ),
        ],
      ),
      body: _buildBody(me),
    );
  }

  Widget _buildBody(String myId) {
    if (_loading && _items.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.photo_library_outlined, size: 64,
              color: AppColors.onSurfaceVariant.withOpacity(0.3)),
          SizedBox(height: 12),
          Text('还没有照片或视频',
              style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 14, color: AppColors.onSurfaceVariant)),
          SizedBox(height: 8),
          Text('去机器人页面拍一张吧 📷',
              style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 12, color: AppColors.onSurfaceVariant.withOpacity(0.6))),
        ]),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _load(reset: true),
      child: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(4),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2,
                  color: AppColors.primary),
            ));
          }
          final item = _items[i];
          final isMe = item.userId == myId;
          return _MediaCell(
            item: item,
            isMe: isMe,
            onTap: () => _openViewer(item),
            onLongPress: isMe ? () => _delete(item) : null,
          );
        },
      ),
    );
  }

  void _openViewer(MediaItem item) {
    if (item.isVideo) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _VideoPlayerPage(url: item.url),
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _PhotoViewPage(url: item.url),
      ));
    }
  }
}

// ── 媒体格子 ────────────────────────────────────────────
class _MediaCell extends StatelessWidget {
  final MediaItem item;
  final bool isMe;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _MediaCell({
    required this.item,
    required this.isMe,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(fit: StackFit.expand, children: [
        // 缩略图
        CachedNetworkImage(
          imageUrl: item.thumbUrl.isNotEmpty ? item.thumbUrl : item.url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: AppColors.surfaceContainerLow,
              child: Icon(Icons.image_outlined, color: AppColors.onSurfaceVariant)),
          errorWidget: (_, __, ___) => Container(color: AppColors.surfaceContainerLow,
              child: Icon(Icons.broken_image_outlined,
                  color: AppColors.onSurfaceVariant.withOpacity(0.5))),
        ),
        // 视频图标
        if (item.isVideo)
          Center(child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
          )),
        // 时长标签（视频）
        if (item.isVideo && item.duration != null)
          Positioned(bottom: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatDuration(item.duration!),
                style: TextStyle(color: Colors.white, fontSize: 10,
                    fontFamily: AppFonts.primary),
              ),
            ),
          ),
        // 他人头像徽章（非我的内容）
        if (!isMe)
          Positioned(top: 4, left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.nickname.length > 4
                    ? item.nickname.substring(0, 4)
                    : item.nickname,
                style: TextStyle(color: Colors.white, fontSize: 9,
                    fontFamily: AppFonts.primary),
              ),
            ),
          ),
      ]),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── 图片全屏查看 ─────────────────────────────────────────
class _PhotoViewPage extends StatelessWidget {
  final String url;
  const _PhotoViewPage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ── 视频全屏播放 ─────────────────────────────────────────
class _VideoPlayerPage extends StatefulWidget {
  final String url;
  const _VideoPlayerPage({required this.url});

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _initialized
            ? GestureDetector(
                onTap: () {
                  _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
                  setState(() {});
                },
                child: AspectRatio(
                  aspectRatio: _ctrl.value.aspectRatio,
                  child: VideoPlayer(_ctrl),
                ),
              )
            : CircularProgressIndicator(color: Colors.white),
      ),
      bottomNavigationBar: _initialized
          ? VideoProgressIndicator(_ctrl,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: AppColors.primary,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white10,
              ))
          : null,
    );
  }
}
