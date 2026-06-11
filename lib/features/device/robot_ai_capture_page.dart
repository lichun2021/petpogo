/// 自动抓拍页 — 配置面板 + 媒体库（点击展开详情）
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/pet_toast.dart';
import 'data/models/capture_model.dart';
import 'data/repository/capture_repository.dart';
import 'widgets/ai_emotion_card.dart';

class RobotAiCapturePage extends ConsumerStatefulWidget {
  final String mac;
  final String deviceName;

  const RobotAiCapturePage({
    super.key,
    required this.mac,
    required this.deviceName,
  });

  @override
  ConsumerState<RobotAiCapturePage> createState() => _RobotAiCapturePageState();
}

class _RobotAiCapturePageState extends ConsumerState<RobotAiCapturePage> {
  // ── 配置状态 ─────────────────────────────────────────────
  bool _enabled = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);
  Set<int> _weekdays = {1, 2, 3, 4, 5, 6, 7}; // 1=周一..7=周日
  String _trigger = 'motion'; // 'motion' | 'scheduled'
  int _count = 5; // AI 分析次数上限

  // ── 媒体库状态 ────────────────────────────────────────────
  final List<CaptureItem> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  final ScrollController _scroll = ScrollController();

  String get _prefKey => 'robot_ai_capture_${widget.mac}';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadMedia(reset: true);
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

  // ── 配置读写 ─────────────────────────────────────────────
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _enabled = m['enabled'] == true;
        _startTime = _parseTime(m['start'] as String? ?? '09:00');
        _endTime = _parseTime(m['end'] as String? ?? '22:00');
        _weekdays = ((m['weekdays'] as List?) ?? [1, 2, 3, 4, 5, 6, 7])
            .map((e) => e as int)
            .toSet();
        _trigger = (m['trigger'] as String?) ?? 'motion';
        _count = (m['count'] as int?) ?? 5;
      });
    } catch (_) {}
  }

  TimeOfDay _parseTime(String s) {
    final p = s.split(':');
    return TimeOfDay(
        hour: int.tryParse(p[0]) ?? 9,
        minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _persistPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefKey,
          jsonEncode({
            'enabled': _enabled,
            'start': _fmtTime(_startTime),
            'end': _fmtTime(_endTime),
            'weekdays': _weekdays.toList()..sort(),
            'trigger': _trigger,
            'count': _count,
          }));
    } catch (_) {
      if (mounted) PetToast.error(context, '保存失败，请重试');
    }
  }

  // ── 媒体库加载 ────────────────────────────────────────────
  Future<void> _loadMedia({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _page = 1;
      _hasMore = true;
      _items.clear();
    }
    setState(() => _loading = true);
    try {
      final result = await ref.read(captureRepositoryProvider).fetchCaptureList(
            deviceId: widget.mac,
            page: _page,
          );
      setState(() {
        _items.addAll(result.list);
        _hasMore = result.hasMore;
        _page++;
      });
    } catch (_) {
      if (mounted) PetToast.error(context, '媒体库加载失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    await _loadMedia();
  }

  // ── 选择时间 ─────────────────────────────────────────────
  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: const Color(0xFF00BFA5)),
        ),
        child: child!,
      ),
    );
    if (t != null) {
      setState(() => isStart ? _startTime = t : _endTime = t);
      await _persistPrefs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _loadMedia(reset: true),
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(child: _buildConfigCard()),
                SliverToBoxAdapter(child: _buildMediaHeader()),
                _buildMediaGrid(),
                if (_hasMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary)),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.arrow_back_ios_rounded,
                  size: 20, color: AppColors.onPrimary),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('自动抓拍',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimary,
                  )),
              Text(widget.deviceName,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    color: AppColors.onPrimary.withValues(alpha: 0.7),
                  )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildConfigCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(children: [
        const Divider(height: 1, indent: 20, endIndent: 20),
        // ── 时间段 ──
        _buildTapRow(
          icon: Icons.schedule_rounded,
          label: '生效时间',
          value: '${_fmtTime(_startTime)} ~ ${_fmtTime(_endTime)}',
          onTap: () async {
            await _pickTime(true);
            await _pickTime(false);
          },
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
        // ── 重复 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(children: [
            Icon(Icons.repeat_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Text('重复',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            _buildWeekdayPicker(),
          ]),
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
        // ── AI 分析次数 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(children: [
            Icon(Icons.analytics_outlined, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Text('AI分析次数/天',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            _CountPickerButton(
              value: _count.clamp(1, 9),
              onTap: _pickCount,
            ),
          ]),
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
        const SizedBox(height: 6),
      ]),
    );
  }

  Future<void> _pickCount() async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountPickerSheet(initialValue: _count.clamp(1, 9)),
    );
    if (picked != null && mounted) {
      setState(() => _count = picked);
      await _persistPrefs();
    }
  }

  Widget _buildWeekdayPicker() {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: List.generate(7, (i) {
        final day = i + 1;
        final sel = _weekdays.contains(day);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (sel) {
                if (_weekdays.length > 1) _weekdays.remove(day);
              } else {
                _weekdays.add(day);
              }
            });
            unawaited(_persistPrefs());
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFF43E97B) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(labels[i],
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 10,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    color: sel ? Colors.white : Colors.grey.shade600,
                  )),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTapRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 14,
                  color: Colors.grey.shade600)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  // ── 媒体库标题 ────────────────────────────────────────────
  Widget _buildMediaHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(children: [
        Text('抓拍记录',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('${_items.length}',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              )),
        ),
      ]),
    );
  }

  // ── 媒体网格 ─────────────────────────────────────────────
  Widget _buildMediaGrid() {
    if (_loading && _items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)),
        ),
      );
    }
    if (_items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(children: [
            const Text('📷', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('暂无抓拍记录',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 15,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text('开启自动抓拍后，记录将显示在这里',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    color: Colors.grey.shade400)),
          ]),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i >= _items.length) return null;
            return _CaptureCell(
              item: _items[i],
              onTap: () => _openDetail(_items[i]),
            );
          },
          childCount: _items.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
      ),
    );
  }

  // ── 点击打开详情底部弹窗 ──────────────────────────────
  void _openDetail(CaptureItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CaptureDetailSheet(
        item: item,
        onDeleted: () {
          setState(() => _items.removeWhere((e) => e.id == item.id));
        },
      ),
    );
  }
}

