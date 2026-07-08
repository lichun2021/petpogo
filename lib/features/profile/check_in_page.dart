/// 每日签到页（月历视图 + 连续签到奖励 + 补签）
///
/// 后端接口（已对齐）：
///   GET  /sdkapi/checkin/calendar?month=YYYY-MM
///        → { month, calendar:[{date,day,status,streakCount,isMakeup}], currentStreak,
///            signedInToday, monthlyMakeupQuota, usedMakeupCount, remainingMakeupQuota,
///            rewardButtons:[{ruleType,streakDays,pointsAmount,pointsType,name,claimed,claimable}] }
///   POST /sdkapi/checkin/signin            → { checkinDate, streakCount }
///   POST /sdkapi/checkin/claim { ruleId }  → { success, pointsAmount, pointsType, balance }
///   POST /sdkapi/checkin/makeup { date }   → { success, date, streakCount, usedMakeupCount, remainingQuota }
///        错误 402 = 配额用尽（引导看广告）
///
/// day.status 枚举：
///   signed            — 已签到（含补签）
///   signable          — 今日未签，可签到
///   future            — 未来日期
///   makeup_available  — 可补签（3 天内缺签 + 配额未用尽）
///   missed            — 已错过，不可补签
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/pet_toast.dart';
import '../../core/api/api_exception.dart';
import 'data/points_repository.dart';

class CheckInPage extends ConsumerStatefulWidget {
  const CheckInPage({super.key});

  @override
  ConsumerState<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends ConsumerState<CheckInPage> {
  Map<String, dynamic>? _data; // /checkin/calendar 的返回；null = 加载中
  bool _signing = false;
  final Set<String> _claiming = {}; // ruleId → claiming

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  /// 拉取月历数据
  Future<void> _loadCalendar() async {
    try {
      final repo = ref.read(pointsRepositoryProvider);
      final month = _ym(DateTime.now());
      final data = await repo.fetchCalendar(month: month);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      // 接口失败时回退到 mock，避免页面空白（开发期）
      setState(() => _data = _mockCalendar());
      debugPrint('[签到] calendar 接口失败，回退 mock: $e');
    }
  }

  Future<void> _refresh() => _loadCalendar();

  /// 执行签到 POST /sdkapi/checkin/signin
  Future<void> _doSignIn() async {
    final d = _data;
    if (d == null) return;
    if ((d['signedInToday'] as bool) || _signing) return;
    setState(() => _signing = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(pointsRepositoryProvider).signIn();
      if (!mounted) return;
      PetToast.success(context, '签到成功');
      await _refresh();
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : '签到失败，请重试';
        PetToast.error(context, msg);
      }
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  /// 领取奖励 POST /sdkapi/checkin/claim { ruleId }
  Future<void> _claimReward(Map<String, dynamic> rule) async {
    final ruleId = rule['id'] as String;
    final claimable = rule['claimable'] as bool;
    final claimed = rule['claimed'] as bool;
    if (!claimable || claimed || _claiming.contains(ruleId)) return;
    setState(() => _claiming.add(ruleId));
    HapticFeedback.mediumImpact();
    try {
      final result =
          await ref.read(pointsRepositoryProvider).claim(ruleId: ruleId);
      if (!mounted) return;
      final amount = result['pointsAmount'] as int? ?? 0;
      final pType = result['pointsType'] as int? ?? 1;
      PetToast.success(context, '已领取 +$amount ${pType == 2 ? '永久' : '周'}积分');
      await _refresh();
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : '领取失败，请重试';
        PetToast.error(context, msg);
      }
    } finally {
      if (mounted) setState(() => _claiming.remove(ruleId));
    }
  }

  // ── 补签 ──
  void _showMakeupSheet(String date) {
    final d = _data;
    if (d == null) return;
    final remaining = d['remainingMakeupQuota'] as int? ?? 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MakeupSheet(
        date: date,
        remaining: remaining,
        onMakeup: () => _doMakeup(date),
      ),
    );
  }

