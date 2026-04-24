import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../shared/theme/app_colors.dart';
import '../../app.dart' show AppL10nX;

/// 宠物详情页 — 健康卡、AI识别历史、设备关联
class PetDetailPage extends StatelessWidget {
  /// 从路由参数传入的宠物 ID（用于加载详情数据）
  final String petId;
  const PetDetailPage({super.key, this.petId = ''});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── 大图 AppBar ──────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                ),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 背景图案
                    Positioned(right: -30, bottom: -30,
                        child: Text('🐱', style: TextStyle(fontSize: 160, color: Colors.white.withOpacity(0.15)))),
                    // 宠物信息
                    Positioned(
                      left: 24, bottom: 32,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Center(child: Text('🐱', style: TextStyle(fontSize: 38))),
                          ),
                          const SizedBox(height: 10),
                          const Text('Doudou',
                              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 28,
                                  fontWeight: FontWeight.w800, color: Colors.white)),
                          Row(children: [
                            _Badge('CAT', Colors.white.withOpacity(0.25), Colors.white),
                            const SizedBox(width: 6),
                            _Badge('British Shorthair', Colors.white.withOpacity(0.25), Colors.white),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── 基本信息卡 ──────────────────────────
                _SectionCard(
                  children: [
                    _InfoRow(icon: Icons.cake_rounded,    label: '生日',     value: '2022-03-15 (3岁)'),
                    _Divider(),
                    _InfoRow(icon: Icons.transgender_rounded, label: '性别', value: '♂ 公猫'),
                    _Divider(),
                    _InfoRow(icon: Icons.monitor_weight_rounded, label: '体重', value: '4.2 kg'),
                    _Divider(),
                    _InfoRow(icon: Icons.palette_rounded, label: '毛色',      value: '灰蓝色'),
                  ],
                ).animate().fadeIn().slideY(begin: 0.1),

                const SizedBox(height: 20),

                // ── 健康状态 ────────────────────────────
                _SectionTitle('健康状态'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _HealthCard(emoji: '💉', label: '疫苗',  status: '已接种', color: AppColors.secondary, isOk: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _HealthCard(emoji: '🩺', label: '体检',  status: '待复诊', color: AppColors.error, isOk: false)),
                  const SizedBox(width: 12),
                  Expanded(child: _HealthCard(emoji: '💊', label: '驱虫',  status: '正常',   color: AppColors.secondary, isOk: true)),
                ]).animate().fadeIn().slideY(begin: 0.1, delay: 80.ms),

                const SizedBox(height: 20),

                // ── AI 识别历史 ─────────────────────────
                _SectionTitle('AI 识别记录'),
                const SizedBox(height: 12),
                ...[
                  _TranslateHistoryCard(time: '今天 14:30', emoji: '🥺', content: '主人快来抱我！我好想你了嘛～',
                      emotions: ['撒娇 78%', '开心 45%']),
                  _TranslateHistoryCard(time: '昨天 09:12', emoji: '😾', content: '这个食物不好吃！换一个！',
                      emotions: ['不满 85%', '饥饿 60%']),
                  _TranslateHistoryCard(time: '2天前 21:05', emoji: '😴', content: '我要睡觉了，别吵我...',
                      emotions: ['困意 92%', '满足 40%']),
                ].asMap().entries.map((e) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: e.value,
                  ).animate().fadeIn().slideY(begin: 0.1, delay: (100 + e.key * 60).ms)
                ),

                const SizedBox(height: 20),

                // ── 关联设备 ────────────────────────────
                _SectionTitle('关联设备'),
                const SizedBox(height: 12),
                _LinkedDeviceCard(
                  name: 'KeyTracker',
                  icon: Icons.key_rounded,
                  iconColor: AppColors.secondary,
                  status: '在线',
                  battery: 85,
                  location: '南山区科技园',
                ).animate().fadeIn().slideY(begin: 0.1, delay: 200.ms),

              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 辅助组件 ──────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color bg, text;
  const _Badge(this.label, this.bg, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
          fontWeight: FontWeight.w700, color: text)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18,
        fontWeight: FontWeight.w700, color: AppColors.onSurface, letterSpacing: -0.3));
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
              color: AppColors.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
              fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 0, indent: 16, color: AppColors.outlineVariant.withOpacity(0.08));
  }
}

class _HealthCard extends StatelessWidget {
  final String emoji, label, status;
  final Color color;
  final bool isOk;
  const _HealthCard({required this.emoji, required this.label, required this.status, required this.color, required this.isOk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
              fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
              fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _TranslateHistoryCard extends StatelessWidget {
  final String time, emoji, content;
  final List<String> emotions;
  const _TranslateHistoryCard({required this.time, required this.emoji, required this.content, required this.emotions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, spreadRadius: -4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(content, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                    color: AppColors.onSurface, height: 1.4))),
          ]),
          const SizedBox(height: 8),
          Row(
            children: [
              ...emotions.map((e) => Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(e, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                    fontWeight: FontWeight.w700, color: AppColors.primary)),
              )),
              const Spacer(),
              Text(time, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                  color: AppColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkedDeviceCard extends StatelessWidget {
  final String name, status, location;
  final IconData icon;
  final Color iconColor;
  final int battery;
  const _LinkedDeviceCard({required this.name, required this.icon, required this.iconColor,
    required this.status, required this.battery, required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)],
      ),
      child: Row(children: [
        Container(width: 48, height: 48,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.online, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(status, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondary)),
            Text('  ·  $location', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: AppColors.onSurfaceVariant)),
          ]),
        ])),
        Column(children: [
          Text('$battery%', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          Icon(Icons.battery_5_bar_rounded, size: 18, color: AppColors.onSurfaceVariant),
        ]),
      ]),
    );
  }
}
