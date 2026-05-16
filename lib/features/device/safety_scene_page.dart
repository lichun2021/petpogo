import 'package:flutter/material.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_toast.dart';
import '../pet/fence_manage_page.dart';

// ── 安全场景设置页 ─────────────────────────────────────────
// 居家场景 / 外出场景 Tab 切换，展示安全设置步骤
class SafetyScenePage extends StatefulWidget {
  final String deviceMac;
  final String deviceName;
  final int    initialTab; // 0=居家 1=外出

  const SafetyScenePage({
    super.key,
    required this.deviceMac,
    required this.deviceName,
    this.initialTab = 0,
  });

  @override
  State<SafetyScenePage> createState() => _SafetyScenePageState();
}

class _SafetyScenePageState extends State<SafetyScenePage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('安全场景设置',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: false,
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          labelStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans',
              fontSize: 13, fontWeight: FontWeight.w600),
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: '居家场景'),
            Tab(text: '外出场景'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _SceneContent(
            key: const ValueKey('home'),
            deviceMac:  widget.deviceMac,
            scene:      _SceneType.home,
          ),
          _SceneContent(
            key: const ValueKey('outing'),
            deviceMac:  widget.deviceMac,
            scene:      _SceneType.outing,
          ),
        ],
      ),
    );
  }
}

enum _SceneType { home, outing }

// ── 场景内容页 ────────────────────────────────────────────
class _SceneContent extends StatelessWidget {
  final String     deviceMac;
  final _SceneType scene;

  const _SceneContent({super.key, required this.deviceMac, required this.scene});

  bool get _isHome => scene == _SceneType.home;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // 安全评分卡
        _SafetyScoreCard(score: 0),
        const SizedBox(height: 24),

        // 设置步骤标题
        const Text('设置步骤',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 4),
        const Text('完成所有步骤以激活安全保护',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 12, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),

        // 步骤列表
        _StepItem(
          icon: Icons.fence_rounded,
          iconBg: AppColors.primary,
          title: '位置信息与电子围栏',
          subtitle: '定义宠物的安全活动范围',
          score: '+30分',
          done: false,
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => FenceManagePage(deviceMac: deviceMac, petName: ''),
          )),
        ),
        const _StepDivider(),

        if (_isHome) ...[
          _StepItem(
            icon: Icons.wifi_rounded,
            iconBg: const Color(0xFF2196F3),
            title: '受信任 Wi-Fi',
            subtitle: '添加家中的 Wi-Fi 网络，配合电子围栏使用',
            score: '+30分',
            done: false,
            onTap: () => PetToast.warning(context, '受信任 Wi-Fi 即将上线'),
          ),
          const _StepDivider(),
        ],

        _StepItem(
          icon: Icons.notifications_rounded,
          iconBg: const Color(0xFFFF9800),
          title: '设置警报通知',
          subtitle: '配置宠物离开安全区域的规则与提醒方式',
          score: '+40分',
          done: false,
          onTap: () => PetToast.warning(context, '警报通知即将上线'),
        ),
        const _StepDivider(),

        if (!_isHome) ...[
          _StepItem(
            icon: Icons.directions_walk_rounded,
            iconBg: const Color(0xFF4CAF50),
            title: '运动轨迹记录',
            subtitle: '外出时自动记录宠物的活动路径',
            score: '+20分',
            done: false,
            comingSoon: true,
            onTap: () => PetToast.warning(context, '运动轨迹即将上线'),
          ),
          const _StepDivider(),
        ],

        _StepItem(
          icon: Icons.bluetooth_rounded,
          iconBg: const Color(0xFF9C27B0),
          title: '添加蓝牙信标',
          subtitle: '绑定信标能更精确地定位您的电子围栏',
          score: '',
          done: false,
          comingSoon: true,
          onTap: () => PetToast.warning(context, '蓝牙信标即将上线'),
        ),

        const SizedBox(height: 20),

        // 全提示
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withOpacity(0.12)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(
              _isHome
                  ? '子围栏与受信任 Wi-Fi 结合使用时，能更准确地判断宠物是否在家中安全区域。'
                  : '外出场景建议开启电子围栏和运动轨迹记录，方便实时掌握宠物位置。',
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.5),
            )),
          ]),
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
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('当前安全评分',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        const SizedBox(height: 4),
        Row(children: [
          Text(
            score == 0 ? '安全指数：低' : score < 60 ? '安全指数：中' : '安全指数：高',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 12,
              color: score == 0 ? AppColors.error : score < 60 ? const Color(0xFFFF9800) : const Color(0xFF4CAF50),
            ),
          ),
        ]),
      ])),
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 3),
        ),
        child: Center(
          child: Text('$score',
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary)),
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
    padding: const EdgeInsets.only(left: 56),
    child: Divider(height: 1, color: AppColors.outlineVariant.withOpacity(0.5)),
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        // 图标
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: comingSoon ? Colors.grey.withOpacity(0.12) : iconBg.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20,
              color: comingSoon ? Colors.grey : iconBg),
        ),
        const SizedBox(width: 14),

        // 文字
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: comingSoon ? AppColors.onSurfaceVariant : AppColors.onSurface)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11, color: AppColors.onSurfaceVariant)),
        ])),

        // 分数 / 即将上线 / 完成状态
        if (done)
          const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF4ADE80))
        else if (comingSoon)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('即将上线',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)),
          )
        else if (score.isNotEmpty)
          Text(score,
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))
        ,
        const SizedBox(width: 6),
        if (!done && !comingSoon)
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.onSurfaceVariant),
      ]),
    ),
  );
}