  /// 补签 POST /sdkapi/checkin/makeup { date }
  /// 后端配额用尽返回 HTTP 402 → 引导看广告（广告播放暂不实现）
  Future<void> _doMakeup(String date) async {
    if (mounted) Navigator.pop(context); // 关闭面板
    HapticFeedback.mediumImpact();
    try {
      await ref.read(pointsRepositoryProvider).makeup(date: date);
      if (!mounted) return;
      PetToast.success(context, '补签成功');
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      // 402 = 配额用尽 → 引导看广告
      if (e.statusCode == 402) {
        PetToast.show(context, '本月补签配额已用完，看广告补签功能即将上线');
      } else {
        PetToast.error(context, e.message);
      }
    } catch (_) {
      if (mounted) PetToast.error(context, '补签失败，请重试');
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
            title: Text('每日签到',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            centerTitle: true,
          ),
          if (_data == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child:
                  Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else ...[
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _SignInHeader(
                    signedInToday: _data!['signedInToday'] as bool? ?? false,
                    currentStreak: _data!['currentStreak'] as int? ?? 0,
                    signing: _signing,
                    onSignIn: _doSignIn,
                  ),
                  const SizedBox(height: 16),
                  _MonthCalendar(
                    month: (_data!['month'] as String?) ?? _ym(DateTime.now()),
                    days: ((_data!['calendar'] as List?) ?? const [])
                        .whereType<Map>()
                        .map((e) => e.cast<String, dynamic>())
                        .toList(),
                    onMakeup: _showMakeupSheet,
                  ),
                  const SizedBox(height: 20),
                  // 补签配额提示
                  _MakeupQuotaStrip(
                    remaining:
                        _data!['remainingMakeupQuota'] as int? ?? 0,
                    total: _data!['monthlyMakeupQuota'] as int? ?? 0,
                  ),
                  const SizedBox(height: 20),
                  // ── 连续签到奖励 ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(children: [
                      Text('连续签到奖励',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface)),
                      const SizedBox(width: 6),
                      Text('（达成即可领取）',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _RewardList(
                      rules: ((_data!['rewardButtons'] as List?) ??
                              const [])
                          .whereType<Map>()
                          .map((e) => e.cast<String, dynamic>())
                          .toList(),
                      claiming: _claiming,
                      onClaim: _claimReward,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _ym(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

// ── 顶部签到卡 ───────────────────────────────────────────
class _SignInHeader extends StatelessWidget {
  final bool signedInToday;
  final int currentStreak;
  final bool signing;
  final VoidCallback onSignIn;
  const _SignInHeader({
    required this.signedInToday,
    required this.currentStreak,
    required this.signing,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department_rounded,
                  color: Colors.white, size: 30),
              const SizedBox(width: 8),
              Text('$currentStreak',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('天连续签到',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9))),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: signedInToday || signing ? null : onSignIn,
              style: FilledButton.styleFrom(
                backgroundColor:
                    signedInToday ? Colors.white.withValues(alpha: 0.2) : Colors.white,
                foregroundColor: AppColors.primary,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: signing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      signedInToday
                          ? Icons.check_circle_rounded
                          : Icons.edit_calendar_rounded,
                      size: 20),
              label: Text(
                signedInToday ? '今日已签到' : signing ? '签到中...' : '立即签到',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 月历（按后端 calendar 数组的 status 枚举渲染）──────────
class _MonthCalendar extends StatelessWidget {
  final String month; // 'YYYY-MM'
  final List<Map<String, dynamic>> days; // 后端返回的 calendar 数组
  final void Function(String date)? onMakeup;
  const _MonthCalendar({required this.month, required this.days, this.onMakeup});

  @override
  Widget build(BuildContext context) {
    // 解析月份用于标题
    final parts = month.split('-');
    final title = parts.length == 2
        ? '${int.parse(parts[0])} 年 ${int.parse(parts[1])} 月'
        : month;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          const SizedBox(height: 12),
          Row(
            children: ['日', '一', '二', '三', '四', '五', '六']
                .map((w) => Expanded(
                      child: Center(
                          child: Text(w,
                              style: TextStyle(
                                  fontFamily: AppFonts.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurfaceVariant))),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 0,
              childAspectRatio: 1,
            ),
            // 后端只返回本月有意义的日期；我们按 days 数组直接渲染
            // 用 padding 对齐星期几（days[0] 的 weekday 决定前面留几个空格）
            itemCount: _leadingSpaces() + days.length,
            itemBuilder: (_, i) {
              if (i < _leadingSpaces()) return const SizedBox.shrink();
              final cell = days[i - _leadingSpaces()];
              return _CalendarCell(
                cell: cell,
                onTap: cell['status'] == 'makeup_available'
                    ? () => onMakeup?.call(cell['date'] as String)
                    : null,
              );
            },
          ),
          const SizedBox(height: 8),
          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(dotColor: AppColors.primary, label: '已签到', filled: true),
              const SizedBox(width: 12),
              _Legend(dotColor: AppColors.primary, label: '今天', outlined: true),
              const SizedBox(width: 12),
              _Legend(dotColor: AppColors.secondary, label: '可补签', dashed: true),
            ],
          ),
        ],
      ),
    );
  }

  /// 计算月初前几天是空格（根据 days[0] 的日期是星期几）
  int _leadingSpaces() {
    if (days.isEmpty) return 0;
    final first = days.first;
    final day = first['day'] as int;
    // 拿 month + day 算 weekday
    final parts = month.split('-');
    if (parts.length != 2) return 0;
    final firstDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), day);
    return firstDate.weekday % 7; // 周日=0
  }
}

class _CalendarCell extends StatelessWidget {
  final Map<String, dynamic> cell;
  final VoidCallback? onTap;
  const _CalendarCell({required this.cell, this.onTap});

  @override
  Widget build(BuildContext context) {
    final day = cell['day'] as int;
    final status = cell['status'] as String;
    switch (status) {
      case 'signed':
        return _circle(
          color: AppColors.primary,
          filled: true,
          child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
        );
      case 'signable':
        return _circle(
          color: AppColors.primary,
          outlined: true,
          child: Text('$day',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        );
      case 'makeup_available':
        return GestureDetector(
          onTap: onTap,
          child: DottedBorder(
            color: AppColors.secondary,
            diameter: 32,
            child: Text('$day',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary)),
          ),
        );
      case 'missed':
        return Center(
          child: Text('$day',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                  decoration: TextDecoration.lineThrough)),
        );
      case 'future':
        return Center(
          child: Text('$day',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5))),
        );
      default:
        return Center(
            child: Text('$day',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 13,
                    color: AppColors.onSurface)));
    }
  }

  Widget _circle(
      {required Color color,
      bool filled = false,
      bool outlined = false,
      Widget? child}) {
    return Center(
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: filled ? color : null,
          shape: BoxShape.circle,
          border: outlined ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// 虚线圆（可补签标记）
class DottedBorder extends StatelessWidget {
  final Color color;
  final double diameter;
  final Widget child;
  const DottedBorder({
    required this.color,
    required this.diameter,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        painter: _DottedCirclePainter(color: color, diameter: diameter),
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  final Color color;
  final double diameter;
  _DottedCirclePainter({required this.color, required this.diameter});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashCount = 16;
    final radius = diameter / 2;
    final center = Offset(radius, radius);
    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i / dashCount) * 2 * 3.14159265;
      final endAngle = startAngle + (3.14159265 / dashCount) * 0.6;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 0.5),
        startAngle,
        endAngle - startAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DottedCirclePainter _) => false;
}

class _Legend extends StatelessWidget {
  final Color dotColor;
  final String label;
  final bool filled;
  final bool outlined;
  final bool dashed;
  const _Legend({
    required this.dotColor,
    required this.label,
    this.filled = false,
    this.outlined = false,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          DottedBorder(
            color: dotColor,
            diameter: 12,
            child: const SizedBox.shrink(),
          )
        else
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: filled ? dotColor : null,
              shape: BoxShape.circle,
              border: outlined ? Border.all(color: dotColor, width: 1.5) : null,
            ),
          ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 10,
                color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}

// ── 补签配额提示条 ───────────────────────────────────────
class _MakeupQuotaStrip extends StatelessWidget {
  final int remaining;
  final int total;
  const _MakeupQuotaStrip({required this.remaining, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.refresh_rounded,
              size: 16, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '本月补签配额：剩余 $remaining / $total 次',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant),
            ),
          ),
          if (remaining == 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('看广告补签',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary)),
            ),
        ]),
      ),
    );
  }
}

