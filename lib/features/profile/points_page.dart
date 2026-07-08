/// 积分明细页
///
/// 后端接口（已对齐）：
///   GET /sdkapi/points/balance → { weekly, permanent, total }
///   GET /sdkapi/points/list?page=&limit= → { list: [{ direction, points_type, amount, balance_after, reason, ref_type, created_at }], page, limit }
///   GET /sdkapi/points/rules → { list: [{ consume_type, name, unit_points, unit_basis }] }
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import 'data/points_repository.dart';

class PointsPage extends ConsumerStatefulWidget {
  const PointsPage({super.key});

  @override
  ConsumerState<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends ConsumerState<PointsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic>? _balance; // null = 加载中
  Map<String, dynamic>? _rulesData;
  List<Map<String, dynamic>> _allTx = [];
  int _page = 1;
  static const _limit = 20;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final repo = ref.read(pointsRepositoryProvider);
    try {
      final balance = repo.fetchBalance();
      final rules = repo.fetchRules();
      final txList = repo.fetchTransactions(page: 1, limit: _limit);
      final b = await balance;
      final r = await rules;
      final t = await txList;
      if (!mounted) return;
      setState(() {
        _balance = b;
        _rulesData = {'list': r};
        _allTx = t;
        _page = 1;
        _hasMore = t.length >= _limit;
      });
    } catch (e) {
      if (!mounted) return;
      // 回退 mock（开发期）
      setState(() {
        _balance = _mockBalance();
        _rulesData = _mockRules();
        _allTx = _mockTransactions();
      });
      debugPrint('[积分] 接口失败，回退 mock: $e');
    }
  }

  /// 上拉加载更多
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(pointsRepositoryProvider);
      final next = await repo.fetchTransactions(page: _page + 1, limit: _limit);
      if (!mounted) return;
      setState(() {
        _allTx.addAll(next);
        _page++;
        _hasMore = next.length >= _limit;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// direction: 1=获得 2=消耗；0=全部
  List<Map<String, dynamic>> _filtered(int directionFilter) {
    if (directionFilter == 0) return _allTx;
    return _allTx.where((t) => t['direction'] == directionFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              color: AppColors.onSurface,
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('积分明细',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, size: 20),
                color: AppColors.onSurfaceVariant,
                tooltip: '积分规则',
                onPressed: _showRules,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: _balance == null
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                : _BalanceCard(balance: _balance!),
          ),
        ],
        body: Column(children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 6,
                      spreadRadius: -2,
                      offset: const Offset(0, 1)),
                ],
              ),
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              labelStyle: TextStyle(
                  fontFamily: AppFonts.primary, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: '全部'),
                Tab(text: '收入'),
                Tab(text: '支出'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TxList(
                    items: _filtered(0),
                    hasMore: _hasMore,
                    loadingMore: _loadingMore,
                    onLoadMore: _loadMore),
                _TxList(
                    items: _filtered(1),
                    hasMore: _hasMore,
                    loadingMore: _loadingMore,
                    onLoadMore: _loadMore),
                _TxList(
                    items: _filtered(2),
                    hasMore: _hasMore,
                    loadingMore: _loadingMore,
                    onLoadMore: _loadMore),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _showRules() {
    if (_rulesData == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RulesSheet(data: _rulesData!),
    );
  }
}

// ── 余额卡 ────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final Map<String, dynamic> balance;
  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final total = balance['total'] as int;
    final permanent = balance['permanent'] as int;
    final weekly = balance['weekly'] as int;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: -4,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('我的积分',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 6),
          Text('$total',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _SubStat(
                  label: '永久积分',
                  value: permanent,
                  icon: Icons.all_inclusive_rounded),
            ),
            Container(
                width: 1,
                height: 28,
                color: Colors.white.withValues(alpha: 0.2)),
            Expanded(
              child: _SubStat(
                  label: '周积分',
                  value: weekly,
                  icon: Icons.date_range_rounded),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded,
                  size: 13, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '周积分每周一重置，永久积分不过期',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SubStat extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const _SubStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 5),
        Text('$label $value',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.95))),
      ],
    );
  }
}

// ── 流水列表 ─────────────────────────────────────────────
class _TxList extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() onLoadMore;
  const _TxList({
    required this.items,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
  });

  @override
  State<_TxList> createState() => _TxListState();
}

