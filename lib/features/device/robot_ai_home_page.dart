/// AI 智能设置中心 — 自动抓拍 / 自动打招呼
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/pet_switch.dart';
import 'robot_ai_capture_page.dart';
import 'robot_ai_greeting_page.dart';

class RobotAiHomePage extends StatefulWidget {
  final String mac;
  final String deviceName;

  const RobotAiHomePage({
    super.key,
    required this.mac,
    required this.deviceName,
  });

  @override
  State<RobotAiHomePage> createState() => _RobotAiHomePageState();
}

class _RobotAiHomePageState extends State<RobotAiHomePage> {
  bool _captureEnabled  = false;
  bool _greetingEnabled = false;

  // 摘要信息（从 prefs 读）
  String _captureSchedule  = '未配置';
  String _greetingSchedule = '未配置';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // ── 抓拍配置 ──
    final capRaw = prefs.getString('robot_ai_capture_${widget.mac}');
    if (capRaw != null) {
      try {
        final m = jsonDecode(capRaw) as Map<String, dynamic>;
        final enabled = m['enabled'] == true;
        final start   = m['start'] as String? ?? '09:00';
        final end     = m['end']   as String? ?? '22:00';
        setState(() {
          _captureEnabled  = enabled;
          _captureSchedule = enabled ? '$start ~ $end' : '已关闭';
        });
      } catch (_) {}
    }

    // ── 打招呼配置 ──
    final greetRaw = prefs.getString('robot_ai_greeting_${widget.mac}');
    if (greetRaw != null) {
      try {
        final m = jsonDecode(greetRaw) as Map<String, dynamic>;
        final enabled = m['enabled'] == true;
        final start   = m['start'] as String? ?? '10:00';
        final end     = m['end']   as String? ?? '18:00';
        setState(() {
          _greetingEnabled  = enabled;
          _greetingSchedule = enabled ? '$start ~ $end' : '已关闭';
        });
      } catch (_) {}
    }
  }

  /// 快速保存 enabled 状态（不打开详情页）
  Future<void> _toggleCapture(bool v) async {
    setState(() => _captureEnabled = v);
    final prefs = await SharedPreferences.getInstance();
    final key   = 'robot_ai_capture_${widget.mac}';
    final raw   = prefs.getString(key);
    Map<String, dynamic> m = {};
    if (raw != null) {
      try { m = jsonDecode(raw) as Map<String, dynamic>; } catch (_) {}
    }
    m['enabled'] = v;
    await prefs.setString(key, jsonEncode(m));
    setState(() => _captureSchedule = v
        ? '${m['start'] ?? '09:00'} ~ ${m['end'] ?? '22:00'}' : '已关闭');
  }

  Future<void> _toggleGreeting(bool v) async {
    setState(() => _greetingEnabled = v);
    final prefs = await SharedPreferences.getInstance();
    final key   = 'robot_ai_greeting_${widget.mac}';
    final raw   = prefs.getString(key);
    Map<String, dynamic> m = {};
    if (raw != null) {
      try { m = jsonDecode(raw) as Map<String, dynamic>; } catch (_) {}
    }
    m['enabled'] = v;
    await prefs.setString(key, jsonEncode(m));
    setState(() => _greetingSchedule = v
        ? '${m['start'] ?? '10:00'} ~ ${m['end'] ?? '18:00'}' : '已关闭');
  }

  Future<void> _goCapture() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => RobotAiCapturePage(
          mac: widget.mac, deviceName: widget.deviceName),
    ));
    _loadStatus(); // 返回后刷新状态
  }

  Future<void> _goGreeting() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => RobotAiGreetingPage(
          mac: widget.mac, deviceName: widget.deviceName),
    ));
    _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: Column(children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              // ── 功能卡区 ──────────────────────────────────
              _sectionLabel('自动互动功能'),
              const SizedBox(height: 10),
              _FeatureCard(
                icon: Icons.camera_alt_rounded,
                title: '自动抓拍',
                desc: '识别宠物出现后拍照，并生成情绪分析',
                enabled: _captureEnabled,
                schedule: _captureSchedule,
                onToggle: _toggleCapture,
                onTap: _goCapture,
              ),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: Icons.record_voice_over_rounded,
                title: '自动打招呼',
                desc: '按计划播放问候语，并分析宠物回应',
                enabled: _greetingEnabled,
                schedule: _greetingSchedule,
                onToggle: _toggleGreeting,
                onTap: _goGreeting,
              ),

              // ── 当前状态摘要 ───────────────────────────────
              const SizedBox(height: 28),
              _sectionLabel('当前状态'),
              const SizedBox(height: 10),
              _StatusPanel(
                captureEnabled:  _captureEnabled,
                captureSchedule: _captureSchedule,
                greetingEnabled: _greetingEnabled,
                greetingSchedule: _greetingSchedule,
              ),

              // ── 使用提示 ──────────────────────────────────
              const SizedBox(height: 28),
              _sectionLabel('使用提示'),
              const SizedBox(height: 10),
              _TipCard(tips: const [
                '开启自动抓拍后，摄像头会在有效时段内检测宠物活动并自动录制。',
                '自动打招呼会在设定时段内按次数上限向宠物播放问候声音。',
                '所有录像和分析结果可在各功能详情页的媒体库中查看。',
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          // ── 顶部导航行 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back_ios_rounded,
                    size: 20, color: AppColors.onSurface),
              ),
              const SizedBox(width: 12),
              Text('AI 智能',
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.3,
                )),
              const Spacer(),
              // 机器人状态 chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('在线',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    )),
                ]),
              ),
            ]),
          ),
          // ── 底部分隔线 ──
          Divider(height: 1, color: AppColors.outlineVariant.withOpacity(0.3)),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
      style: TextStyle(
        fontFamily: AppFonts.primary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.3,
      ));
  }
}

