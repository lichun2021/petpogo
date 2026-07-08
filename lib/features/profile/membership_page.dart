/// 购买计划页（Free / Pro / ProMax）
///
/// 后端接口（已对齐）：
///   GET  /sdkapi/plan/list → { list: [{ id, plan_type, name, price, duration_days, weekly_points_grant, permanent_points_grant, description }] }
///   POST /sdkapi/plan/order { planId } → { orderId, planId, amount, status }
///   plan_type: 0=Free 1=Pro 2=ProMax
///   status: 0=待支付 1=已支付 2=已取消
///
/// 注意：order 接口仅生成占位订单，不对接真实支付，需管理后台人工确认。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/pet_toast.dart';
import '../auth/controller/auth_controller.dart';
import 'data/points_repository.dart';

class MembershipPage extends ConsumerStatefulWidget {
  const MembershipPage({super.key});

  @override
  ConsumerState<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends ConsumerState<MembershipPage> {
  String? _selectedPlanId;
  bool _ordering = false;
  bool _disposed = false;
  String _orderStatusText = ''; // 订单轮询时的提示文案

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  List<Map<String, dynamic>> _plans = const [];
  bool _plansLoading = true;

  Future<void> _loadPlans() async {
    try {
      final list = await ref.read(pointsRepositoryProvider).fetchPlans();
      if (!mounted) return;
      setState(() {
        _plans = list;
        _plansLoading = false;
      });
      // 默认选中 Pro（plan_type=1）
      final pro = _plans.firstWhere(
        (p) => p['plan_type'] == 1,
        orElse: () => _plans.isEmpty ? <String, dynamic>{} : _plans.first,
      );
      if (pro.isNotEmpty) {
        _selectedPlanId = pro['id'] as String;
      }
    } catch (e) {
      if (!mounted) return;
      // 回退 mock
      setState(() {
        _plans = _mockPlans()['list'].cast<Map<String, dynamic>>();
        _plansLoading = false;
      });
      final pro = _plans.firstWhere((p) => p['plan_type'] == 1,
          orElse: () => _plans.first);
      _selectedPlanId = pro['id'] as String;
      debugPrint('[会员] plan/list 失败，回退 mock: $e');
    }
  }

  String get _currentPlanId {
    final user = ref.read(authControllerProvider).user;
    // TODO: 后端如果提供「当前订阅计划」接口，在此读取；目前默认 free
    return user?.vipLevel == 'pro' ? '2' : '1';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
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
            title: Text('购买计划',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: _plansLoading
                ? const Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      // ── 套餐选择 ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Text('选择套餐',
                            style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface)),
                ),
                ..._plans.map((p) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: _PlanCard(
                        plan: p,
                        selected: _selectedPlanId == p['id'],
                        isCurrent: _currentPlanId == p['id'],
                        onTap: () =>
                            setState(() => _selectedPlanId = p['id'] as String),
                      ),
                    )),
                const SizedBox(height: 20),
                // ── 积分赠送对比 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text('积分赠送',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _GrantTable(plans: _plans),
                ),
                const SizedBox(height: 16),
                // ── 说明 ──
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '购买后积分自动发放到账。周积分每周一重置，永久积分不过期。\n订单提交后需后台确认支付后生效。',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                              height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      // ── 底部开通按钮 ──
      bottomNavigationBar: _plans.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    if (_plans.isEmpty) return const SizedBox.shrink();
    final selected = _plans.firstWhere(
      (p) => p['id'] == _selectedPlanId,
      orElse: () => _plans.first,
    );
    final planType = selected['plan_type'] as int;
    final price = (selected['price'] as num).toDouble();
    final isCurrent = _currentPlanId == selected['id'];
    final isFree = planType == 0;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
              top: BorderSide(color: AppColors.outlineVariant, width: 1)),
        ),
        child: Row(
          children: [
            if (!isFree) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('¥$price',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary)),
                  Text('${selected['duration_days'] ?? 30} 天',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: (isCurrent || isFree || _ordering)
                      ? null
                      : _onOrder,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.onSurfaceVariant.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _ordering
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _orderStatusText.isNotEmpty
                                    ? _orderStatusText
                                    : '处理中...',
                                style: TextStyle(
                                    fontFamily: AppFonts.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          isFree
                              ? '当前免费计划'
                              : isCurrent
                                  ? '当前套餐'
                                  : '开通 ${selected['name']}',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// POST /sdkapi/plan/order 创建订单，然后轮询 GET /sdkapi/plan/order/:orderId
  /// status: 0=待支付 1=已支付 2=已取消
  Future<void> _onOrder() async {
    if (_ordering) return;
    final planId = _selectedPlanId;
    if (planId == null) return;
    setState(() {
      _ordering = true;
      _orderStatusText = '创建订单中...';
    });
    HapticFeedback.mediumImpact();
    try {
      // 1. 创建订单
      final order =
          await ref.read(pointsRepositoryProvider).createOrder(planId: planId);
      if (!mounted) return;
      final orderId = order['orderId']?.toString() ?? '';
      if (orderId.isEmpty) {
        throw Exception('订单创建失败：未返回 orderId');
      }

      // 2. 轮询订单状态（每 2 秒一次，最多 30 次 = 60 秒）
      if (_disposed) return;
      setState(() => _orderStatusText = '等待支付确认...');
      await _pollOrderStatus(orderId);
    } catch (e) {
      if (!_disposed && mounted) {
        PetToast.error(context, '订单创建失败，请重试');
      }
    } finally {
      if (!_disposed && mounted) {
        setState(() {
          _ordering = false;
          _orderStatusText = '';
        });
      }
    }
  }

  /// 轮询订单状态。
  /// status: 0=待支付 1=已支付 2=已取消
  Future<void> _pollOrderStatus(String orderId) async {
    const maxAttempts = 30;
    const interval = Duration(seconds: 2);
    for (var i = 0; i < maxAttempts; i++) {
      if (_disposed || !mounted) return;
      try {
        final data =
            await ref.read(pointsRepositoryProvider).fetchOrder(orderId);
        final status = data['status'] as int? ?? 0;
        if (_disposed || !mounted) return;
        if (status == 1) {
          // 已支付
          if (!_disposed && mounted) {
            PetToast.success(context, '开通成功 🎉');
            // 刷新会员状态
            ref.read(authControllerProvider.notifier).refreshUser();
          }
          return;
        }
        if (status == 2) {
          // 已取消
          if (!_disposed && mounted) {
            PetToast.error(context, '订单已取消');
          }
          return;
        }
        // status==0 继续轮询
        setState(() => _orderStatusText = '等待支付确认...(${i + 1}/$maxAttempts)');
      } catch (_) {
        // 网络错误继续轮询
      }
      await Future.delayed(interval);
    }
    // 超时
    if (!_disposed && mounted) {
      PetToast.show(context, '支付确认中，请稍后在订单页查看');
    }
  }
}

// ── 套餐卡片 ──────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final planType = plan['plan_type'] as int; // 0/1/2
    final name = plan['name'] as String;
    final price = (plan['price'] as num).toDouble();
    final duration = plan['duration_days'] as int?;
    final weekly = plan['weekly_points_grant'] as int? ?? 0;
    final permanent = plan['permanent_points_grant'] as int? ?? 0;
    final desc = plan['description'] as String? ?? '';

    final accent = planType == 2
        ? const Color(0xFFB8860B) // ProMax 金
        : planType == 1
            ? AppColors.primary // Pro
            : AppColors.onSurfaceVariant; // Free
    final badge = planType == 1
        ? '热门'
        : planType == 2
            ? '超值'
            : '';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent : AppColors.outlineVariant,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: accent.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: -2,
                      offset: const Offset(0, 3))
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // 选中圈
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected ? accent : AppColors.outlineVariant,
                      width: 2),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: accent, shape: BoxShape.circle),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Text(name,
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface)),
              if (badge.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accent)),
                ),
              ],
              if (isCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('当前',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant)),
                ),
              ],
              const Spacer(),
              // 价格
              if (price > 0)
                Text('¥$price',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: accent))
              else
                Text('免费',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurfaceVariant)),
            ]),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(desc,
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4)),
              ),
            ],
            const SizedBox(height: 8),
            // 积分赠送
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (weekly > 0)
                    _GrantChip(
                        icon: Icons.date_range_rounded,
                        text: '每周 $weekly 积分'),
                  if (permanent > 0)
                    _GrantChip(
                        icon: Icons.all_inclusive_rounded,
                        text: '永久 $permanent 积分'),
                  if (duration != null && price > 0)
                    _GrantChip(
                        icon: Icons.calendar_month_rounded,
                        text: '$duration 天'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrantChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GrantChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.primary),
        const SizedBox(width: 3),
        Text(text,
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 11,
                color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}

