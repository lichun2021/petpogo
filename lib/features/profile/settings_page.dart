import 'package:flutter/material.dart';
import '../../shared/theme/app_colors.dart';
import '../../core/config/app_config.dart';

/// 设置页（对应"我的" Tab 点击设置按钮进入）
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const bool _isLoggedIn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(),
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 用户资料行（仅登录用户显示）
          if (_isLoggedIn) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Text('🐾', style: TextStyle(fontSize: 22))),
                  ),
                  title: Text(
                    'PetLover3211I581B',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
                  onTap: () {},
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader('服务'),
            _buildSettingsGroup([
              _SettingsTile(label: '订单', onTap: () {}),
            ]),
            const SizedBox(height: 20),
          ],

          _buildSectionHeader('账户设置'),
          _buildSettingsGroup([
            _SettingsTile(label: '语言', trailing: '简体中文', onTap: () {}),
            _SettingsTile(label: '密码', onTap: () {}),
            _SettingsTile(label: '账户管理', onTap: () {}),
          ]),
          const SizedBox(height: 20),

          _buildSectionHeader('消息设置'),
          _buildSettingsGroup([
            _SettingsTile(label: '接收消息', onTap: () {}),
            _SettingsTile(label: '通知权限设置', onTap: () {}),
          ]),
          const SizedBox(height: 20),

          _buildSectionHeader('关于'),
          _buildSettingsGroup([
            _SettingsTile(label: '版本', trailing: AppConfig.appVersion, onTap: () {}),
            _SettingsTile(label: '条款', onTap: () {}),
          ]),
          const SizedBox(height: 30),

          if (_isLoggedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showLogoutDialog(context),
                  icon: Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                  label: Text(
                    '退出登录',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
                  ),
                ),
              ),
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
        title,
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 12,
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<_SettingsTile> tiles) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4)],
        ),
        child: Column(
          children: tiles.asMap().entries.map((e) {
            final isLast = e.key == tiles.length - 1;
            return Column(
              children: [
                e.value,
                if (!isLast)
                  Divider(
                    color: AppColors.outlineVariant.withOpacity(0.08),
                    height: 0,
                    indent: 16,
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('退出登录', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        content: Text('确定要退出登录吗？', style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: AppColors.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); /* TODO: 执行登出 */ },
            child: Text('退出', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _SettingsTile({required this.label, this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}
