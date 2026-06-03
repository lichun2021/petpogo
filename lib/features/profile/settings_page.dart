import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../core/config/app_config.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/font_provider.dart';
import '../../core/providers/color_scheme_provider.dart';
import '../../shared/theme/color_schemes.dart';
import '../../app.dart' show AppL10nX;
import '../auth/controller/auth_controller.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

/// 设置页（含修改昵称 / 修改密码）
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.watch(localeProvider); // 保持对 locale 变化的订阅
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.settingsTitle,
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── 外观───────────────────────────────────────
          _buildSectionHeader('外观'),
          _AppearanceGroup(),
          SizedBox(height: 20),

          // ── 账户（语言 + 昵称 + 密码）────────────────────
          _buildSectionHeader('账户'),
          _buildGroup([
            if (user != null)
              _SettingsTile(
                icon: Icons.lock_rounded,
                label: '修改密码',
                onTap: () => _showPasswordSheet(context, ref),
              ),
          ]),
          SizedBox(height: 20),

          // ── 关于 ──────────────────────────────────────
          _buildSectionHeader(l10n.settingsSectionAbout),
          _buildGroup([
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: l10n.settingsVersion,
              trailing: AppConfig.appVersion,
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.article_rounded,
              label: l10n.settingsTerms,
              onTap: () {},
            ),
          ]),
          SizedBox(height: 32),

          // ── 退出登录 ──────────────────────────────────
          if (auth.isLoggedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _LogoutButton(l10n: l10n, ref: ref),
            ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── 修改密码 Bottom Sheet ─────────────────────────────
  void _showPasswordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _PasswordSheet(ref: ref),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      );

  Widget _buildGroup(List<Widget> tiles) => Padding(
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
            children: tiles
                .asMap()
                .entries
                .map((e) => Column(children: [
                      e.value,
                      if (e.key < tiles.length - 1)
                        Divider(
                            color: AppColors.outlineVariant.withOpacity(0.08),
                            height: 0,
                            indent: 56),
                    ]))
                .toList(),
          ),
        ),
      );
}

// ── 外观分组（字体 + 配色）──────────────────────────
// ignore: must_be_immutable
class _AppearanceGroup extends ConsumerWidget {
  const _AppearanceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFont   = ref.watch(fontFamilyProvider);
    final currentScheme = ref.watch(colorSchemeProvider);
    final fontNotifier   = ref.read(fontFamilyProvider.notifier);
    final schemeNotifier = ref.read(colorSchemeProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10,
                spreadRadius: -4),
          ],
        ),
        child: Column(
          children: [
            // ―― 字体 ――
            _DropdownRow(
              icon: Icons.text_fields_rounded,
              label: '字体',
              value: currentFont,
              items: kFontOptions.map<DropdownMenuItem<String>>((o) => DropdownMenuItem<String>(
                value: o.family,
                child: Text(o.name,
                    style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans', // 始终用系统字体显示选项名
                        fontSize: 14,
                        color: AppColors.onSurface)),
              )).toList(),
              onChanged: (v) { if (v != null) fontNotifier.setFont(v); },
            ),
            Divider(height: 1, indent: 52,
                color: AppColors.outlineVariant.withOpacity(0.2)),
            // ―― 配色 ――
            _DropdownRow(
              icon: Icons.palette_outlined,
              label: '配色',
              value: currentScheme,
              items: kColorSchemes.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(
                value: s.key,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.emoji, style: TextStyle(fontSize: 16)),
                    SizedBox(width: 6),
                    Text(s.name,
                        style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14,
                            color: AppColors.onSurface)),
                  ],
                ),
              )).toList(),
              onChanged: (v) { if (v != null) schemeNotifier.setScheme(v); },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 下拉行通用组件 ──────────────────────────────────────
class _DropdownRow<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurface)),
          Spacer(),
          DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.expand_more_rounded,
                size: 18, color: AppColors.onSurfaceVariant),
            style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                color: AppColors.onSurface),
            dropdownColor: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
    );
  }
}


class _PasswordSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _PasswordSheet({required this.ref});

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _cfmCtrl = TextEditingController();
  bool _loading = false;
  bool _showOld = false;
  bool _showNew = false;
  String? _error;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _cfmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newCtrl.text.length < 6) {
      setState(() => _error = '新密码不能少于6位');
      return;
    }
    if (_newCtrl.text != _cfmCtrl.text) {
      setState(() => _error = '两次密码不一致');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result =
        await ref.read(authControllerProvider.notifier).changePassword(
              oldPassword: _oldCtrl.text,
              newPassword: _newCtrl.text,
            );
    if (!mounted) return;

    result.when(
      success: (_) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
              content: Text('密码已更新'), behavior: SnackBarBehavior.floating),
        );
      },
      failure: (err) {
        setState(() {
          _loading = false;
          _error = err.userMessage;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('修改密码',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          SizedBox(height: 20),
          _SheetField(
              controller: _oldCtrl,
              hint: '当前密码',
              icon: Icons.lock_outline_rounded,
              obscure: !_showOld,
              suffix: IconButton(
                  icon: Icon(
                      _showOld
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: AppColors.onSurfaceVariant),
                  onPressed: () => setState(() => _showOld = !_showOld))),
          SizedBox(height: 12),
          _SheetField(
              controller: _newCtrl,
              hint: '新密码（至少6位）',
              icon: Icons.lock_rounded,
              obscure: !_showNew,
              suffix: IconButton(
                  icon: Icon(
                      _showNew
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: AppColors.onSurfaceVariant),
                  onPressed: () => setState(() => _showNew = !_showNew))),
          SizedBox(height: 12),
          _SheetField(
              controller: _cfmCtrl,
              hint: '确认新密码',
              icon: Icons.lock_reset_rounded,
              obscure: true),
          if (_error != null) ...[
            SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          SizedBox(height: 20),
          _SheetButton(label: '确认修改', loading: _loading, onTap: _submit),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── 共用 Sheet 输入框 ──────────────────────────────────────
class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  const _SheetField(
      {required this.controller,
      required this.hint,
      required this.icon,
      this.obscure = false,
      this.suffix});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(fontFamily: AppFonts.primary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontFamily: AppFonts.primary,
              fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ── 共用 Sheet 按钮 ────────────────────────────────────────
class _SheetButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _SheetButton(
      {required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          elevation: 0,
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── 普通设置 Tile ──────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  const _SettingsTile(
      {required this.icon,
      required this.label,
      this.trailing,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.primary.withOpacity(0.06),
        child: ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          title: Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 15,
                  color: AppColors.onSurface)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (trailing != null)
              Text(trailing!,
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant)),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant, size: 20),
          ]),
        ),
      );
}

// ── 退出登录按钮 ───────────────────────────────────────────
class _LogoutButton extends ConsumerWidget {
  final dynamic l10n;
  final WidgetRef ref;
  const _LogoutButton({required this.l10n, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(l10n.settingsLogoutTitle,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          content: Text(l10n.settingsLogoutContent,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  color: AppColors.onSurfaceVariant)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonCancel,
                    style: TextStyle(color: AppColors.onSurfaceVariant))),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(authControllerProvider.notifier).logout();
              },
              child: Text(l10n.settingsLogout,
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
      icon: Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
      label: Text(l10n.settingsLogout,
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.error)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.error.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        minimumSize: Size(double.infinity, 52),
      ),
    );
  }
}
