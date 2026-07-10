/// 购买计划页（Free / Pro / ProMax）
///
/// 后端接口（已对齐）：
///   GET  /sdkapi/plan/list → { list: [{ id, plan_type, name, price_monthly,
///          price_yearly, grant_period_days, period_grant_amount,
///          period_grant_type_code, weekly_makeup_quota, description }] }
///   POST /sdkapi/plan/order { planId, period } → { orderId, planId, period, amount, status }
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
  String _billingPeriod = 'monthly';
  bool _ordering = false;
  bool _disposed = false;
  String _orderStatusText = ''; // 订单轮询时的提示文案

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  int _priceCents(Map<String, dynamic> plan, String period) {
    final value = plan[period == 'yearly' ? 'price_yearly' : 'price_monthly'];
    final amount =
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return (amount * 100).round();
  }

  String _formatMoney(int cents) {
    if (cents % 100 == 0) return (cents ~/ 100).toString();
    return (cents / 100).toStringAsFixed(2);
  }

  int _planType(Map<String, dynamic> plan) => _asInt(plan['plan_type']);

  String _planId(Map<String, dynamic> plan) => plan['id']?.toString() ?? '';

  bool _isCurrentPlan(Map<String, dynamic> plan) {
    final level = ref.read(authControllerProvider).user?.vipLevel;
    final currentType = level == 'pro_max'
        ? 2
        : level == 'pro'
            ? 1
            : 0;
    return _planType(plan) == currentType;
  }

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
        (p) => _planType(p) == 1,
        orElse: () => _plans.isEmpty ? <String, dynamic>{} : _plans.first,
      );
      if (pro.isNotEmpty) {
        setState(() => _selectedPlanId = _planId(pro));
      }
    } catch (e) {
      if (!mounted) return;
      // 回退 mock
      setState(() {
        _plans = _mockPlans()['list'].cast<Map<String, dynamic>>();
        _plansLoading = false;
        final pro = _plans.firstWhere((p) => _planType(p) == 1,
            orElse: () => _plans.first);
        _selectedPlanId = _planId(pro);
      });

      debugPrint('[会员] plan/list 失败，回退 mock: $e');
    }
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: _BillingPeriodSelector(
                          period: _billingPeriod,
                          onChanged: (period) =>
                              setState(() => _billingPeriod = period),
                        ),
                      ),
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
                              period: _billingPeriod,
                              selected: _selectedPlanId == _planId(p),
                              isCurrent: _isCurrentPlan(p),
                              onTap: () =>
                                  setState(() => _selectedPlanId = _planId(p)),
                            ),
                          )),
                      const SizedBox(height: 20),
                      // ── 积分赠送对比 ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text('计划详情',
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onSurface)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _GrantTable(
                          plans: _plans,
                          period: _billingPeriod,
                        ),
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
                                'Free 计划赠送积分 7 天有效；Pro 与 ProMax 计划赠送积分永久有效。\n积分按计划周期自动发放，订单提交后需后台确认支付后生效。',
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
    final planType = _planType(selected);
    final priceCents = _priceCents(selected, _billingPeriod);
    final isCurrent = _isCurrentPlan(selected);
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
                  Text('¥${_formatMoney(priceCents)}',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary)),
                  Text(_billingPeriod == 'yearly' ? '年付' : '月付',
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
                  onPressed:
                      (isCurrent || isFree || _ordering) ? null : _onOrder,
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
      final selectedPeriod = _billingPeriod;
      final order = await ref.read(pointsRepositoryProvider).createOrder(
            planId: planId,
            period: selectedPeriod,
          );
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

class _BillingPeriodSelector extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;
  const _BillingPeriodSelector({
    required this.period,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _BillingPeriodOption(
            label: '月付',
            selected: period == 'monthly',
            onTap: () => onChanged('monthly'),
          ),
          _BillingPeriodOption(
            label: '年付',
            badge: '更优惠',
            selected: period == 'yearly',
            onTap: () => onChanged('yearly'),
          ),
        ],
      ),
    );
  }
}