// ── 积分赠送对比表 ────────────────────────────────────────
class _GrantTable extends StatelessWidget {
  final List<Map<String, dynamic>> plans;
  const _GrantTable({required this.plans});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 表头
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            color: AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('权益',
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurfaceVariant))),
                ...plans.map((p) => Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(p['name'] as String,
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onSurface)),
                      ),
                    )),
              ],
            ),
          ),
          _Row(
              label: '价格',
              values: plans
                  .map((p) => (p['price'] as num).toDouble() == 0
                      ? '免费'
                      : '¥${p['price']}')
                  .toList()),
          _Row(
              label: '周期',
              values: plans
                  .map((p) => (p['duration_days'] as int?) == null
                      ? '永久'
                      : '${p['duration_days']}天')
                  .toList()),
          _Row(
              label: '每周积分',
              highlight: true,
              values: plans
                  .map((p) => '${p['weekly_points_grant'] ?? 0}')
                  .toList()),
          _Row(
              label: '永久积分',
              highlight: true,
              values: plans
                  .map((p) => '${p['permanent_points_grant'] ?? 0}')
                  .toList(),
              isLast: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final List<String> values;
  final bool highlight;
  final bool isLast;
  const _Row({
    required this.label,
    required this.values,
    this.highlight = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                top: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: 0.4),
                    width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(label,
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 12,
                      color: AppColors.onSurface))),
          ...values.map((v) => Expanded(
                flex: 2,
                child: Center(
                  child: Text(v,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 11,
                          fontWeight:
                              highlight ? FontWeight.w800 : FontWeight.w500,
                          color: highlight
                              ? AppColors.primary
                              : AppColors.onSurface)),
                ),
              )),
        ],
      ),
    );
  }
}

