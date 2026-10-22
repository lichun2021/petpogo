import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_fonts.dart';
import '../../../shared/theme/app_tokens.dart';
import '../services/navigation_map_app.dart';

class PetNavigationSheet extends StatefulWidget {
  final bool isIOS;
  final String destinationName;
  final Future<bool> Function(NavigationMapApp app) onNavigate;

  const PetNavigationSheet({
    super.key,
    required this.isIOS,
    required this.destinationName,
    required this.onNavigate,
  });

  @override
  State<PetNavigationSheet> createState() => _PetNavigationSheetState();
}

class _PetNavigationSheetState extends State<PetNavigationSheet> {
  NavigationMapApp _selected = NavigationMapApp.amap;
  bool _opening = false;
  String? _error;

  Future<void> _navigate() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final opened = await widget.onNavigate(_selected);
      if (!mounted) return;
      if (opened) {
        Navigator.pop(context);
        return;
      }
      _showOpenError();
    } catch (_) {
      if (mounted) _showOpenError();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showOpenError() => setState(() {
        _error = '未能打开${_selected.label}，请确认已安装，或选择其他地图';
      });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.x20, 0, AppSpacing.x20, AppSpacing.x20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child: Text('选择地图',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary))),
              IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: AppSpacing.x4),
            Text('前往${widget.destinationName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.x20),
            for (final app in NavigationMapApp.forPlatform(isIOS: widget.isIOS))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x8),
                child: _NavigationMapRow(
                    app: app,
                    selected: app == _selected,
                    onTap: _opening
                        ? null
                        : () => setState(() {
                              _selected = app;
                              _error = null;
                            })),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
                child: Text(_error!,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.statusAlert)),
              ),
            const SizedBox(height: AppSpacing.x12),
            FilledButton.icon(
              onPressed: _opening ? null : _navigate,
              style: FilledButton.styleFrom(
                  foregroundColor: AppColors.textOnBrand,
                  backgroundColor: AppColors.brandPrimary,
                  minimumSize: const Size.fromHeight(AppSize.touchMin),
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillRadius)),
              icon: _opening
                  ? const SizedBox(
                      width: AppSpacing.x16,
                      height: AppSpacing.x16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.navigation_outlined, size: 18),
              label: Text(_opening ? '正在打开…' : '开始导航'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationMapRow extends StatelessWidget {
  final NavigationMapApp app;
  final bool selected;
  final VoidCallback? onTap;
  const _NavigationMapRow(
      {required this.app, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (app) {
      NavigationMapApp.amap => (Icons.navigation_rounded, AppColors.amap),
      NavigationMapApp.tencent => (
          Icons.directions_rounded,
          AppColors.tencentMap
        ),
      NavigationMapApp.baidu => (Icons.map_outlined, AppColors.baiduMap),
      NavigationMapApp.apple => (Icons.apple, AppColors.appleMaps),
    };
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Material(
        color: selected ? AppColors.brandPrimarySoft : AppColors.surfacePage,
        shape: RoundedRectangleBorder(
            borderRadius: AppRadius.controlRadius,
            side: BorderSide(
                color: selected
                    ? AppColors.brandPrimary.withValues(alpha: .35)
                    : Colors.transparent)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x12),
            child: Row(children: [
              Container(
                width: AppSpacing.x40,
                height: AppSpacing.x40,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: AppRadius.controlRadius),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.x8,
                  runSpacing: AppSpacing.x4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(app.label,
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    if (app == NavigationMapApp.amap)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
                        decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: AppRadius.pillRadius),
                        child: Text('推荐',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandPrimaryStrong)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x12),
              ExcludeSemantics(
                  child: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 22,
                      color: selected
                          ? AppColors.brandPrimary
                          : AppColors.textTertiary)),
            ]),
          ),
        ),
      ),
    );
  }
}