class _BillingPeriodOption extends StatelessWidget {
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;
  const _BillingPeriodOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant)),
                if (badge != null) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8860B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(badge!,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB8860B))),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 套餐卡片 ──────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool selected;
  final bool isCurrent;
  final String period;
  final VoidCallback onTap;
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.isCurrent,
    required this.period,
    required this.onTap,
  });

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  int _priceCents(String key) {
    final value = plan[key];
    final amount =
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return (amount * 100).round();
  }

  String _money(int cents) {
    if (cents % 100 == 0) return (cents ~/ 100).toString();
    return (cents / 100).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final planType = _asInt(plan['plan_type']);
    final name = plan['name']?.toString() ?? '';
    final monthlyCents = _priceCents('price_monthly');
    final yearlyCents = _priceCents('price_yearly');
    final priceCents = period == 'yearly' ? yearlyCents : monthlyCents;
    final grantPeriod = _asInt(plan['grant_period_days']);
    final grantAmount = _asInt(plan['period_grant_amount']);
    final makeupQuota = _asInt(plan['weekly_makeup_quota']);
    final grantType = plan['period_grant_type_code']?.toString() ?? '';
    final desc = plan['description']?.toString() ?? '';
    final pointsValidity = planType == 0 ? '赠送积分 7 天有效' : '赠送积分永久有效';
    final yearlySaving = monthlyCents * 12 - yearlyCents;
    final isYearly = period == 'yearly' && priceCents > 0;

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
              if (priceCents > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('¥${_money(priceCents)}/${isYearly ? '年' : '月'}',
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: accent)),
                    if (isYearly) ...[
                      const SizedBox(height: 2),
                      Text('折合 ¥${_money((yearlyCents / 12).round())}/月',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant)),
                    ],
                  ],
                )
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
                  if (grantAmount > 0) ...[
                    _GrantChip(
                      icon: grantType == 'permanent'
                          ? Icons.all_inclusive_rounded
                          : Icons.card_giftcard_rounded,
                      text: '每 $grantPeriod 天赠送 $grantAmount 积分',
                    ),
                    _GrantChip(
                      icon: planType == 0
                          ? Icons.schedule_rounded
                          : Icons.all_inclusive_rounded,
                      text: pointsValidity,
                    ),
                  ],
                  if (makeupQuota > 0)
                    _GrantChip(
                      icon: Icons.history_rounded,
                      text: '每周可补签 $makeupQuota 次',
                    ),
                  if (isYearly && yearlySaving > 0)
                    _GrantChip(
                      icon: Icons.savings_rounded,
                      text: '年付省 ¥${_money(yearlySaving)}',
                    ),
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
  final String period;
  const _GrantTable({required this.plans, required this.period});

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  int _priceCents(Map<String, dynamic> plan) {
    final value = plan[period == 'yearly' ? 'price_yearly' : 'price_monthly'];
    final amount =
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return (amount * 100).round();
  }

  String _money(int cents) {
    if (cents % 100 == 0) return (cents ~/ 100).toString();
    return (cents / 100).toStringAsFixed(2);
  }

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
              values: plans.map((p) {
                final cents = _priceCents(p);
                return cents == 0
                    ? '免费'
                    : '¥${_money(cents)}/${period == 'yearly' ? '年' : '月'}';
              }).toList()),
          _Row(
              label: '积分周期',
              values: plans
                  .map((p) => '每${_asInt(p['grant_period_days'])}天')
                  .toList()),
          _Row(
              label: '赠送积分',
              highlight: true,
              values: plans
                  .map((p) => '${_asInt(p['period_grant_amount'])}')
                  .toList()),
          _Row(
              label: '积分有效期',
              highlight: true,
              values: plans
                  .map((p) => _asInt(p['plan_type']) == 0 ? '7天' : '永久')
                  .toList()),
          _Row(
              label: '每周补签',
              highlight: true,
              values: plans
                  .map((p) => '${_asInt(p['weekly_makeup_quota'])}次')
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
        'price_monthly': 0,
        'price_yearly': 0,
        'duration_days': null,
        'grant_period_days': 7,
        'period_grant_amount': 70,
        'period_grant_type_code': 'plan_free',
        'weekly_makeup_quota': 1,
        'description': '基础功能，适合体验',
      },
      {
        'id': '2',
        'plan_type': 1,
        'name': 'Pro',
        'price_monthly': 30,
        'price_yearly': 299,
        'duration_days': 30,
        'grant_period_days': 30,
        'period_grant_amount': 700,
        'period_grant_type_code': 'plan_pro',
        'weekly_makeup_quota': 3,
        'description': '更多积分额度，畅享 AI 分析',
      },
      {
        'id': '3',
        'plan_type': 2,
        'name': 'ProMax',
        'price_monthly': 98,
        'price_yearly': 899,
        'duration_days': 30,
        'grant_period_days': 30,
        'period_grant_amount': 2000,
        'period_grant_type_code': 'plan_promax',
        'weekly_makeup_quota': 5,
        'description': '最高积分额度 + 永久积分赠送',
      },
    ],
  };
}
