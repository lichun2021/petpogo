import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../features/auth/controller/auth_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import 'data/models/share_link_model.dart';
import 'data/repository/share_repository.dart';

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
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    if (auth.isLoggedIn && !_started) {
      _started = true;
      Future.microtask(_resolve);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.go(AppRoutes.home),
                icon: Icon(Icons.close_rounded, color: AppColors.onSurface),
              ),
              const Spacer(),
              if (auth.isRestoring || _loading)
                const _LoadingCard()
              else if (!auth.isLoggedIn)
                _LoginCard(type: widget.type)
              else if (_data != null)
                _ResultCard(data: _data!)
              else
                _ErrorCard(
                  message: _error ?? '分享内容打开失败',
                  onRetry: _resolve,
                ),
              const Spacer(flex: 2),
            ],
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
  final String? type;
  const _LoginCard({this.type});

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
            label: '去登录',
            onTap: () => context.go(AppRoutes.login),
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

  const _Preview({
    required this.imageUrl,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      _typeIcon(type),
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
            borderRadius: BorderRadius.circular(18),
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
