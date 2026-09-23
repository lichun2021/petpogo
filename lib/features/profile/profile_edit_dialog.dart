import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/error_presenter.dart';
import '../../shared/widgets/modal_header.dart';
import '../auth/controller/auth_controller.dart';

class ProfileEditDialog extends ConsumerStatefulWidget {
  const ProfileEditDialog({super.key});
  @override
  ConsumerState<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends ConsumerState<ProfileEditDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _birthday = TextEditingController();
  int _gender = 0;
  bool _loading = true;
  bool _ready = false;
  bool _saving = false;
  bool _emailSupported = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/sdkapi/user/profile');
      if (!mounted) return;
      _name.text = data['nickname'] as String? ?? '';
      _email.text = data['email'] as String? ?? '';
      _birthday.text = (data['birthday'] as String? ?? '').split('T').first;
      final gender = (data['gender'] as num?)?.toInt() ?? 0;
      _gender = [0, 1, 2].contains(gender) ? gender : 0;
      _emailSupported = data.containsKey('email');
      _ready = true;
    } catch (e) {
      if (!mounted) return;
      _error = ErrorPresenter.message(e, fallback: '资料加载失败，请重试');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickBirthday() async {
    FocusScope.of(context).unfocus();
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate = DateTime(1900);
    var selected = DateTime.tryParse(_birthday.text) ?? DateTime(2000, 1, 1);
    if (selected.isBefore(firstDate)) selected = firstDate;
    if (selected.isAfter(today)) selected = today;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (pickerContext) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: ModalHeader(
              title: '选择生日',
              confirmLabel: '确定生日',
              onConfirm: () => Navigator.pop(pickerContext, selected),
            ),
          ),
          SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              dateOrder: DatePickerDateOrder.ymd,
              initialDateTime: selected,
              minimumDate: firstDate,
              maximumDate: today,
              minimumYear: 1900,
              maximumYear: today.year,
              onDateTimeChanged: (date) => selected = date,
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
    if (mounted && picked != null) {
      setState(
          () => _birthday.text = picked.toIso8601String().split('T').first);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
      );

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
          nickname: _name.text.trim(),
          gender: _gender,
          birthday: _birthday.text.trim(),
          email: _emailSupported ? _email.text.trim() : null);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = ErrorPresenter.message(e, fallback: '保存失败，请重试');
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _birthday.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormModal(
        title: '个人资料',
        busy: _saving,
        onConfirm: _loading || !_ready ? null : _save,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('昵称'),
                      TextFormField(
                          key: const ValueKey('profile-name'),
                          controller: _name,
                          enabled: !_saving,
                          maxLength: 30,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                              hintText: '输入昵称',
                              counterText: '',
                              prefixIcon: Icon(Icons.person_outline_rounded)),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? '请输入昵称' : null),
                      const SizedBox(height: 16),
                      _label('性别'),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final entry in {0: '不透露', 1: '男', 2: '女'}.entries)
                          ChoiceChip(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              label: Text(entry.value),
                              selected: _gender == entry.key,
                              onSelected: _saving
                                  ? null
                                  : (_) => setState(() => _gender = entry.key)),
                      ]),
                      const SizedBox(height: 20),
                      _label('生日'),
                      TextFormField(
                          key: const ValueKey('profile-birthday'),
                          controller: _birthday,
                          enabled: !_saving,
                          readOnly: true,
                          onTap: _pickBirthday,
                          canRequestFocus: false,
                          decoration: InputDecoration(
                              hintText: '选择生日（选填）',
                              prefixIcon: const Icon(Icons.cake_outlined),
                              suffixIcon: _birthday.text.isEmpty
                                  ? const Icon(Icons.calendar_month_outlined)
                                  : IconButton(
                                      tooltip: '清除生日',
                                      onPressed: () =>
                                          setState(() => _birthday.clear()),
                                      icon: const Icon(Icons.close_rounded,
                                          size: 18))),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final raw = v.trim();
                            final date = DateTime.tryParse(raw);
                            if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw) ||
                                date == null ||
                                date.toIso8601String().split('T').first !=
                                    raw ||
                                date.isAfter(DateTime.now()) ||
                                date.year < 1900) {
                              return '请输入有效生日，如 1995-06-18';
                            }
                            return null;
                          }),
                      const SizedBox(height: 20),
                      _label('邮箱'),
                      TextFormField(
                          key: const ValueKey('profile-email'),
                          controller: _email,
                          enabled: !_saving && _emailSupported,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          maxLength: 254,
                          decoration: InputDecoration(
                              hintText: '选填',
                              counterText: '',
                              helperText:
                                  _emailSupported ? null : '邮箱功能待服务更新后开放',
                              prefixIcon:
                                  const Icon(Icons.mail_outline_rounded)),
                          validator: (v) => v == null ||
                                  v.trim().isEmpty ||
                                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(v.trim())
                              ? null
                              : '请输入有效邮箱'),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!, style: TextStyle(color: AppColors.error)),
                        if (!_ready)
                          TextButton(
                              onPressed: _load, child: const Text('重新加载')),
                      ],
                    ])),
      );
}
