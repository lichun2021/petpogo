import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../core/config/app_config.dart';
import '../../core/providers/locale_provider.dart';
import '../../app.dart' show AppL10nX;
import '../../l10n/app_localizations.dart';

/// 设置页
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const bool _isLoggedIn = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeProvider);
    final isChinese = locale.languageCode == 'zh';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── 用户资料行 ──────────────────────────────
          if (_isLoggedIn) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _AnimatedTile(
                onTap: () {},
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                        child: Text('🐾', style: TextStyle(fontSize: 22))),
                  ),
                  title: const Text(
                    'PetLover3211I581B',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(l10n.settingsSectionService),
            _buildGroup([
              _SettingsTile(label: l10n.settingsOrders, onTap: () {}),
            ]),
            const SizedBox(height: 20),
          ],

          // ── 账户设置 ────────────────────────────────
          _buildSectionHeader(l10n.settingsSectionAccount),
          _buildGroup([
            // 语言切换（核心功能）
            _LanguageTile(isChinese: isChinese, ref: ref),
            _SettingsTile(label: l10n.settingsPassword, onTap: () {}),
            _SettingsTile(label: l10n.settingsAccountManage, onTap: () {}),
          ]),
          const SizedBox(height: 20),

          // ── 消息设置 ────────────────────────────────
          _buildSectionHeader(l10n.settingsSectionNotification),
          _buildGroup([
            _SettingsTile(label: l10n.settingsReceiveMessage, onTap: () {}),
            _SettingsTile(
                label: l10n.settingsNotificationPermission, onTap: () {}),
          ]),
          const SizedBox(height: 20),

          // ── 关于 ────────────────────────────────────
          _buildSectionHeader(l10n.settingsSectionAbout),
          _buildGroup([
            _SettingsTile(
                label: l10n.settingsVersion,
                trailing: AppConfig.appVersion,
                onTap: () {}),
            _SettingsTile(label: l10n.settingsTerms, onTap: () {}),
          ]),
          const SizedBox(height: 30),

          // ── 退出登录 ────────────────────────────────
          if (_isLoggedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _LogoutButton(l10n: l10n),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 11,
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGroup(List<Widget> tiles) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)
          ],
        ),
        child: Column(
          children: tiles.asMap().entries.map((e) {
            final isLast = e.key == tiles.length - 1;
            return Column(children: [
              e.value,
              if (!isLast)
                Divider(
                  color: AppColors.outlineVariant.withOpacity(0.08),
                  height: 0,
                  indent: 16,
                ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// ── 语言切换 Tile（内嵌 SegmentedButton）─────────────────────
class _LanguageTile extends StatelessWidget {
  final bool isChinese;
  final WidgetRef ref;

  const _LanguageTile({required this.isChinese, required this.ref});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.language_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(
            l10n.settingsLanguage,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 15,
              color: AppColors.onSurface,
            ),
          ),
          const Spacer(),
          // SegmentedButton 切换
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LangChip(
                  label: '中文',
                  selected: isChinese,
                  onTap: () => ref
                      .read(localeProvider.notifier)
                      .setLocale(const Locale('zh')),
                ),
                _LangChip(
                  label: 'EN',
                  selected: !isChinese,
                  onTap: () => ref
                      .read(localeProvider.notifier)
                      .setLocale(const Locale('en')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── 带按压动效的 Tile 包装 ──────────────────────────────────
class _AnimatedTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedTile({required this.child, required this.onTap});

  @override
  State<_AnimatedTile> createState() => _AnimatedTileState();
}

class _AnimatedTileState extends State<_AnimatedTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 16,
                  spreadRadius: -4)
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── 普通设置 Tile ────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _SettingsTile(
      {required this.label, this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: AppColors.primary.withOpacity(0.06),
      highlightColor: AppColors.primary.withOpacity(0.04),
      child: ListTile(
        title: Text(
          label,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 15,
            color: AppColors.onSurface,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── 退出登录按钮 ─────────────────────────────────────────────
class _LogoutButton extends StatefulWidget {
  final dynamic l10n;
  const _LogoutButton({required this.l10n});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _showDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          widget.l10n.settingsLogoutTitle,
          style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface),
        ),
        content: Text(
          widget.l10n.settingsLogoutContent,
          style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.l10n.commonCancel,
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              widget.l10n.settingsLogout,
              style: TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        _showDialog();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(48),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.l10n.settingsLogout,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