class _CountPickerButton extends StatelessWidget {
  final int value;
  final VoidCallback onTap;

  const _CountPickerButton({
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value 次',
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPickerSheet extends StatefulWidget {
  final int initialValue;

  const _CountPickerSheet({required this.initialValue});

  @override
  State<_CountPickerSheet> createState() => _CountPickerSheetState();
}

class _CountPickerSheetState extends State<_CountPickerSheet> {
  late int _selected;
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue.clamp(1, 9);
    _controller = FixedExtentScrollController(initialItem: _selected - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'AI 分析次数',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(
                    '完成',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 180,
              child: CupertinoPicker(
                scrollController: _controller,
                itemExtent: 42,
                useMagnifier: true,
                magnification: 1.08,
                squeeze: 1.08,
                backgroundColor: Colors.transparent,
                selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                  background: AppColors.primary.withValues(alpha: 0.06),
                ),
                onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() => _selected = index + 1);
                },
                children: List.generate(
                  9,
                  (index) => Center(
                    child: Text(
                      '${index + 1} 次',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 网格格子 ─────────────────────────────────────────────────
class _CaptureCell extends StatelessWidget {
  final CaptureItem item;
  final VoidCallback onTap;
  const _CaptureCell({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(fit: StackFit.expand, children: [
          // ── 底层：封面图 / 视频占位 ──
          _buildThumbnail(),
          // AI 情绪标签（渐变遮罩底部）
          if (item.aiResult?.top != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Text(
                  '${item.aiResult!.top!.emoji} ${item.aiResult!.top!.name}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                ),
              ),
            ),
          // 右上角时间（仅视频显示）
          if (item.isVideo)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _fmtShort(item.createdAt),
                  style: const TextStyle(color: Colors.white, fontSize: 8),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  /// 底层缩略图：区分图片 / 有封面视频 / 无封面视频
  Widget _buildThumbnail() {
    // 视频且没有封面 → 黑底 + 大播放图标
    if (item.isVideo && item.coverUrl.isEmpty) {
      return Container(
        color: const Color(0xFF1C1C1E),
        child: const Center(
          child: Icon(Icons.play_circle_fill_rounded,
              size: 40, color: Colors.white70),
        ),
      );
    }
    // 有封面（图片 or 视频封面）→ 加载网络图片
    final imageUrl =
        item.coverUrl.isNotEmpty ? item.coverUrl : item.resourceUrl;
    return Stack(fit: StackFit.expand, children: [
      CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Colors.grey.shade200,
          child: const Center(
              child: Icon(Icons.image_outlined, color: Colors.grey, size: 28)),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.grey.shade200,
          child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.grey, size: 28)),
        ),
      ),
      // 视频有封面 → 中央播放角标
      if (item.isVideo)
        Center(
            child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
              color: Colors.black45, shape: BoxShape.circle),
          child: const Icon(Icons.play_arrow_rounded,
              color: Colors.white, size: 20),
        )),
    ]);
  }

  String _fmtShort(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }
}

// ── 详情底部弹窗 ───────────────────────────────────────────────
class _CaptureDetailSheet extends ConsumerStatefulWidget {
  final CaptureItem item;
  final VoidCallback onDeleted;
  const _CaptureDetailSheet({required this.item, required this.onDeleted});

  @override
  ConsumerState<_CaptureDetailSheet> createState() =>
      _CaptureDetailSheetState();
}

class _CaptureDetailSheetState extends ConsumerState<_CaptureDetailSheet> {
  VideoPlayerController? _ctrl;
  bool _videoReady = false;
  bool _downloading = false;
  bool _deleting = false;

  // ── 下载到相册（用 Dio）────────────────────────────────
  Future<void> _download() async {
    final url = widget.item.resourceUrl;
    if (url.isEmpty) return;
    setState(() => _downloading = true);
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final ok = await Gal.requestAccess(toAlbum: true);
        if (!ok) {
          if (mounted) PetToast.error(context, '无相册权限，请在设置中开启');
          return;
        }
      }
      final tmp = await getTemporaryDirectory();
      final ext = widget.item.isVideo ? 'mp4' : 'jpg';
      final path =
          '${tmp.path}/capture_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Dio().download(url, path);
      if (widget.item.isVideo) {
        await Gal.putVideo(path, album: 'PetPogo');
      } else {
        await Gal.putImage(path, album: 'PetPogo');
      }
      await File(path).delete();
      if (mounted) PetToast.success(context, '已保存到相册');
    } catch (_) {
      if (mounted) PetToast.error(context, '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  // ── 删除记录 ──────────────────────────────────────────
  Future<void> _delete(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除抓拍记录'),
        content: const Text('确定要删除这条抓拍记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      // 通过 captureRepositoryProvider 调用（带 JWT 认证）
      await ref.read(captureRepositoryProvider).deleteCapture(widget.item.id);
      widget.onDeleted();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) PetToast.error(context, '删除失败，请重试');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo && widget.item.resourceUrl.isNotEmpty) {
      _ctrl =
          VideoPlayerController.networkUrl(Uri.parse(widget.item.resourceUrl))
            ..initialize().then((_) {
              if (mounted) setState(() => _videoReady = true);
              _ctrl?.play();
            });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // 拖拽指示条
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              controller: sc,
              child: Column(children: [
                // 视频/图片区
                _buildMediaArea(),
                // 信息区
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 时间 + 类型
                      _InfoRow(
                        icon: '📅',
                        label: '拍摄时间',
                        value: _fmtFull(widget.item.createdAt),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: '📍',
                        label: '触发方式',
                        value: widget.item.eventTypeLabel,
                      ),
                      // AI 情绪卡片
                      if (widget.item.aiResult != null &&
                          widget.item.aiResult!.emotions.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        AiEmotionCard(
                            result: widget.item.aiResult!,
                            time: widget.item.createdAt),
                      ],
                      const SizedBox(height: 20),
                      // 操作按钮：下载 + 删除
                      Row(children: [
                        // 下载按钮（有资源才显示）
                        if (widget.item.resourceUrl.isNotEmpty) ...[
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: _downloading ? null : _download,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                  textStyle: TextStyle(
                                    fontFamily: AppFonts.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                                icon: _downloading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.download_rounded,
                                        size: 18),
                                label: Text(
                                  _downloading ? '保存中...' : '保存到相册',
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        // 删除按钮
                        SizedBox(
                          width: widget.item.resourceUrl.isNotEmpty
                              ? 46
                              : double.infinity,
                          height: 46,
                          child: Builder(
                              builder: (ctx) => ElevatedButton(
                                    onPressed:
                                        _deleting ? null : () => _delete(ctx),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade50,
                                      foregroundColor: Colors.red.shade700,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: _deleting
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.red.shade700))
                                        : widget.item.resourceUrl.isNotEmpty
                                            ? const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 20)
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                    const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 18),
                                                    const SizedBox(width: 6),
                                                    const Text('删除记录',
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700)),
                                                  ]),
                                  )),
                        ),
                      ]),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMediaArea() {
    if (widget.item.isVideo) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: _videoReady
              ? GestureDetector(
                  onTap: () {
                    _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play();
                    setState(() {});
                  },
                  child: Stack(children: [
                    AspectRatio(
                      aspectRatio: _ctrl!.value.aspectRatio,
                      child: VideoPlayer(_ctrl!),
                    ),
                    if (!_ctrl!.value.isPlaying)
                      const Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              size: 60, color: Colors.white70)),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: VideoProgressIndicator(_ctrl!,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Color(0xFF43E97B),
                            bufferedColor: Colors.white30,
                            backgroundColor: Colors.white10,
                          )),
                    ),
                  ]),
                )
              : const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
        ),
      );
    }
    // 图片
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: CachedNetworkImage(
        imageUrl: widget.item.resourceUrl,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_outlined,
                size: 48, color: Colors.grey)),
      ),
    );
  }

  String _fmtFull(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── 信息行 ────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 14,
              color: Colors.grey.shade600)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600)),
    ]);
  }
}
