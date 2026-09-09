import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart' show appRouter;
import '../../core/router/app_routes.dart';
import '../../features/auth/controller/auth_controller.dart';
import '../../features/device/data/repository/device_repository.dart';
import '../../features/device/data/models/device_product_model.dart';
import '../../features/pet/data/repository/pet_share_repository.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/pet_toast.dart';
import 'data/models/share_link_model.dart';
import 'data/repository/share_repository.dart';
import '../../shared/theme/app_tokens.dart';

class ShareLandingPage extends ConsumerStatefulWidget {
  final String code;
  final String? type;

  const ShareLandingPage({
    super.key,
    required this.code,
    this.type,
  });

  @override
  ConsumerState<ShareLandingPage> createState() => _ShareLandingPageState();
}

class _ShareLandingPageState extends ConsumerState<ShareLandingPage> {
  bool _loading = false;
  bool _started = false;
  ShareResolveResult? _data;
  String? _error;

  @override
  void didUpdateWidget(covariant ShareLandingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code == widget.code && oldWidget.type == widget.type) return;
    _started = false;
    _data = null;
    _error = null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    if (auth.isLoggedIn && !_started) {
      _started = true;
      Future.microtask(_resolve);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical -
                  38,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => context.go(AppRoutes.home),
                  icon: Icon(Icons.close_rounded, color: AppColors.onSurface),
                ),
                const SizedBox(height: 56),
                if (auth.isRestoring || _loading)
                  const _LoadingCard()
                else if (!auth.isLoggedIn)
                  _LoginCard(code: widget.code, type: widget.type)
                else if (_data != null)
                  switch (_data!.type) {
                    'device' => _DeviceShareCard(data: _data!),
                    'pet' => _PetShareCard(data: _data!),
                    _ => _ResultCard(data: _data!),
                  }
                else
                  _ErrorCard(
                    message: _error ?? '分享内容打开失败',
                    onRetry: _resolve,
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resolve() async {
    if (widget.code.trim().isEmpty) {
      setState(() => _error = '分享链接缺少分享码');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref
        .read(shareRepositoryProvider)
        .resolveShare(widget.code.trim());
    if (!mounted) return;

    result.when(
      success: (data) {
        setState(() {
          _data = data;
          _loading = false;
        });
      },
      failure: (error) {
        setState(() {
          _error = error.userMessage;
          _loading = false;
        });
      },
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(
            '正在打开分享内容',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final String code;
  final String? type;
  const _LoginCard({required this.code, this.type});

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBubble(icon: Icons.lock_open_rounded),
          const SizedBox(height: 18),
          Text(
            '登录后查看${_typeLabel(type)}',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '为了保护宠物和设备隐私，分享内容需要登录后打开。',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: '登录并继续',
            onTap: () => context.go(
              AppRoutes.loginWithReturnTo(
                AppRoutes.shareLanding(code: code, type: type),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ShareResolveResult data;
  const _ResultCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Preview(imageUrl: data.imageUrl, type: data.type),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title.isNotEmpty ? data.title : '分享已打开',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _typeLabel(data.type),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            data.description.isNotEmpty ? data.description : '分享内容已经同步到 App。',
            style: TextStyle(
              fontSize: 15,
              height: 1.65,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: '回到首页',
            onTap: () => context.go(AppRoutes.home),
          ),
        ],
      ),
    );
  }
}

// ── 宠物分享卡片（接收者）────────────────────────────────────
class _PetShareCard extends ConsumerStatefulWidget {
  final ShareResolveResult data;
  const _PetShareCard({required this.data});

  @override
  ConsumerState<_PetShareCard> createState() => _PetShareCardState();
}

class _PetShareCardState extends ConsumerState<_PetShareCard> {
  bool _accepting = false;
  bool _accepted = false;
  String? _error;

  String get _order => widget.data.payload['order']?.toString() ?? '';
  String get _petName {
    final name = widget.data.payload['petName']?.toString().trim() ?? '';
    return name.isNotEmpty
        ? name
        : (widget.data.title.isNotEmpty ? widget.data.title : '这只宠物');
  }

  bool get _expired =>
      widget.data.expiresAt != null &&
      !widget.data.expiresAt!.isAfter(DateTime.now());

  Future<void> _accept() async {
    if (_accepting || _accepted || _order.isEmpty || _expired) return;
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      await ref.read(petShareRepositoryProvider).acceptShare(_order);
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _accepted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.data.createdByCurrentUser;
    final missingOrder = _order.isEmpty;
    final unavailable = missingOrder || _expired || owner;
    final title = _accepted
        ? '已接受宠物邀请'
        : owner
            ? '这是你发出的宠物邀请'
            : _expired
                ? '宠物邀请已失效'
                : missingOrder
                    ? '宠物邀请信息不完整'
                    : '邀请你共同管理「$_petName」';
    final description = _accepted
        ? '你现在可以在“我的宠物”中查看这只宠物。'
        : owner
            ? '这是你创建的分享链接，不能重复接受自己的邀请。'
            : _expired
                ? '该邀请已过期，请联系邀请人重新分享。'
                : missingOrder
                    ? '分享口令缺失，无法接受该邀请，请让邀请人重新生成链接。'
                    : '接受后可在“我的宠物”中查看并共同管理，不会改变宠物所有权。';

    return _ShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Preview(imageUrl: widget.data.imageUrl, type: 'pet'),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _accepted ? '宠物共享成功' : '宠物共享邀请',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            _accepted ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              height: 1.65,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (!_accepted && !owner && !_expired && !missingOrder) ...[
            const SizedBox(height: 16),
            _ShareInfoRow(
              icon: Icons.group_outlined,
              label: '身份',
              value: '共享成员',
            ),
            _ShareInfoRow(
              icon: Icons.visibility_outlined,
              label: '权限',
              value: '查看和共同管理宠物',
            ),
            _ShareInfoRow(
              icon: Icons.lock_outline_rounded,
              label: '所有权',
              value: '不会改变宠物所有权',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style:
                  TextStyle(color: AppColors.error, fontSize: 13, height: 1.4),
            ),
          ],
          const SizedBox(height: 24),
          if (_accepted)
            _PrimaryButton(
              label: '查看我的宠物',
              onTap: () {
                context.go(AppRoutes.profile);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  appRouter.push(AppRoutes.petList);
                });
              },
            )
          else if (unavailable)
            _PrimaryButton(
              label: owner ? '回到首页' : '返回首页',
              onTap: () => context.go(AppRoutes.home),
            )
          else if (_accepting)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('正在接受…', style: TextStyle(color: AppColors.primary)),
                  ],
                ),
              ),
            )
          else
            _PrimaryButton(label: '接受宠物邀请', onTap: _accept),
        ],
      ),
    );
  }
}

