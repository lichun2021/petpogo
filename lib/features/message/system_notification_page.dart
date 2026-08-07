import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/pet_toast.dart';
import '../device/device_detail_page.dart';
import '../device/robot_device_page.dart';
import 'data/models/device_event_model.dart';
import 'data/repository/device_event_repository.dart';

/// 系统通知列表页（承接设备/宠物异常通知）
///
/// 数据源：业务后端 GET /sdkapi/device-event/list（已就绪）
/// 通知类型：越界告警(breach) / 设备离线(offline) / 低电提醒(low_battery)
/// 进入路径：消息页系统通知卡片 / 首页铃铛 / 我的页铃铛 → 消息页 → 本页
class SystemNotificationPage extends ConsumerStatefulWidget {
  const SystemNotificationPage({super.key});

  @override
  ConsumerState<SystemNotificationPage> createState() =>
      _SystemNotificationPageState();
}

class _SystemNotificationPageState extends ConsumerState<SystemNotificationPage> {
  List<DeviceEvent> _events = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _total = 0;
  String? _error;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirst());
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final repo = ref.read(deviceEventRepositoryProvider);
      final events = await repo.fetchEvents(page: 1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
        _total = events.length; // 后端 total 字段在 _unwrap 后未保留，用 list 长度近似
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _events.length < _page * _pageSize) return;
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(deviceEventRepositoryProvider);
      final next = await repo.fetchEvents(page: _page + 1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _events = [..._events, ...next];
        _page += 1;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  bool get _hasUnread => _events.any((e) => !e.read);

  Future<void> _markAllRead() async {
    try {
      final repo = ref.read(deviceEventRepositoryProvider);
      await repo.markAllRead();
      if (!mounted) return;
      setState(() {
        for (final e in _events) {
          // DeviceEvent 字段 final，用新对象替换
        }
        _events = _events.map((e) => e.read ? e : _copyAsRead(e)).toList();
      });
      PetToast.success(context, '已全部标记为已读');
    } catch (e) {
      if (!mounted) return;
      PetToast.error(context, '操作失败');
    }
  }

  DeviceEvent _copyAsRead(DeviceEvent e) => DeviceEvent(
        id: e.id,
        type: e.type,
        petName: e.petName,
        deviceMac: e.deviceMac,
        deviceName: e.deviceName,
        deviceProductKey: e.deviceProductKey,
        desc: e.desc,
        time: e.time,
        read: true,
      );

  Future<void> _onTapEvent(DeviceEvent e) async {
    // 跳转对应宠物设备详情页，跳转后标记已读
    if (!e.read) {
      try {
        await ref.read(deviceEventRepositoryProvider).markRead(e.id);
      } catch (_) {}
      setState(() {
        _events = _events.map((x) => x.id == e.id ? _copyAsRead(x) : x).toList();
      });
    }
    if (e.deviceMac.isEmpty) return;
    final isRobot = e.deviceProductKey.contains('robot');
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isRobot
            ? RobotDevicePage(mac: e.deviceMac, name: e.deviceName)
            : DeviceDetailPage(mac: e.deviceMac, name: e.deviceName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('系统通知',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          if (_hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: Text('全部已读',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            SizedBox(height: 8),
            Text(_error!, style: TextStyle(fontSize: 13, color: AppColors.error)),
            SizedBox(height: 12),
            TextButton(onPressed: _loadFirst, child: Text('重试')),
          ],
        ),
      );
    }
    if (_events.isEmpty) return _buildEmpty();
    return _buildGroupedList();
  }

  // ── 空状态 ─────────────────────────────────────────────
  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🛡️', style: TextStyle(fontSize: 52)),
            SizedBox(height: 14),
            Text('一切正常',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant)),
            SizedBox(height: 6),
            Text('暂无设备异常通知\n宠物安全守护中',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                    height: 1.6)),
          ],
        ),
      );

  // ── 按日期分组列表 ─────────────────────────────────────
  Widget _buildGroupedList() {
    final now = DateTime.now();
    // 按日期分组（保序：列表已按 created_at DESC，分组保持顺序）
    final groups = <String, List<DeviceEvent>>{};
    for (final e in _events) {
      final label = _dateLabel(e.time, now);
      groups.putIfAbsent(label, () => []).add(e);
    }
    final labels = groups.keys.toList();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: labels.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, gi) {
          if (gi == labels.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            );
          }
          final label = labels[gi];
          final items = groups[label]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Text(label,
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant)),
              ),
              ...items.map((e) => _EventRow(
                    event: e,
                    onTap: () => _onTapEvent(e),
                  )),
            ],
          );
        },
      ),
    );
  }

  String _dateLabel(DateTime t, DateTime now) {
    final d = DateTime(t.year, t.month, t.day);
    final n = DateTime(now.year, now.month, now.day);
    final diff = n.difference(d).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${t.month}月${t.day}日';
  }
}

// ── 通知行 ────────────────────────────────────────────────
class _EventRow extends StatelessWidget {
  final DeviceEvent event;
  final VoidCallback onTap;
  const _EventRow({required this.event, required this.onTap});

  (IconData, Color, Color) get _iconSpec {
    switch (event.type) {
      case 'breach':
        return (Icons.warning_amber_rounded,
            const Color(0xFFFFE8E0), AppColors.error);
      case 'offline':
        return (Icons.wifi_off_rounded,
            const Color(0xFFFFF3E0), const Color(0xFFE07000));
      case 'low_battery':
        return (Icons.battery_alert_rounded,
            const Color(0xFFFFFBE0), const Color(0xFFC09000));
      default:
        return (Icons.info_outline_rounded,
            AppColors.surfaceContainerLow, AppColors.onSurfaceVariant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, bg, color) = _iconSpec;
    final isUnread = !event.read;
    final title = switch (event.type) {
      'breach' => '越界告警',
      'offline' => '设备离线',
      'low_battery' => '低电提醒',
      _ => '设备通知',
    };
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFFFF8F5) : AppColors.surface,
          border: Border(
            left: BorderSide(
              color: isUnread ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: color),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(title,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isUnread
                                ? AppColors.onSurface
                                : AppColors.onSurfaceVariant)),
                    SizedBox(width: 6),
                    _StatusBadge(read: event.read),
                  ]),
                  if (event.desc.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(event.desc,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 11,
                            color: isUnread
                                ? AppColors.onSurfaceVariant
                                : AppColors.onSurfaceVariant.withOpacity(0.7),
                            height: 1.5)),
                  ],
                  SizedBox(height: 4),
                  Row(children: [
                    if (event.petName.isNotEmpty)
                      Text('🐱 ${event.petName}',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    if (event.petName.isNotEmpty) SizedBox(width: 8),
                    Text(_timeStr(event.time),
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant)),
                  ]),
                ],
              ),
            ),
            if (isUnread)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 6),
                decoration:
                    BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  String _timeStr(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ── 状态标签 ──────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool read;
  const _StatusBadge({required this.read});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: read ? const Color(0xFFE8F5E9) : const Color(0xFFFFEDED),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(read ? '已处理' : '未处理',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: read ? const Color(0xFF4CAF50) : AppColors.error)),
      );
}
