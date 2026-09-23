/// 每日签到页（月历视图 + 连续签到奖励 + 补签）
///
/// 后端接口（已对齐）：
///   GET  /sdkapi/checkin/calendar?month=YYYY-MM
///        → { month, calendar:[{date,day,status,streakCount,isMakeup}], currentStreak,
///            signedInToday, weeklyMakeupQuota, usedMakeupCount, remainingMakeupQuota,
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
///   makeup_available  — 可补签（2 天内缺签 + 配额未用尽）
///   missed            — 已错过，不可补签
library;

import 'package:flutter/material.dart';
import '../../shared/widgets/app_error_view.dart';
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
  Object? _loadError;
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
    setState(() => _loadError = null);
    try {
      final repo = ref.read(pointsRepositoryProvider);
      final month = _ym(DateTime.now());
      final data = await repo.fetchCalendar(month: month);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  Future<void> _refresh() => _loadCalendar();

  /// 执行签到 POST /sdkapi/checkin/signin
  Future<void> _doSignIn() async {
    final data = _data;
    if (data == null || _signing) return;
    if (_asBool(data['signedInToday'])) {
      PetToast.show(context, '今日已签到 ✅');
      return;
    }
    setState(() => _signing = true);
    HapticFeedback.mediumImpact();
    try {
      final result = await ref.read(pointsRepositoryProvider).signIn();
      if (!mounted) return;
      final alreadySigned = _asBool(result['alreadySigned']);
      final streakCount = _asInt(result['streakCount']);
      if (alreadySigned) {
        PetToast.show(context, '今日已签到 ✅');
      } else {
        PetToast.success(context, '签到成功！连续 $streakCount 天');
      }
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
    final ruleId = _asString(rule['id']);
    final claimable = _asBool(rule['claimable']);
    final claimed = _asBool(rule['claimed']);
    if (ruleId.isEmpty || !claimable || claimed || _claiming.contains(ruleId)) {
      return;
    }
    setState(() => _claiming.add(ruleId));
    HapticFeedback.mediumImpact();
    try {
      final result =
          await ref.read(pointsRepositoryProvider).claim(ruleId: ruleId);
      if (!mounted) return;
      final amount = _asInt(result['pointsAmount']);
      final pType = _asInt(result['pointsType']);
      PetToast.success(context, '已领取 +$amount ${pType == 2 ? '永久积分' : '积分'}');
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
    final remaining = _asInt(d['remainingMakeupQuota']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MakeupSheet(
        date: date,
        remaining: remaining,
        onMakeup: () => _doMakeup(date),
        onWatchAd: _showMakeupAdPlaceholder,
      ),
    );
  }

  void _showMakeupAdPlaceholder() {
    Navigator.pop(context);
    PetToast.show(context, '观看广告补签功能即将上线');
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
        PetToast.show(context, '本周补签配额已用完，看广告补签功能即将上线');
      } else {
        PetToast.error(context, e.message);
      }
    } catch (_) {
      if (mounted) PetToast.error(context, '补签失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('签到')),
        body: AppErrorView(error: _loadError, onRetry: _loadCalendar),
      );
    }

    final data = _data;
    final days = _mapList(data?['calendar']);
    final rules = _mapList(data?['rewardButtons']);
    final dailyRules = rules
        .where((rule) => _asInt(rule['ruleType']) == 1)
        .toList(growable: false);
    final dailyPoints =
        dailyRules.isEmpty ? 0 : _asInt(dailyRules.first['pointsAmount']);
    final streakRules = rules
        .where((rule) => _asInt(rule['ruleType']) == 2)
        .toList(growable: false);
    final currentStreak = _asInt(data?['currentStreak']);
    final signedInToday = _asBool(data?['signedInToday']);

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
            title: Text('签到',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            centerTitle: true,
          ),
          if (data == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else ...[
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // ── 月历（每一天都显示明确状态）──
                  _MonthCalendar(
                    month:
                        _asString(data['month'], fallback: _ym(DateTime.now())),
                    days: days,
                    dailyPoints: dailyPoints,
                    signedInToday: signedInToday,
                    signing: _signing,
                    onSignIn: _doSignIn,
                    onMakeup: _showMakeupSheet,
                  ),
                  const SizedBox(height: 16),
                  // 补签配额提示
                  _MakeupQuotaStrip(
                    remaining: _asInt(data['remainingMakeupQuota']),
                    total: data.containsKey('weeklyMakeupQuota')
                        ? _asInt(data['weeklyMakeupQuota'])
                        : _asInt(data['monthlyMakeupQuota']),
                  ),
                  const SizedBox(height: 20),
                  if (streakRules.isNotEmpty)
                    _RewardSection(
                      title: '连续签到奖励',
                      subtitle: '达到档位即可领取',
                      trailing: _StreakCountBadge(currentStreak: currentStreak),
                      rules: streakRules,
                      currentStreak: currentStreak,
                      signedInToday: signedInToday,
                      claiming: _claiming,
                      onClaim: _claimReward,
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

String _ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

List<Map<String, dynamic>> _mapList(dynamic value) =>
    (value as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);

int _asInt(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

bool _asBool(dynamic value) =>
    value == true || value == 1 || value == '1' || value == 'true';

String _asString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

// ── 月历（按后端 calendar 数组的 status 枚举渲染）──────────
class _MonthCalendar extends StatelessWidget {
  final String month; // 'YYYY-MM'
  final List<Map<String, dynamic>> days; // 后端返回的 calendar 数组
  final int dailyPoints;
  final bool signedInToday;
  final VoidCallback? onSignIn; // 点击今日（signable）直接签到
  final void Function(String date)? onMakeup; // 点击可补签日期
  final bool signing;
  const _MonthCalendar({
    required this.month,
    required this.days,
    required this.dailyPoints,
    required this.signedInToday,
    required this.signing,
    this.onSignIn,
    this.onMakeup,
  });

  @override
  Widget build(BuildContext context) {
    // 解析月份用于标题
    final parts = month.split('-');
    final title = parts.length == 2
        ? '${int.parse(parts[0])} 年 ${int.parse(parts[1])} 月'
        : month;

    // 按 date 字符串建索引，便于按真实日期渲染整月网格
    final byDate = <String, Map<String, dynamic>>{};
    for (final d in days) {
      final dateStr = d['date'] as String?;
      if (dateStr != null && dateStr.isNotEmpty) byDate[dateStr] = d;
    }

    // 算整月天数 + 月初星期对齐（用月份第一天真实算）
    final y = parts.length == 2 ? int.parse(parts[0]) : DateTime.now().year;
    final m = parts.length == 2 ? int.parse(parts[1]) : DateTime.now().month;
    final firstDayOfMonth = DateTime(y, m, 1);
    final daysInMonth = DateTime(y, m + 1, 0).day;
    // weekday: 周一=1..周日=7，转成 周日=0 起算
    final leadingSpaces = firstDayOfMonth.weekday % 7;

    String fmt(int day) =>
        '$y-${m.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

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
          const SizedBox(height: 1),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 0.74,
            ),
            // 整月网格：前导空格 + 本月所有天
            itemCount: leadingSpaces + daysInMonth,
            itemBuilder: (_, i) {
              if (i < leadingSpaces) return const SizedBox.shrink();
              final day = i - leadingSpaces + 1;
              final dateStr = fmt(day);
              final cell = byDate[dateStr];
              // 如果后端没返回该天（理论上不会），按“未来”兜底。
              final serverStatus = cell?['status'] as String? ?? 'future';
              final cellDate = DateTime(y, m, day);
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final daysAgo = today.difference(cellDate).inDays;
              final isToday = daysAgo == 0;
              final isUnsignedPastDay = serverStatus == 'makeup_available' ||
                  serverStatus == 'missed';
              final canMakeup =
                  isUnsignedPastDay && daysAgo >= 1 && daysAgo <= 2;
              final status = isToday && signedInToday
                  ? 'signed'
                  : canMakeup
                      ? 'makeup_available'
                      : serverStatus == 'makeup_available'
                          ? 'missed'
                          : serverStatus;
              return _CalendarCell(
                day: day,
                status: status,
                isMakeup: _asBool(cell?['isMakeup']),
                dailyPoints: dailyPoints,
                onTap: canMakeup
                    ? () => onMakeup?.call(dateStr)
                    : status == 'signable' && !signedInToday && !signing
                        ? onSignIn
                        : null,
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 5,
            children: const [
              _CalendarLegend(label: '已签', tone: _CalendarTone.signed),
              _CalendarLegend(label: '签到', tone: _CalendarTone.signable),
              _CalendarLegend(label: '补签', tone: _CalendarTone.makeup),
              _CalendarLegend(label: '漏签', tone: _CalendarTone.missed),
              _CalendarLegend(label: '未到', tone: _CalendarTone.future),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  final int day; // 真实日期（几号）
  final String status; // signed/signable/future/makeup_available/missed
  final bool isMakeup;
  final int dailyPoints;
  final VoidCallback? onTap;
  const _CalendarCell({
    required this.day,
    required this.status,
    required this.isMakeup,
    required this.dailyPoints,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _CalendarTone.fromStatus(status);
    final label = tone == _CalendarTone.signed && isMakeup ? '补签' : tone.label;
    final canTap = onTap != null;
    final showPoints = dailyPoints > 0 &&
        (tone == _CalendarTone.signable || tone == _CalendarTone.signed);

    return Semantics(
      button: canTap,
      label: '$day 日$label${showPoints ? '，+$dailyPoints 积分' : ''}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: tone.accent.withValues(alpha: 0.14),
          highlightColor: tone.accent.withValues(alpha: 0.07),
          child: Ink(
            decoration: BoxDecoration(
              color: tone.paper,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: tone.border, width: tone.borderWidth),
              boxShadow: canTap
                  ? [
                      BoxShadow(
                        color: tone.accent.withValues(alpha: 0.16),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 13,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tone.accent,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -2,
                  left: 8,
                  child: _CalendarBinder(color: tone.binder),
                ),
                Positioned(
                  top: -2,
                  right: 8,
                  child: _CalendarBinder(color: tone.binder),
                ),
                Positioned.fill(
                  top: 11,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: tone.foreground,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (showPoints)
                        Text(
                          '+$dailyPoints积分',
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 7.5,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: tone.accent,
                          ),
                        )
                      else if (tone == _CalendarTone.signed)
                        Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: tone.accent,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarBinder extends StatelessWidget {
  final Color color;
  const _CalendarBinder({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.7), width: 0.6),
      ),
    );
  }
}

enum _CalendarTone {
  signed,
  signable,
  makeup,
  missed,
  future;

  static _CalendarTone fromStatus(String status) {
    switch (status) {
      case 'signed':
        return signed;
      case 'signable':
        return signable;
      case 'makeup_available':
        return makeup;
      case 'missed':
        return missed;
      default:
        return future;
    }
  }

  String get label {
    switch (this) {
      case signed:
        return '已签';
      case signable:
        return '签到';
      case makeup:
        return '补签';
      case missed:
        return '漏签';
      case future:
        return '未到';
    }
  }

  Color get accent {
    switch (this) {
      case signed:
        return AppColors.statusOnline;
      case signable:
        return AppColors.brandPrimary;
      case makeup:
        return AppColors.brandPrimaryStrong;
      case missed:
        return AppColors.statusNeutral;
      case future:
        return AppColors.borderSubtle;
    }
  }

  Color get paper {
    switch (this) {
      case signed:
        return AppColors.statusOnlineSoft;
      case signable:
        return AppColors.brandPrimarySoft;
      case makeup:
        return AppColors.brandPrimarySoft;
      case missed:
      case future:
        return AppColors.surfaceSunken;
    }
  }

  Color get binder => this == missed || this == future
      ? AppColors.textTertiary
      : AppColors.textSecondary;

  Color get background => accent;

  Color get border => accent.withValues(alpha: 0.55);

  Color get foreground {
    switch (this) {
      case signed:
        return AppColors.statusOnlineStrong;
      case signable:
        return AppColors.brandPrimaryStrong;
      case makeup:
        return AppColors.brandPrimaryStrong;
      case missed:
      case future:
        return AppColors.statusNeutral;
    }
  }

  double get borderWidth => this == signable || this == makeup ? 1.2 : 0.8;
}

class _CalendarLegend extends StatelessWidget {
  final String label;
  final _CalendarTone tone;
  const _CalendarLegend({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: tone.border, width: 0.8),
          ),
        ),
        const SizedBox(width: 3),
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
          Icon(Icons.refresh_rounded, size: 16, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '本周补签配额：剩余 $remaining / $total 次',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant),
            ),
          ),
          if (remaining == 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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

// ── 奖励区（完全由服务端 rewardButtons 配置驱动）───────────
class _RewardSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<Map<String, dynamic>> rules;
  final int currentStreak;
  final bool signedInToday;
  final Set<String> claiming;
  final void Function(Map<String, dynamic> rule) onClaim;
  const _RewardSection({
    required this.title,
    required this.subtitle,
    required this.rules,
    required this.currentStreak,
    required this.signedInToday,
    required this.claiming,
    required this.onClaim,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 15,
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
              if (trailing != null) trailing!,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _RewardList(
            rules: rules,
            currentStreak: currentStreak,
            signedInToday: signedInToday,
            claiming: claiming,
            onClaim: onClaim,
          ),
        ),
      ],
    );
  }
}

class _StreakCountBadge extends StatelessWidget {
  final int currentStreak;
  const _StreakCountBadge({required this.currentStreak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 3),
          Text('已连签 $currentStreak 天',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _RewardList extends StatelessWidget {
  final List<Map<String, dynamic>> rules;
  final int currentStreak;
  final bool signedInToday;
  final Set<String> claiming;
  final void Function(Map<String, dynamic> rule) onClaim;
  const _RewardList({
    required this.rules,
    required this.currentStreak,
    required this.signedInToday,
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
            currentStreak: currentStreak,
            signedInToday: signedInToday,
            isClaiming: claiming.contains(_asString(entry.value['id'])),
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
  final int currentStreak;
  final bool signedInToday;
  final bool isClaiming;
  final VoidCallback onClaim;
  const _RewardRow({
    required this.rule,
    required this.isLast,
    required this.currentStreak,
    required this.signedInToday,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final ruleType = _asInt(rule['ruleType']); // 1=每日 2=连续
    final streakDays = _asInt(rule['streakDays']);
    final pointsAmount = _asInt(rule['pointsAmount']);
    final pointsType = _asInt(rule['pointsType']); // 1=周 2=永久
    final claimed = _asBool(rule['claimed']);
    final claimable = _asBool(rule['claimable']);
    final name =
        _asString(rule['name'], fallback: ruleType == 1 ? '每日签到' : '连续签到奖励');
    final remainingDays =
        streakDays > currentStreak ? streakDays - currentStreak : 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                top: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: 0.4),
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
            color: claimed ? AppColors.onSurfaceVariant : AppColors.primary,
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
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: pointsType == 2
                      ? AppColors.brandPrimarySoft
                      : AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('+$pointsAmount ${pointsType == 2 ? '永久' : '积分'}',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: pointsType == 2
                            ? AppColors.brandPrimaryStrong
                            : AppColors.onSurfaceVariant)),
              ),
            ],
          ),
        ),
        _RewardActionButton(
          ruleType: ruleType,
          remainingDays: remainingDays,
          signedInToday: signedInToday,
          claimed: claimed,
          claimable: claimable,
          isClaiming: isClaiming,
          onClaim: onClaim,
        ),
      ]),
    );
  }
}

class _RewardActionButton extends StatelessWidget {
  final int ruleType;
  final int remainingDays;
  final bool signedInToday;
  final bool claimed;
  final bool claimable;
  final bool isClaiming;
  final VoidCallback onClaim;
  const _RewardActionButton({
    required this.ruleType,
    required this.remainingDays,
    required this.signedInToday,
    required this.claimed,
    required this.claimable,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    if (claimed) {
      return SizedBox(
        width: 86,
        height: 32,
        child: OutlinedButton.icon(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            disabledForegroundColor: AppColors.onSurfaceVariant,
            side: BorderSide(color: AppColors.outlineVariant),
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.check_rounded, size: 14),
          label: Text('已领取',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      );
    }

    if (claimable) {
      return SizedBox(
        width: 86,
        height: 32,
        child: FilledButton(
          onPressed: isClaiming ? null : onClaim,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: isClaiming
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.6, color: Colors.white),
                )
              : Text('立即领取',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
        ),
      );
    }

    final label = ruleType == 1
        ? '签到后领取'
        : !signedInToday && remainingDays == 0
            ? '签到后领取'
            : remainingDays > 0
                ? '还差 $remainingDays 天'
                : '暂不可领取';
    return SizedBox(
      width: 86,
      height: 32,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          disabledForegroundColor:
              AppColors.onSurfaceVariant.withValues(alpha: 0.75),
          side: BorderSide(color: AppColors.outlineVariant),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── 补签面板 ─────────────────────────────────────────────
class _MakeupSheet extends StatelessWidget {
  final String date;
  final int remaining; // 会员剩余补签次数
  final VoidCallback onMakeup;
  final VoidCallback onWatchAd;
  const _MakeupSheet({
    required this.date,
    required this.remaining,
    required this.onMakeup,
    required this.onWatchAd,
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
            if (hasQuota)
              _MakeupOption(
                icon: Icons.workspace_premium_outlined,
                iconColor: AppColors.brandPrimaryStrong,
                title: '会员补签',
                subtitle: '使用 1 次配额，本周剩余 $remaining 次',
                enabled: true,
                onTap: onMakeup,
              )
            else
              _MakeupOption(
                icon: Icons.play_circle_outline_rounded,
                iconColor: AppColors.secondary,
                title: '观看广告补签',
                subtitle: '观看广告视频即可免费补签',
                enabled: true,
                onTap: onWatchAd,
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
