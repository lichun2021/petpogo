import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pressable.dart';

/// 绑定成功页 — 庆祝动画 + 后续操作引导
class BindSuccessPage extends StatefulWidget {
  final String deviceType;
  const BindSuccessPage({super.key, required this.deviceType});

  @override
  State<BindSuccessPage> createState() => _BindSuccessPageState();
}

class _BindSuccessPageState extends State<BindSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  bool get _isKeyTracker => widget.deviceType == 'KeyTracker';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 100), () {
      _ctrl.forward();
      HapticFeedback.heavyImpact();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),

              // 成功图标
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.primaryGlow, blurRadius: 50, spreadRadius: -4),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isKeyTracker ? '🗝️' : '📱',
                          style: const TextStyle(fontSize: 52)),
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // 文字
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Text('${widget.deviceType} 绑定成功！',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 28,
                            fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: -0.6)),
                    const SizedBox(height: 12),
                    Text('你的设备已与账号关联\n可以在首页查看实时状态',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                            color: AppColors.onSurfaceVariant, height: 1.6)),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 设备功能说明卡
              FadeTransition(
                opacity: _fade,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 20, spreadRadius: -6)],
                  ),
                  child: Column(
                    children: _isKeyTracker
                        ? [
                            _FeatureRow(icon: Icons.location_on_rounded, label: '实时 GPS 定位', color: AppColors.primary),
                            const SizedBox(height: 14),
                            _FeatureRow(icon: Icons.notifications_active_rounded, label: '走失预警通知', color: AppColors.secondary),
                            const SizedBox(height: 14),
                            _FeatureRow(icon: Icons.battery_charging_full_rounded, label: '电量低提醒', color: AppColors.tertiary),
                          ]
                        : [
                            _FeatureRow(icon: Icons.call_rounded, label: '远程与宠物通话', color: AppColors.primary),
                            const SizedBox(height: 14),
                            _FeatureRow(icon: Icons.music_note_rounded, label: '播放舒缓音乐', color: AppColors.secondary),
                            const SizedBox(height: 14),
                            _FeatureRow(icon: Icons.graphic_eq_rounded, label: 'AI 宠物语音识别', color: AppColors.tertiary),
                          ],
                  ),
                ),
              ),

              const Spacer(),

              // 操作按钮
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    PrimaryButton(
                      label: '查看设备状态',
                      icon: Icons.sensors_rounded,
                      onPressed: () => context.go('/'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/bind-device'),
                      child: Text('继续添加设备',
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FeatureRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 14),
      Text(label, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14,
          fontWeight: FontWeight.w600, color: AppColors.onSurface)),
      const Spacer(),
      Icon(Icons.check_rounded, color: color, size: 18),
    ]);
  }
}
