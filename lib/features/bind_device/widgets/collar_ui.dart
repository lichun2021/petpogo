import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';

/// 蓝牙配网流程共用文字样式，颜色取自语义 token。
abstract final class CollarText {
  static TextStyle get title => TextStyle(
      fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static TextStyle get body =>
      TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary);
  static TextStyle get caption =>
      TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary);
}

/// 圆形英雄图标，可叠加进度环（busy）与雷达脉冲（pulse）。
/// [halo] 为脉冲预留外圈空间，避免动画开始时布局跳动。
class CollarHeroBadge extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color? iconColor, backgroundColor;
  final bool busy, pulse, halo;
  const CollarHeroBadge({
    super.key,
    required this.icon,
    this.size = 88,
    this.iconColor,
    this.backgroundColor,
    this.busy = false,
    this.pulse = false,
    this.halo = false,
  });

  @override
  State<CollarHeroBadge> createState() => _CollarHeroBadgeState();
}

class _CollarHeroBadgeState extends State<CollarHeroBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncPulse();
  }

  @override
  void didUpdateWidget(CollarHeroBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final run = widget.pulse && !_reduceMotion;
    if (run && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!run && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.iconColor ?? AppColors.brandPrimary;
    final fill = widget.backgroundColor ?? AppColors.brandPrimarySoft;
    final outer =
        widget.pulse || widget.halo ? widget.size * 1.45 : widget.size;
    return SizedBox(
      width: outer,
      height: outer,
      child: Center(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (_pulse.isAnimating) ...[
                _Ripple(animation: _pulse, color: accent, phase: 0),
                _Ripple(animation: _pulse, color: accent, phase: .5),
              ],
              Container(
                  width: widget.size,
                  height: widget.size,
                  decoration:
                      BoxDecoration(color: fill, shape: BoxShape.circle)),
              Icon(widget.icon, size: widget.size * .5, color: accent),
              if (widget.busy)
                Positioned.fill(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accent)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ripple extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final double phase;
  const _Ripple(
      {required this.animation, required this.color, required this.phase});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = (animation.value + phase) % 1.0;
          return Transform.scale(
            scale: 1 + .45 * t,
            child: SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: color.withValues(alpha: .35 * (1 - t)), width: 2),
                ),
              ),
            ),
          );
        },
      );
}

enum CollarNoticeTone { info, warning, error }

/// 带图标的提示卡，状态不只靠颜色表达。
class CollarNoticeCard extends StatelessWidget {
  final CollarNoticeTone tone;
  final String? title;
  final String message;
  final Widget? action;
  const CollarNoticeCard(
      {super.key,
      this.tone = CollarNoticeTone.info,
      this.title,
      required this.message,
      this.action});

  @override
  Widget build(BuildContext context) {
    final (icon, accent, fill) = switch (tone) {
      CollarNoticeTone.info => (
          Icons.info_outline_rounded,
          AppColors.statusNeutral,
          AppColors.surfaceSunken
        ),
      CollarNoticeTone.warning => (
          Icons.warning_amber_rounded,
          AppColors.statusWarning,
          AppColors.statusWarningSoft
        ),
      CollarNoticeTone.error => (
          Icons.error_outline_rounded,
          AppColors.statusAlert,
          AppColors.statusAlertSoft
        ),
    };
    return Semantics(
      container: true,
      liveRegion: tone == CollarNoticeTone.error,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x16),
        decoration:
            BoxDecoration(color: fill, borderRadius: AppRadius.cardRadius),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (title != null) ...[
                  Text(title!,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: AppSpacing.x4),
                ],
                Text(message,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textPrimary)),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.x4),
                  action!,
                ],
              ])),
        ]),
      ),
    );
  }
}

/// 设备行：发现列表与已选设备摘要共用。
class CollarDeviceTile extends StatelessWidget {
  final String title, subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool selected, dimmed;
  const CollarDeviceTile(
      {super.key,
      required this.title,
      required this.subtitle,
      this.onTap,
      this.trailing,
      this.selected = false,
      this.dimmed = false});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: dimmed ? .5 : 1,
        child: Material(
          color: selected ? AppColors.brandPrimarySoft : AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.cardRadius,
              side: BorderSide(
                  color:
                      selected ? Colors.transparent : AppColors.borderSubtle)),
          child: InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: AppRadius.cardRadius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x12),
              child: Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: selected
                            ? AppColors.surfaceCard
                            : AppColors.brandPrimarySoft,
                        shape: BoxShape.circle),
                    child: Icon(Icons.bluetooth_rounded,
                        size: 20, color: AppColors.brandPrimary)),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: AppSpacing.x4),
                      Text(subtitle, style: CollarText.caption),
                    ])),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.x8),
                  trailing!,
                ],
              ]),
            ),
          ),
        ),
      );
}

/// 全宽胶囊主按钮：整页唯一的主操作。
class CollarPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const CollarPrimaryButton(
      {super.key, required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape:
            const RoundedRectangleBorder(borderRadius: AppRadius.pillRadius));
    return icon == null
        ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 20),
            label: Text(label));
  }
}

class CollarGuideItem {
  final IconData icon;
  final String text;
  const CollarGuideItem(this.icon, this.text);
}

class CollarGuideList extends StatelessWidget {
  final List<CollarGuideItem> items;
  const CollarGuideList({super.key, required this.items});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.x12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: AppColors.brandPrimarySoft,
                      shape: BoxShape.circle),
                  child: Icon(items[i].icon,
                      size: 18, color: AppColors.brandPrimary)),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 32),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(items[i].text,
                              style: CollarText.body
                                  .copyWith(color: AppColors.textPrimary))))),
            ]),
          ],
        ],
      );
}
