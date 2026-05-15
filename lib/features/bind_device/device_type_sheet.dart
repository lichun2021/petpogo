import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/theme/app_colors.dart';
import 'scan_qr_page.dart';

// ── 选择设备类型后跳转扫码 ────────────────────────────────
class DeviceTypeSheet extends StatelessWidget {
  const DeviceTypeSheet({super.key});

  static const _types = [
    _TypeItem(
      emoji:    '🐾',
      title:    '智能项圈',
      subtitle: '给宠物佩戴，实时定位 + 健康监测',
      icon:     Icons.circle_outlined,
      subIcon:  Icons.pets_rounded,
      grad1:    Color(0xFFff784e),
      grad2:    Color(0xFFa83206),
      glow:     Color(0xFFff784e),
      deviceType: '智能项圈',
    ),
    _TypeItem(
      emoji:    '🤖',
      title:    '智能宠物机器人',
      subtitle: '放置家中，互动陪伴 + 远程监控',
      icon:     Icons.smart_toy_rounded,
      subIcon:  null,
      grad1:    Color(0xFF00897B),
      grad2:    Color(0xFF006760),
      glow:     Color(0xFF7fe6db),
      deviceType: '智能宠物机器人',
    ),
  ];

  /// 弹出 Sheet，选完后跳转扫码。返回 true 表示完成绑定
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DeviceTypeSheet(),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13131f),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── 拖拽条 ─────────────────────────────────────────
        const SizedBox(height: 14),
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),

        // ── 标题 ───────────────────────────────────────────
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('选择设备类型', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            Text('选择要添加的智能设备类型，然后扫描设备二维码',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                    color: Colors.white.withOpacity(0.45))),
          ]),
        ),
        const SizedBox(height: 20),

        // ── 设备类型卡片 ───────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: _types.map((t) => _TypeCard(
            item: t,
            onTap: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(context); // 先关 Sheet
              final ok = await Navigator.push<bool>(context, MaterialPageRoute(
                builder: (_) => ScanQrPage(deviceType: t.deviceType),
              ));
              if (context.mounted) Navigator.pop(context, ok == true);
            },
          )).toList()),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ── 单个类型卡片 ──────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final _TypeItem item;
  final VoidCallback onTap;
  const _TypeCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [item.grad1.withOpacity(0.18), item.grad2.withOpacity(0.10)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: item.grad1.withOpacity(0.3), width: 1.2),
        ),
        child: Row(children: [
          // 图标背景
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [item.grad1, item.grad2],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: item.glow.withOpacity(0.5),
                  blurRadius: 16, spreadRadius: -2, offset: const Offset(0, 5))],
            ),
            child: Center(
              child: item.subIcon != null
                  ? Stack(alignment: Alignment.center, children: [
                      Icon(item.icon, color: Colors.white.withOpacity(0.5), size: 38),
                      Icon(item.subIcon, color: Colors.white, size: 20),
                      Positioned(bottom: 9, child: Container(width: 12, height: 3,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(2)))),
                    ])
                  : Icon(item.icon, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(width: 16),
          // 文字
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(item.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(item.title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
            const SizedBox(height: 5),
            Text(item.subtitle, style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 12, color: Colors.white.withOpacity(0.45), height: 1.4)),
          ])),
          // 箭头
          Icon(Icons.arrow_forward_ios_rounded,
              color: item.grad1.withOpacity(0.7), size: 16),
        ]),
      ),
    );
  }
}

// ── 数据模型 ──────────────────────────────────────────────
class _TypeItem {
  final String emoji, title, subtitle, deviceType;
  final IconData icon;
  final IconData? subIcon;
  final Color grad1, grad2, glow;
  const _TypeItem({
    required this.emoji, required this.title, required this.subtitle,
    required this.deviceType, required this.icon, required this.subIcon,
    required this.grad1, required this.grad2, required this.glow,
  });
}