// ══════════════════════════════════════════════════════════════
//  功能卡片（图标 + 文案 + 开关 + 点击进详情）
// ══════════════════════════════════════════════════════════════
class _FeatureCard extends StatelessWidget {
  final IconData   icon;
  final String     title;
  final String     desc;
  final bool       enabled;
  final String     schedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback       onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.enabled,
    required this.schedule,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(children: [
            // ── 图标容器 ──
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(enabled ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon,
                size: 24,
                color: enabled
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            // ── 文案 ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    )),
                  const SizedBox(height: 3),
                  Text(desc,
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    )),
                  // 时段小标签
                  if (enabled) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.schedule_rounded,
                          size: 11, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(schedule,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        )),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // ── 开关 ──
            PetSwitch(
              value: enabled,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onToggle(v);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  当前状态面板
// ══════════════════════════════════════════════════════════════
class _StatusPanel extends StatelessWidget {
  final bool   captureEnabled;
  final String captureSchedule;
  final bool   greetingEnabled;
  final String greetingSchedule;

  const _StatusPanel({
    required this.captureEnabled,
    required this.captureSchedule,
    required this.greetingEnabled,
    required this.greetingSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        _StatusRow(
          icon: Icons.camera_alt_rounded,
          label: '自动抓拍',
          status: captureEnabled ? captureSchedule : '未开启',
          active: captureEnabled,
        ),
        Divider(height: 1, indent: 56, endIndent: 16,
            color: AppColors.outlineVariant.withOpacity(0.3)),
        _StatusRow(
          icon: Icons.record_voice_over_rounded,
          label: '定时打招呼',
          status: greetingEnabled ? greetingSchedule : '未开启',
          active: greetingEnabled,
        ),
      ]),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   status;
  final bool     active;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 20,
          color: active ? AppColors.primary : AppColors.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          )),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withOpacity(0.10)
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.primary : AppColors.onSurfaceVariant,
            )),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  使用提示卡
// ══════════════════════════════════════════════════════════════
class _TipCard extends StatelessWidget {
  final List<String> tips;
  const _TipCard({required this.tips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tips.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 4, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t,
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                )),
            ),
          ]),
        )).toList(),
      ),
    );
  }
}
