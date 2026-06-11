/// ════════════════════════════════════════════════════════════
///  登录页面
///
///  UI 职责：
///    ✅ 渲染账号 / 密码输入框
///    ✅ 国家/区号选择（下拉底部弹窗，数据来自 PeerApi）
///    ✅ 监听 AuthState 变化，显示加载 / 错误 / 成功反馈
///    ✅ 登录成功后由路由守卫自动跳转，页面不直接 push
///    ❌ 不包含任何业务逻辑（全部在 AuthController）
/// ════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/pet_toast.dart';
import '../../../shared/widgets/doc_reader_page.dart';
import 'data/models/country_model.dart';
import 'data/country_repository.dart';
import 'controller/auth_controller.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';


class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl     = TextEditingController();
  final _searchCtrl   = TextEditingController();

  bool _obscure = true;
  bool _isSmsLogin = true;
  bool _agreedToTerms = false;   // 是否同意协议

  bool _isSendingSms = false;
  int _countdown = 0;
  Timer? _timer;

  CountryInfo _selectedCountry = CountryInfo.china;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    _searchCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() { _countdown = 60; });
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
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
      PetToast.warning(context, '请先输入手机号');
      return;
    }
    setState(() => _isSendingSms = true);
    final error = await ref
        .read(authControllerProvider.notifier)
        .sendSms(phone, nationNum: _selectedCountry.dialCode);
    if (!mounted) return;
    setState(() => _isSendingSms = false);
    if (error == null) {
      PetToast.success(context, '验证码已发送，请注意查收 📱');
      _startCountdown();
    } else {
      PetToast.error(context, error);
    }
  }

  void _submit() {
    // 先检查是否同意协议
    if (!_agreedToTerms) {
      PetToast.warning(context, '请先阅读并同意《服务条款》和《隐私政策》');
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      PetToast.warning(context, '请先输入手机号');
      return;
    }
    final nationNum = _selectedCountry.dialCode;
    if (_isSmsLogin) {
      final code = _codeCtrl.text.trim();
      if (code.isEmpty) {
        PetToast.warning(context, '请输入验证码');
        return;
      }
      ref.read(authControllerProvider.notifier)
          .loginWithSms(phone: phone, code: code, nationNum: nationNum);
    } else {
      final password = _passwordCtrl.text.trim();
      if (password.isEmpty) {
        PetToast.warning(context, '请输入密码');
        return;
      }
      ref.read(authControllerProvider.notifier)
          .loginWithPwd(phone: phone, password: password, nationNum: nationNum);
    }
  }

  // ── 打开国家选择器底部弹窗 ──────────────────────────────────
  void _showCountryPicker(List<CountryInfo> countries) {
    _searchCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(
        countries: countries,
        selected: _selectedCountry,
        searchCtrl: _searchCtrl,
        onSelect: (c) {
          setState(() => _selectedCountry = c);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final countriesAsync = ref.watch(countryListProvider);

    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next.status == AuthStatus.loggedIn) {
        debugPrint('[LoginPage] 登录成功，等待路由守卫跳转');
      } else if (next.status == AuthStatus.error && next.errorMessage != null) {
        PetToast.error(context, next.errorMessage!);
        if (!_isSmsLogin && (next.errorMessage!.contains('未注册') || next.errorMessage!.contains('验证码登录'))) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('该手机号未注册，请先用验证码登录/注册',
                  style: TextStyle(fontFamily: AppFonts.primary)),
              action: SnackBarAction(
                label: '切换验证码',
                onPressed: () => setState(() => _isSmsLogin = true),
              ),
              duration: Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          clipBehavior: Clip.hardEdge,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 56, // 减去两侧 padding
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo ────────────────────────────────────
              Row(children: [
                Icon(Icons.pets_rounded, color: AppColors.primary, size: 36),
                SizedBox(width: 10),
                Text('萌宠智伴',
                    style: TextStyle(fontFamily: AppFonts.primary,
                        fontSize: 28, fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ]),

              SizedBox(height: 32),

              // ── 标题 ─────────────────────────────────────
              Text('欢迎回来 👋',
                  style: TextStyle(fontFamily: AppFonts.primary,
                      fontSize: 28, fontWeight: FontWeight.w800,
                      color: AppColors.onSurface)),
              SizedBox(height: 20),


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
                  SizedBox(width: 24),
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
              SizedBox(height: 24),

              // ── 手机号输入框（带国家选择器前缀）─────────────
              const _FieldLabel('手机号'),
              SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: [],
                style: TextStyle(fontFamily: AppFonts.primary,
                    fontSize: 15, color: AppColors.onSurface),
                decoration: _inputDecorationWithCountry(
                  hint: '请输入手机号',
                  country: _selectedCountry,
                  onCountryTap: () => countriesAsync.whenData(
                      (list) => _showCountryPicker(list)),
                ),
              ),

              SizedBox(height: 20),

              // ── 验证码 / 密码输入框 ────────────────────────────────
              if (_isSmsLogin) ...[
                const _FieldLabel('验证码'),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        style: TextStyle(fontFamily: AppFonts.primary,
                            fontSize: 15, color: AppColors.onSurface),
                        decoration: _inputDecoration(
                          hint: '请输入验证码',
                          prefixIcon: Icons.message_outlined,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
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
                SizedBox(height: 8),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: TextStyle(fontFamily: AppFonts.primary,
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
                SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: AppColors.onSurfaceVariant),
                  SizedBox(width: 4),
                  Text('首次登录初始密码为 123456，建议登录后修改',
                      style: TextStyle(fontFamily: AppFonts.primary,
                          fontSize: 11, color: AppColors.onSurfaceVariant)),
                ]),
              ],

              SizedBox(height: 28),

              // ── 协议勾选 ──────────────────────────────────
              _AgreementRow(
                agreed: _agreedToTerms,
                onChanged: (v) => setState(() => _agreedToTerms = v),
              ),

              SizedBox(height: 20),

              // ── 登录按钮 ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _agreedToTerms
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.45),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    elevation: 0,
                    // 不固定高度，改用 minimumSize + 垂直 padding 让字体自然展开
                    minimumSize: const Size(double.infinity, 54),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          '登录 / 注册',
                          style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            // 固定行高为 1.0 防止自定义字体 ascender/descender 被裁
                            height: 1.0,
                          ),
                          strutStyle: const StrutStyle(
                            forceStrutHeight: true,
                            height: 1.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
          ), // ConstrainedBox
        ),
      ),
    );
  }

  InputDecoration _inputDecorationWithCountry({
    required String hint,
    required CountryInfo country,
    required VoidCallback onCountryTap,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: AppFonts.primary,
            fontSize: 14, color: AppColors.onSurfaceVariant.withOpacity(0.6)),
        prefixIcon: GestureDetector(
          onTap: onCountryTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(country.flagEmoji,
                    style: TextStyle(fontSize: 20)),
                Icon(Icons.arrow_drop_down_rounded,
                    size: 14, color: AppColors.onSurfaceVariant),
              ],
            ),
          ),
        ),
        prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: AppFonts.primary,
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

