/// ════════════════════════════════════════════════════════════
///  登录页面
///
///  UI 职责：
///    ✅ 渲染账号 / 密码输入框
///    ✅ 监听 AuthState 变化，显示加载 / 错误 / 成功反馈
///    ✅ 登录成功后由路由守卫自动跳转，页面不直接 push
///    ❌ 不包含任何业务逻辑（全部在 AuthController）
/// ════════════════════════════════════════════════════════════

import 'dart:async';
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
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl     = TextEditingController();
  
  bool _obscure = true;
  bool _isSmsLogin = true;

  bool _isSendingSms = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendSms() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入手机号')),
      );
      return;
    }
    setState(() => _isSendingSms = true);
    final error = await ref.read(authControllerProvider.notifier).sendSms(phone);
    if (!mounted) return;
    setState(() => _isSendingSms = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码已发送，请注意查收')),
      );
      _startCountdown();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  void _submit() {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入手机号')),
      );
      return;
    }

    if (_isSmsLogin) {
      final code = _codeCtrl.text.trim();
      if (code.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入验证码')),
        );
        return;
      }
      ref.read(authControllerProvider.notifier).loginWithSms(phone: phone, code: code);
    } else {
      final password = _passwordCtrl.text.trim();
      if (password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入密码')),
        );
        return;
      }
      ref.read(authControllerProvider.notifier).loginWithPwd(phone: phone, password: password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next.status == AuthStatus.loggedIn) {
        // 路由守卫检测到 loggedIn 后会自动跳回首页，无需手动 pop
        debugPrint('[LoginPage] 登录成功，等待路由守卫跳转');
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
                const Text('萌宠智伴',
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
              Text('未注册手机号验证后自动创建账号',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14, color: AppColors.onSurfaceVariant)),

              const SizedBox(height: 30),

              // ── 切换登录方式 ──────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isSmsLogin = true),
                    child: Text('短信登录',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: _isSmsLogin ? FontWeight.w800 : FontWeight.w600,
                            color: _isSmsLogin ? AppColors.primary : AppColors.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: () => setState(() => _isSmsLogin = false),
                    child: Text('密码登录',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: !_isSmsLogin ? FontWeight.w800 : FontWeight.w600,
                            color: !_isSmsLogin ? AppColors.primary : AppColors.onSurfaceVariant)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 手机号输入框 ────────────────────────────────
              const _FieldLabel('手机号'),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15, color: AppColors.onSurface),
                decoration: _inputDecoration(
                  hint: '请输入手机号',
                  prefixIcon: Icons.phone_android_rounded,
                ),
              ),

              const SizedBox(height: 20),

              // ── 验证码 / 密码输入框 ────────────────────────────────
              if (_isSmsLogin) ...[
                const _FieldLabel('验证码'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                            fontSize: 15, color: AppColors.onSurface),
                        decoration: _inputDecoration(
                          hint: '请输入验证码',
                          prefixIcon: Icons.message_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 96,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: (_countdown > 0 || _isSendingSms) ? null : _sendSms,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: (_countdown > 0 || _isSendingSms)
                                ? AppColors.outline
                                : AppColors.primary,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSendingSms
                            ? SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ))
                            : Text(
                                _countdown > 0 ? '${_countdown}s 后重发' : '获取验证码',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _countdown > 0
                                      ? AppColors.onSurfaceVariant
                                      : AppColors.primary,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const _FieldLabel('密码'),
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
              ],

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
                      : const Text('登录 / 注册',
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
