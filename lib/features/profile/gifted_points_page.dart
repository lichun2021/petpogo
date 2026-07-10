import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import 'data/points_repository.dart';

class GiftedPointsPage extends ConsumerStatefulWidget {
  const GiftedPointsPage({super.key});

  @override
  ConsumerState<GiftedPointsPage> createState() => _GiftedPointsPageState();
}

class _GiftedPointsPageState extends ConsumerState<GiftedPointsPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() => _refreshing = true);
    } else if (_data == null) {
      setState(() => _error = null);
    }
    try {
      final data = await ref.read(pointsRepositoryProvider).fetchBalance();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '赠送积分详情加载失败，请重试';
        _refreshing = false;
      });
    }
  }

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  List<Map<String, dynamic>> _batches(dynamic value) {
    final items = (value as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .where((item) =>
            item['typeCode']?.toString() != 'permanent' &&
            _asInt(item['remaining']) > 0)
        .toList(growable: false);
    items.sort((a, b) {
      final aDate = _parseDate(a['expireAt']);
      final bDate = _parseDate(b['expireAt']);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return items;
  }

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(
        text.contains('T') ? text : text.replaceFirst(' ', 'T'));
  }

  String _typeLabel(dynamic value) {
    switch (value?.toString()) {
      case 'checkin':
        return '签到积分';
      case 'plan_free':
        return 'Free 计划积分';
      case 'plan_pro':
        return 'Pro 计划积分';
      case 'plan_promax':
      case 'plan_pro_max':
        return 'Pro Max 计划积分';
      default:
        return '赠送积分';
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}年${date.month}月${date.day}日';

  String _expiryLabel(DateTime expiresAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final local = expiresAt.toLocal();
    final expiryDay = DateTime(local.year, local.month, local.day);
    final days = expiryDay.difference(today).inDays;
    if (days < 0) return '已到期';
    if (days == 0) return '今天到期';
    return '还有 $days 天';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final batches = _batches(data?['batches']);
    final total = _asInt(data?['expiring']);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('赠送积分',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.list(children: [
                _GiftedSummary(total: total),
                const SizedBox(height: 20),
                Text('到期明细',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface)),
                const SizedBox(height: 10),
                if (data == null && _error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                else if (_error != null && data == null)
                  _ErrorState(message: _error!, onRetry: _load)
                else if (batches.isEmpty)
                  const _EmptyState()
                else
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: batches.asMap().entries.map((entry) {
                        final item = entry.value;
                        final expiresAt = _parseDate(item['expireAt']);
                        return _BatchRow(
                          key: ValueKey(item['id'] ?? entry.key),
                          title: _typeLabel(item['typeCode']),
                          amount: _asInt(item['remaining']),
                          reason: item['reason']?.toString() ?? '',
                          expireDate: expiresAt == null
                              ? '到期时间待确认'
                              : '${_formatDate(expiresAt.toLocal())}到期',
                          countdown:
                              expiresAt == null ? '' : _expiryLabel(expiresAt),
                          showDivider: entry.key < batches.length - 1,
                        );
                      }).toList(),
                    ),
                  ),
                if (_error != null && data != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 11,
                          color: AppColors.error)),
                ],
                if (_refreshing) ...[
                  const SizedBox(height: 12),
                  const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftedSummary extends StatelessWidget {
  final int total;
  const _GiftedSummary({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3D6), Color(0xFFFFFBF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0D29B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前赠送积分',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('$total',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface)),
          const SizedBox(height: 12),
          Text('每笔赠送积分独立到期，消费时优先扣除即将到期的积分。',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _BatchRow extends StatelessWidget {
  final String title;
  final int amount;
  final String reason;
  final String expireDate;
  final String countdown;
  final bool showDivider;
  const _BatchRow({
    super.key,
    required this.title,
    required this.amount,
    required this.reason,
    required this.expireDate,
    required this.countdown,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: 0.5)))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFB7791F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.card_giftcard_rounded,
                size: 20, color: Color(0xFFB7791F)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface)),
                  ),
                  Text('$amount 积分',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFB7791F))),
                ]),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(reason,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant)),
                ],
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: Text(expireDate,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant)),
                  ),
                  if (countdown.isNotEmpty)
                    Text(countdown,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB7791F))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Column(children: [
        Icon(Icons.card_giftcard_outlined,
            size: 52, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('暂无赠送积分批次',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 13,
                color: AppColors.onSurfaceVariant)),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function({bool refresh}) onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(children: [
        Text(message,
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 13,
                color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        TextButton(onPressed: () => onRetry(), child: const Text('重新加载')),
      ]),
    );
  }
}