class _ShareInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ShareInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 9),
          Text('$label：', style: TextStyle(color: AppColors.onSurfaceVariant)),
          Expanded(
            child: Text(value, style: TextStyle(color: AppColors.onSurface)),
          ),
        ],
      ),
    );
  }
}

// ── 设备分享卡片（接收者）────────────────────────────────────
/// 判断设备是否已添加：已添加 → 进入设备；未添加 → 确认后凭口令绑定
class _DeviceShareCard extends ConsumerStatefulWidget {
  final ShareResolveResult data;
  const _DeviceShareCard({required this.data});

  @override
  ConsumerState<_DeviceShareCard> createState() => _DeviceShareCardState();
}

class _DeviceShareCardState extends ConsumerState<_DeviceShareCard> {
  bool _accepting = false;

  String get _mac => widget.data.payload['mac']?.toString() ?? '';
  String get _deviceId => widget.data.payload['deviceId']?.toString() ?? '';
  String get _order => widget.data.payload['order']?.toString() ?? '';
  String get _productKey => widget.data.payload['productKey']?.toString() ?? '';
  DeviceProductType get _productType =>
      DeviceProductType.fromProductKey(_productKey);
  String get _productTypeName {
    final name =
        widget.data.payload['productTypeName']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : _productType.displayName;
  }

  String get _deviceName {
    final n = widget.data.payload['deviceName']?.toString() ?? '';
    if (n.isNotEmpty) return n;
    return widget.data.title.isNotEmpty ? widget.data.title : '智能设备';
  }

