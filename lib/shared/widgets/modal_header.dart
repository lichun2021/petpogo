import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// 弹窗的确认操作统一放在左侧；关闭不提交编辑。
class ModalHeader extends StatelessWidget {
  const ModalHeader(
      {super.key,
      required this.title,
      this.onConfirm,
      this.busy = false,
      this.showConfirm = false,
      this.confirmLabel = '保存',
      this.onClose});

  final String title;
  final VoidCallback? onConfirm;
  final bool busy;
  final bool showConfirm;
  final String confirmLabel;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 48,
            height: 48,
            child: busy
                ? Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.statusOnlineStrong)))
                : !showConfirm && onConfirm == null
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: confirmLabel,
                        onPressed: onConfirm,
                        color: AppColors.statusOnlineStrong,
                        disabledColor: AppColors.outline,
                        icon: const Icon(Icons.check_rounded, size: 28))),
        Expanded(
            child: Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface))),
        IconButton(
            tooltip: '关闭',
            onPressed:
                busy ? null : onClose ?? () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded,
                size: 21, color: AppColors.onSurfaceVariant)),
      ]);
}

/// Dialog 本身处理键盘避让，正文独立滚动，操作栏始终可见。
class FormModal extends StatelessWidget {
  const FormModal(
      {super.key,
      required this.title,
      required this.child,
      this.onConfirm,
      this.onClose,
      this.busy = false,
      this.confirmLabel = '保存'});
  final String title;
  final Widget child;
  final VoidCallback? onConfirm;
  final VoidCallback? onClose;
  final bool busy;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !busy,
        child: Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: ModalHeader(
                        title: title,
                        onConfirm: onConfirm,
                        busy: busy,
                        onClose: onClose,
                        showConfirm: true,
                        confirmLabel: confirmLabel)),
                Flexible(
                    child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: AbsorbPointer(absorbing: busy, child: child))),
              ])),
        ),
      );
}
