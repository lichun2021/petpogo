import 'package:flutter/material.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import '../pet/fence_manage_page.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

// ── 安全设置页 ───────────────────────────────────────────
// 展示安全评分与两步设置（位置围栏 + 警报通知）
class SafetyScenePage extends StatefulWidget {
  final String deviceMac;
  final String deviceName;
  final String petName;      // 绑定宠物名称（用于围栏页标题）

  SafetyScenePage({
    super.key,
    required this.deviceMac,
    required this.deviceName,
    this.petName = '',
  });

  @override
  State<SafetyScenePage> createState() => _SafetyScenePageState();
}

class _SafetyScenePageState extends State<SafetyScenePage> {
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
        title: Text('安全设置',
            style: TextStyle(fontFamily: AppFonts.primary,
                fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: _SafetySettingsContent(
        deviceMac: widget.deviceMac,
        petName: widget.petName,
      ),
    );
  }
}

// ── 安全设置内容（单一场景，无 Tab）────────────────────────
class _SafetySettingsContent extends StatelessWidget {
  final String deviceMac;
  final String petName;

  const _SafetySettingsContent({
    required this.deviceMac,
    this.petName = '',
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // 安全评分卡
        _SafetyScoreCard(score: 0),
        SizedBox(height: 24),

        // 设置步骤标题
        Text('设置步骤',
            style: TextStyle(fontFamily: AppFonts.primary,
                fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        SizedBox(height: 4),
        Text('完成所有步骤以激活安全保护',
            style: TextStyle(fontFamily: AppFonts.primary,
                fontSize: 12, color: AppColors.onSurfaceVariant)),
        SizedBox(height: 16),

        // 白色步骤容器
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
            ),
            child: Column(children: [
              // ① 位置与围栏
              _StepItem(
                icon: Icons.radar_rounded,
                iconBg: AppColors.primary,
                title: '位置信息与电子围栏',
                subtitle: '定义宠物的安全活动范围',
                score: '+60分',
                done: false,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => FenceManagePage(
                    deviceMac: deviceMac,
                    petName: petName,
                  ))),
              ),
              const _StepDivider(),

              // ② 警报通知
              _StepItem(
                icon: Icons.notifications_rounded,
                iconBg: AppColors.brandPrimary,
                title: '设置警报通知',
                subtitle: '配置宠物离开安全区域的规则与提醒方式',
                score: '+40分',
                done: false,
                onTap: () => PetToast.warning(context, '警报通知即将上线'),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── 安全评分卡 ────────────────────────────────────────────
class _SafetyScoreCard extends StatelessWidget {
  final int score;
  const _SafetyScoreCard({required this.score});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: Offset(0, 3))],
    ),
    child: Row(children: [
      // 左：标题 + 安全指数
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.shield_rounded, size: 16,
              color: score == 0 ? AppColors.statusAlert : AppColors.statusOnline),
          SizedBox(width: 6),
          Text('当前安全评分',
              style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        ]),
        SizedBox(height: 6),
        Text(
          '安全指数：${score == 0 ? '低' : score < 60 ? '中' : '高'}',
          style: TextStyle(
            fontFamily: AppFonts.primary, fontSize: 12, fontWeight: FontWeight.w600,
            color: score == 0 ? AppColors.statusAlert : score < 60 ? AppColors.brandPrimary : AppColors.statusOnline,
          ),
        ),
      ])),
      // 右：圆形分数
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: score == 0
                  ? AppColors.statusAlertSoft
                  : AppColors.statusOnlineSoft,
              width: 2.5),
        ),
        child: Center(
          child: Text('$score',
              style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: score == 0 ? AppColors.statusAlert : AppColors.statusOnline)),
        ),
      ),
    ]),
  );
}

// ── 步骤分割线 ─────────────────────────────────────────────
class _StepDivider extends StatelessWidget {
  const _StepDivider();
  @override
  Widget build(BuildContext context) => Padding(
    // 16(card padding) + 42(icon) + 14(gap) = 72
    padding: const EdgeInsets.only(left: 72),
    child: const Divider(height: 1),
  );
}

// ── 设置步骤项 ─────────────────────────────────────────────
class _StepItem extends StatelessWidget {
  final IconData   icon;
  final Color      iconBg;
  final String     title, subtitle, score;
  final bool       done, comingSoon;
  final VoidCallback onTap;

  const _StepItem({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.onTap,
    this.done       = false,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      // 横向 16px padding，确保不出框
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(children: [
        // 图标
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: comingSoon
                ? Colors.grey.withOpacity(0.1)
                : iconBg.withOpacity(0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20,
              color: comingSoon ? Colors.grey.shade400 : iconBg),
        ),
        SizedBox(width: 14),

        // 文字
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: comingSoon ? AppColors.onSurfaceVariant : AppColors.onSurface)),
          SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 11, color: AppColors.onSurfaceVariant)),
        ])),
        SizedBox(width: 8),

        // 分数 / 即将上线 / 完成状态
        if (done)
          Icon(Icons.check_circle_outline_rounded, size: 20, color: AppColors.statusOnline)
        else if (comingSoon)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('即将上线',
                style: TextStyle(fontFamily: AppFonts.primary,
                    fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)),
          )
        else if (score.isNotEmpty)
          Text(score,
              style: TextStyle(fontFamily: AppFonts.primary,
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary))
        ,
        if (!done && !comingSoon)
          SizedBox(width: 2),
        if (!done && !comingSoon)
          Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.onSurfaceVariant),
      ]),
    ),
  );
}