// ══════════════════════════════════════════════════════════════
//  协议勾选行 — _AgreementRow
// ══════════════════════════════════════════════════════════════
class _AgreementRow extends StatelessWidget {
  final bool agreed;
  final ValueChanged<bool> onChanged;

  const _AgreementRow({required this.agreed, required this.onChanged});

  void _openDoc(BuildContext context, String title, String assetPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocReaderPage(title: title, assetPath: assetPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 点击整行切换勾选状态（方便拇指点击）
      onTap: () => onChanged(!agreed),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 自定义圆形 Checkbox
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: agreed ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: agreed
                    ? AppColors.primary
                    : AppColors.outline.withOpacity(0.5),
                width: 1.8,
              ),
            ),
            child: agreed
                ? const Icon(Icons.check_rounded,
                    size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          // 文字（含可点击链接）
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12.5,
                  color: AppColors.onSurfaceVariant,
                  height: 1.6,
                ),
                children: [
                  const TextSpan(text: '我已阅读并同意'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: () => _openDoc(
                        context,
                        '服务条款',
                        'assets/docs/服务条款.html',
                      ),
                      child: Text(
                        '《服务条款》',
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: '和'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: () => _openDoc(
                        context,
                        '隐私政策',
                        'assets/docs/隐私政策.html',
                      ),
                      child: Text(
                        '《隐私政策》',
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: '，并授权使用手机号注册/登录'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 国家选择器底部弹窗 ─────────────────────────────────────────
class _CountryPickerSheet extends StatefulWidget {
  final List<CountryInfo> countries;
  final CountryInfo selected;
  final TextEditingController searchCtrl;
  final ValueChanged<CountryInfo> onSelect;

  const _CountryPickerSheet({
    required this.countries,
    required this.selected,
    required this.searchCtrl,
    required this.onSelect,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  late List<CountryInfo> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
    widget.searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    widget.searchCtrl.removeListener(_onSearch);
    super.dispose();
  }

  void _onSearch() {
    final q = widget.searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.countries
          : widget.countries.where((c) =>
              c.country.toLowerCase().contains(q) ||
              c.countryEn.toLowerCase().contains(q) ||
              c.phoneId.contains(q) ||
              c.countryId.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── 顶部把手 ──
          SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('选择国家/地区',
                style: TextStyle(fontFamily: AppFonts.primary,
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.onSurface)),
          ),
          SizedBox(height: 12),
          // ── 搜索框 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: widget.searchCtrl,
              autofocus: true,
              style: TextStyle(fontFamily: AppFonts.primary, fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索国家名称或区号',
                hintStyle: TextStyle(fontFamily: AppFonts.primary,
                    fontSize: 14, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(height: 8),
          Divider(height: 1),
          // ── 列表 ──
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text('未找到相关国家',
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            color: Colors.grey.shade400)),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final c = _filtered[i];
                      final isSelected = c == widget.selected;
                      return ListTile(
                        leading: Text(c.flagEmoji,
                            style: TextStyle(fontSize: 22)),
                        title: Text(c.country,
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.onSurface)),
                        subtitle: Text(c.countryEn,
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                        trailing: Text(
                          c.phoneId,
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant),
                        ),
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withOpacity(0.05),
                        onTap: () => widget.onSelect(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(fontFamily: AppFonts.primary,
            fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.onSurface));
  }
}