// ── 连续奖励列表 ─────────────────────────────────────────
class _RewardList extends StatelessWidget {
  final List<Map<String, dynamic>> rules;
  final Set<String> claiming;
  final void Function(Map<String, dynamic> rule) onClaim;
  const _RewardList({
    required this.rules,
    required this.claiming,
    required this.onClaim,
  });

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
        children: rules.asMap().entries.map((entry) {
          final i = entry.key;
          return _RewardRow(
            rule: entry.value,
            isLast: i == rules.length - 1,
            isClaiming: claiming.contains(entry.value['id'] as String),
            onClaim: () => onClaim(entry.value),
          );
        }).toList(),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final Map<String, dynamic> rule;
  final bool isLast;
  final bool isClaiming;
  final VoidCallback onClaim;
  const _RewardRow({
    required this.rule,
    required this.isLast,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final ruleType = rule['ruleType'] as int; // 1=每日 2=连续
    final pointsAmount = rule['pointsAmount'] as int;
    final pointsType = rule['pointsType'] as int; // 1=周 2=永久
    final claimed = rule['claimed'] as bool;
    final claimable = rule['claimable'] as bool;
    final name = rule['name'] as String;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                top: BorderSide(
                    color: AppColors.outlineVariant
                        .withValues(alpha: 0.4),
                    width: 0.5)),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (claimed ? AppColors.onSurfaceVariant : AppColors.primary)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            claimed
                ? Icons.check_circle_rounded
                : ruleType == 1
                    ? Icons.calendar_today_rounded
                    : Icons.emoji_events_rounded,
            size: 18,
            color: claimed
                ? AppColors.onSurfaceVariant
                : AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface)),
              const SizedBox(height: 3),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: pointsType == 2
                      ? const Color(0xFFB8860B).withValues(alpha: 0.12)
                      : AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('+$pointsAmount ${pointsType == 2 ? '永久' : '周'}',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: pointsType == 2
                            ? const Color(0xFFB8860B)
                            : AppColors.onSurfaceVariant)),
              ),
            ],
          ),
        ),
        if (claimed)
          Text('已领取',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant))
        else if (claimable)
          SizedBox(
            width: 64,
            height: 30,
            child: FilledButton(
              onPressed: isClaiming ? null : onClaim,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.5),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: isClaiming
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Colors.white))
                  : Text('领取',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
            ),
          )
        else
          Text('未达成',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant)),
      ]),
    );
  }
}