class _TxListState extends State<_TxList> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >=
          _scroll.position.maxScrollExtent - 200) {
        if (widget.hasMore && !widget.loadingMore) widget.onLoadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('暂无记录',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
      itemCount: widget.items.length + (widget.hasMore || widget.loadingMore ? 1 : 0),
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      itemBuilder: (_, i) {
        // 最后一项：加载更多指示器
        if (i >= widget.items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: widget.loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('上拉加载更多',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant)),
            ),
          );
        }
        final tx = widget.items[i];
        // direction: 1=获得 2=消耗
        final isIncome = tx['direction'] == 1;
        final amount = tx['amount'] as int;
        final pointsType = tx['points_type'] as int; // 1=周 2=永久
        final reason = tx['reason'] as String? ?? '';
        final refType = tx['ref_type'] as String? ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isIncome ? AppColors.primary : AppColors.onSurfaceVariant)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconForRefType(refType, isIncome),
                size: 18,
                color: isIncome ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reason.isNotEmpty ? reason : (isIncome ? '积分收入' : '积分消耗'),
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(_fmtTime(tx['created_at'] as String),
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(pointsType == 2 ? '永久' : '周',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant)),
                    ),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}$amount',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isIncome
                          ? const Color(0xFF16A34A)
                          : AppColors.onSurface),
                ),
                if (tx['balance_after'] != null) ...[
                  const SizedBox(height: 1),
                  Text('余额 ${tx['balance_after']}',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant)),
                ],
              ],
            ),
          ]),
        );
      },
    );
  }

  IconData _iconForRefType(String refType, bool isIncome) {
    if (isIncome) {
      switch (refType) {
        case 'checkin':
        case 'checkin_reward':
          return Icons.calendar_month_rounded;
        case 'plan_grant':
          return Icons.workspace_premium_rounded;
        case 'recharge':
          return Icons.account_balance_wallet_rounded;
        default:
          return Icons.add_circle_outline_rounded;
      }
    }
    switch (refType) {
      case 'ai_consumption':
        return Icons.bolt_rounded;
      case 'voice_analyze':
        return Icons.mic_rounded;
      case 'image_analyze':
        return Icons.image_rounded;
      case 'consult':
        return Icons.chat_rounded;
      default:
        return Icons.remove_circle_outline_rounded;
    }
  }

  String _fmtTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}';
    } catch (_) {
      return iso;
    }
  }
}

// ── 积分规则弹窗 ─────────────────────────────────────────
class _RulesSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RulesSheet({required this.data});

  @override
  Widget build(BuildContext context) {
    final ruleList = (data['list'] as List).cast<Map<String, dynamic>>();
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPad),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Text('积分规则',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface)),
            const SizedBox(height: 4),
            Text('以下为积分消费规则',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 12),
            ...ruleList.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Icon(Icons.bolt_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['name'] as String,
                              style: TextStyle(
                                  fontFamily: AppFonts.primary,
                                  fontSize: 13,
                                  color: AppColors.onSurface)),
                          if ((r['unit_basis'] as String?) == 'per_call')
                            Text('每次调用',
                                style: TextStyle(
                                    fontFamily: AppFonts.primary,
                                    fontSize: 10,
                                    color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Text(
                      '-${r['unit_points']}',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface),
                    ),
                  ]),
                )),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('我知道了',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mock 数据（对齐后端字段）──────────────────────────────
Map<String, dynamic> _mockBalance() {
  return {
    'weekly': 65,     // 周积分
    'permanent': 100, // 永久积分
    'total': 165,
  };
}

Map<String, dynamic> _mockRules() {
  return {
    'list': [
      {'consume_type': 'image_analyze', 'name': '图片情绪分析', 'unit_points': 5, 'unit_basis': 'per_call'},
      {'consume_type': 'voice_analyze', 'name': '语音情绪分析', 'unit_points': 5, 'unit_basis': 'per_call'},
      {'consume_type': 'consult', 'name': 'AI 问诊', 'unit_points': 8, 'unit_basis': 'per_call'},
    ],
  };
}

List<Map<String, dynamic>> _mockTransactions() {
  return [
    {
      'id': '123',
      'direction': 2,        // 1=获得 2=消耗
      'points_type': 1,      // 1=周 2=永久
      'amount': 5,
      'balance_after': 60,
      'reason': '图片情绪分析',
      'ref_type': 'ai_consumption',
      'ref_id': 'abc123',
      'created_at': '2026-07-08T10:00:00.000Z',
    },
    {
      'id': '122',
      'direction': 2,
      'points_type': 1,
      'amount': 5,
      'balance_after': 65,
      'reason': '语音情绪分析',
      'ref_type': 'ai_consumption',
      'ref_id': 'abc122',
      'created_at': '2026-07-08T09:30:00.000Z',
    },
    {
      'id': '121',
      'direction': 1,        // 获得
      'points_type': 2,      // 永久
      'amount': 100,
      'balance_after': 100,
      'reason': '开通 Pro 计划赠送',
      'ref_type': 'plan_grant',
      'ref_id': 'plan_2',
      'created_at': '2026-07-07T18:00:00.000Z',
    },
    {
      'id': '120',
      'direction': 1,        // 获得
      'points_type': 2,      // 永久（连续签到奖励）
      'amount': 10,
      'balance_after': 65,
      'reason': '连续签到 3 天奖励',
      'ref_type': 'checkin_reward',
      'ref_id': 'rule_2',
      'created_at': '2026-07-07T09:00:00.000Z',
    },
    {
      'id': '119',
      'direction': 1,
      'points_type': 1,      // 周
      'amount': 2,
      'balance_after': 55,
      'reason': '每日签到',
      'ref_type': 'checkin',
      'ref_id': 'rule_1',
      'created_at': '2026-07-07T08:50:00.000Z',
    },
  ];
}
