/// ════════════════════════════════════════════════════════════
///  登录页面
///
///  UI 职责：
///    ✅ 渲染账号 / 密码输入框
///    ✅ 监听 AuthState 变化，显示加载 / 错误 / 成功反馈
///    ✅ 登录成功后由路由守卫自动跳转，页面不直接 push
///    ❌ 不包含任何业务逻辑（全部在 AuthController）
/// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import 'controller/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _accountCtrl  = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final account  = _accountCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (account.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入账号和密码')),
      );
      return;
    }
    ref.read(authControllerProvider.notifier).login(
      account: account,
      password: password,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    // 监听状态变化：成功 → 自动返回上一页；失败 → 弹出提示
    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next.status == AuthStatus.loggedIn) {
        // 登录成功，返回上一页（Profile 页会自动刷新显示已登录状态）
        if (context.mounted) Navigator.of(context).pop();
      } else if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo ────────────────────────────────────
              Row(children: [
                Icon(Icons.pets_rounded, color: AppColors.primary, size: 36),
                const SizedBox(width: 10),
                Text('萌宠智伴',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 28, fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ]),

              const SizedBox(height: 48),

              // ── 标题 ─────────────────────────────────────
              const Text('欢迎回来 👋',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 28, fontWeight: FontWeight.w800,
                      color: AppColors.onSurface)),
              const SizedBox(height: 6),
              Text('登录后管理您的宠物与设备',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14, color: AppColors.onSurfaceVariant)),

              const SizedBox(height: 40),

              // ── 账号输入框 ────────────────────────────────
              _FieldLabel('账号'),
              const SizedBox(height: 8),
              TextField(
                controller: _accountCtrl,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15, color: AppColors.onSurface),
                decoration: _inputDecoration(
                  hint: '请输入账号',
                  prefixIcon: Icons.person_outline_rounded,
                ),
              ),

              const SizedBox(height: 20),

              // ── 密码输入框 ────────────────────────────────
              _FieldLabel('密码'),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15, color: AppColors.onSurface),
                decoration: _inputDecoration(
                  hint: '请输入密码',
                  prefixIcon: Icons.lock_outline_rounded,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(_obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                        size: 20, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── 登录按钮 ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('登录',
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),

              const SizedBox(height: 24),

              // ── 游客入口 ──────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('暂不登录，以游客身份浏览',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13, color: AppColors.onSurfaceVariant)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 输入框样式 ─────────────────────────────────────────
  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 14, color: AppColors.onSurfaceVariant.withOpacity(0.6)),
        prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.onSurfaceVariant),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.outline.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
            fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.onSurface));
  }
}