// ── 补签面板 ─────────────────────────────────────────────
class _MakeupSheet extends StatelessWidget {
  final String date;
  final int remaining; // 会员剩余补签次数
  final VoidCallback onMakeup;
  const _MakeupSheet({
    required this.date,
    required this.remaining,
    required this.onMakeup,
  });

  String get _dateLabel {
    try {
      final d = DateTime.parse(date);
      return '${d.month}月${d.day}日';
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    final hasQuota = remaining > 0;

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
            Text('补签 $_dateLabel',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface)),
            const SizedBox(height: 4),
            Text('补签后该日计入连续签到天数',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 18),
            // 会员补签
            _MakeupOption(
              icon: Icons.workspace_premium_rounded,
              iconColor: const Color(0xFFB8860B),
              title: '会员补签',
              subtitle:
                  hasQuota ? '本月剩余 $remaining 次' : '本月配额已用完',
              enabled: hasQuota,
              onTap: hasQuota ? onMakeup : null,
            ),
            const SizedBox(height: 10),
            // 看广告补签（配额用完才显示）
            if (!hasQuota)
              _MakeupOption(
                icon: Icons.play_circle_outline_rounded,
                iconColor: AppColors.secondary,
                title: '看视频补签',
                subtitle: '观看广告视频即可免费补签',
                enabled: true,
                onTap: onMakeup, // TODO: 接广告 SDK
              ),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                  side: BorderSide(color: AppColors.outlineVariant),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('取消',
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

class _MakeupOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;
  const _MakeupOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? iconColor.withValues(alpha: 0.3)
                  : AppColors.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

// ── Mock 数据（对齐后端 calendar 接口字段）────────────────
Map<String, dynamic> _mockCalendar() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monthStr = _ym(now);
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final calendar = <Map<String, dynamic>>[];
  for (var day = 1; day <= now.day; day++) {
    final date = DateTime(now.year, now.month, day);
    final diff = today.difference(date).inDays;
    final isToday = diff == 0;
    final signed = day == 1 ||
        day == 4 ||
        day == 5 ||
        day == 6 ||
        day == 7; // mock 已签日期
    if (isToday) {
      calendar.add({
        'date': fmt(date),
        'day': day,
        'status': 'signable',
        'streakCount': null,
        'isMakeup': false,
      });
    } else if (signed) {
      calendar.add({
        'date': fmt(date),
        'day': day,
        'status': 'signed',
        'streakCount': 1,
        'isMakeup': false,
      });
    } else if (diff >= 1 && diff <= 3) {
      calendar.add({
        'date': fmt(date),
        'day': day,
        'status': 'makeup_available',
        'streakCount': null,
        'isMakeup': false,
      });
    } else {
      calendar.add({
        'date': fmt(date),
        'day': day,
        'status': 'missed',
        'streakCount': null,
        'isMakeup': false,
      });
    }
  }

  return {
    'month': monthStr,
    'calendar': calendar,
    'currentStreak': 3,
    'signedInToday': false,
    'monthlyMakeupQuota': 3,
    'usedMakeupCount': 1,
    'remainingMakeupQuota': 2,
    'rewardButtons': [
      {
        'id': '1',
        'ruleType': 1,
        'streakDays': 1,
        'pointsAmount': 2,
        'pointsType': 2,
        'name': '每日签到',
        'claimed': false,
        'claimable': true,
      },
      {
        'id': '2',
        'ruleType': 2,
        'streakDays': 3,
        'pointsAmount': 10,
        'pointsType': 2,
        'name': '连续 3 天',
        'claimed': false,
        'claimable': true,
      },
      {
        'id': '3',
        'ruleType': 2,
        'streakDays': 5,
        'pointsAmount': 30,
        'pointsType': 2,
        'name': '连续 5 天',
        'claimed': false,
        'claimable': false,
      },
      {
        'id': '4',
        'ruleType': 2,
        'streakDays': 7,
        'pointsAmount': 100,
        'pointsType': 2,
        'name': '连续 7 天',
        'claimed': false,
        'claimable': false,
      },
      {
        'id': '5',
        'ruleType': 2,
        'streakDays': 15,
        'pointsAmount': 200,
        'pointsType': 2,
        'name': '连续 15 天',
        'claimed': false,
        'claimable': false,
      },
      {
        'id': '6',
        'ruleType': 2,
        'streakDays': 30,
        'pointsAmount': 500,
        'pointsType': 2,
        'name': '连续 30 天',
        'claimed': false,
        'claimable': false,
      },
    ],
  };
}

Map<String, dynamic> _mockClaimResult() {
  return {
    'success': true,
    'pointsAmount': 10,
    'pointsType': 2,
    'balance': {'weekly': 65, 'permanent': 110, 'total': 175},
  };
}