// ── Mock 数据（对齐后端字段）──────────────────────────────
Map<String, dynamic> _mockPlans() {
  return {
    'list': [
      {
        'id': '1',
        'plan_type': 0,
        'name': 'Free',
        'price': 0,
        'duration_days': null,
        'weekly_points_grant': 70,
        'permanent_points_grant': 0,
        'description': '基础功能，适合体验',
      },
      {
        'id': '2',
        'plan_type': 1,
        'name': 'Pro',
        'price': 30,
        'duration_days': 30,
        'weekly_points_grant': 700,
        'permanent_points_grant': 100,
        'description': '更多积分额度，畅享 AI 分析',
      },
      {
        'id': '3',
        'plan_type': 2,
        'name': 'ProMax',
        'price': 98,
        'duration_days': 30,
        'weekly_points_grant': 2000,
        'permanent_points_grant': 300,
        'description': '最高积分额度 + 永久积分赠送',
      },
    ],
  };
}

Map<String, dynamic> _mockOrderResult() {
  return {
    'orderId': '1001',
    'planId': '2',
    'amount': 30,
    'status': 0, // 0=待支付
  };
}

/// mock 轮询订单状态：第 3 次轮询时返回已支付（模拟后台确认）
/// 后端接通后删除此方法，直接读接口返回的 status
int _mockPollStatus(String orderId, int attempt) {
  if (attempt >= 2) return 1; // 第 3 次轮询（attempt=2）模拟已支付
  return 0; // 待支付
}