  bool get _alreadyAdded {
    final devices = ref.watch(deviceListProvider).devices;
    return devices.any((d) =>
        (_mac.isNotEmpty && d.mac.toLowerCase() == _mac.toLowerCase()) ||
        (_deviceId.isNotEmpty && d.deviceId == _deviceId));
  }

  void _goDevice() {
    if (_mac.isEmpty) {
      context.go(AppRoutes.home);
      return;
    }
    // 先 go('/') 确保底层有首页作为返回目标，再 push 设备详情页
    // 避免直接 go(deviceDetail) 后返回黑屏（导航栈为空）
    context.go(AppRoutes.home);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.push(AppRoutes.deviceDetail(_mac));
    });
  }

  Future<void> _accept() async {
    if (_accepting) return;
    if (_order.isEmpty) {
      PetToast.error(context, '分享口令缺失，无法添加');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('添加设备',
            style: TextStyle(
                fontFamily: AppFonts.primary, fontWeight: FontWeight.w700)),
        content: Text('确定将「$_deviceName」添加到你的账户吗？',
            style: TextStyle(fontFamily: AppFonts.primary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('确认添加'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _accepting = true);
    try {
      await ref.read(deviceRepositoryProvider).acceptShare(_order);
      await ref.read(deviceListProvider.notifier).load();
      if (!mounted) return;
      PetToast.success(context, '已添加「$_deviceName」');
      _goDevice();
    } catch (e) {
      if (!mounted) return;
      setState(() => _accepting = false);
      final msg = e.toString().replaceAll('Exception: ', '');
      PetToast.error(context, msg.contains('[iPet]') ? msg : '添加失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final added = _alreadyAdded;
    return _ShellCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Preview(
                imageUrl: widget.data.imageUrl,
                type: 'device',
                deviceProductType: _productType,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _deviceName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      added ? '已在你的设备列表' : '设备分享',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _productTypeName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            added
                ? '你已经是该设备的成员，可直接进入查看和控制。'
                : (widget.data.description.isNotEmpty
                    ? widget.data.description
                    : '将设备添加到你的账户，即可一起查看和控制。'),
            style: TextStyle(
              fontSize: 15,
              height: 1.65,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (added)
            _PrimaryButton(label: '进入设备', onTap: _goDevice)
          else if (_accepting)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            )
          else
            _PrimaryButton(label: '添加该设备', onTap: _accept),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBubble(icon: Icons.error_outline_rounded),
          const SizedBox(height: 18),
          Text(
            '分享暂时打不开',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(label: '重新加载', onTap: onRetry),
        ],
      ),
    );
  }
}

class _ShellCard extends StatelessWidget {
  final Widget child;
  const _ShellCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  const _IconBubble({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: AppColors.primary, size: 30),
    );
  }
}

class _Preview extends StatelessWidget {
  final String imageUrl;
  final String type;
  final DeviceProductType deviceProductType;

  const _Preview({
    required this.imageUrl,
    required this.type,
    this.deviceProductType = DeviceProductType.unknown,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      type == 'device'
          ? switch (deviceProductType) {
              DeviceProductType.collar => Icons.pets_rounded,
              DeviceProductType.robot => Icons.smart_toy_rounded,
              DeviceProductType.unknown => Icons.memory_rounded,
            }
          : _typeIcon(type),
      color: AppColors.primary,
      size: 30,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 78,
        height: 78,
        color: AppColors.primaryContainer,
        child: imageUrl.isEmpty
            ? placeholder
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.pillRadius,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

String _typeLabel(String? type) {
  switch (type) {
    case 'pet':
      return '宠物分享';
    case 'device':
      return '设备分享';
    case 'location':
      return '位置分享';
    case 'capture':
      return 'AI 抓拍';
    case 'greeting':
      return '打招呼记录';
    default:
      return '分享内容';
  }
}

IconData _typeIcon(String type) {
  switch (type) {
    case 'device':
      return Icons.memory_rounded;
    case 'location':
      return Icons.location_on_rounded;
    case 'capture':
      return Icons.camera_alt_rounded;
    case 'greeting':
      return Icons.record_voice_over_rounded;
    default:
      return Icons.pets_rounded;
  }
}
