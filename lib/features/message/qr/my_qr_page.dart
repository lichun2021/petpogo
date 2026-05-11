import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/pet_toast.dart';
import '../../auth/controller/auth_controller.dart';


/// 我的二维码名片页
/// QR Data 格式: petpogo://user/{userId}
class MyQrCodePage extends ConsumerWidget {
  const MyQrCodePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final userId   = user?.id ?? '';
    final nickname = user?.name ?? '用户';
    final avatar   = user?.avatar ?? '';
    final qrData   = 'petpogo://user/$userId';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '我的二维码',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 18,
            fontWeight: FontWeight.w700, color: AppColors.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.onSurface),
            onPressed: () {
              HapticFeedback.lightImpact();
              PetToast.show(context, '分享功能即将上线 🐾');
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── 名片容器 ──────────────────────────────────
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 340),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.12),
                      blurRadius: 40,
                      spreadRadius: -4,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 顶部品牌色渐变
                    // Container(
                    //   height: 80,
                    //   decoration: BoxDecoration(
                    //     gradient: LinearGradient(
                    //       colors: [AppColors.primary, AppColors.primary.withOpacity(0.75)],
                    //       begin: Alignment.topLeft,
                    //       end: Alignment.bottomRight,
                    //     ),
                    //     borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    //   ),
                    //   child: const Center(
                    //     child: Text('🐾 PetPogo',
                    //       style: TextStyle(
                    //         fontFamily: 'Plus Jakarta Sans', fontSize: 20,
                    //         fontWeight: FontWeight.w800, color: Colors.white,
                    //         letterSpacing: -0.5,
                    //       ),
                    //     ),
                    //   ),
                    // ),

                    // 头像（跨越分隔线）
                    Transform.translate(
                      offset: const Offset(0, -36),
                      child: Column(
                        children: [
                          _buildAvatar(avatar, nickname),
                          const SizedBox(height: 8),
                          Text(
                            nickname,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans', fontSize: 18,
                              fontWeight: FontWeight.w700, color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'PetPogo 宠物主人',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // QR 码
                    Transform.translate(
                      offset: const Offset(0, -20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.outlineVariant.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: userId.isNotEmpty
                              ? QrImageView(
                                  data: qrData,
                                  version: QrVersions.auto,
                                  size: 200,
                                  backgroundColor: Colors.transparent,
                                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                                  embeddedImage: const AssetImage('assets/icons/app_icon.png'),
                                  embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(30, 30)),
                                )
                              : const SizedBox(
                                  width: 200, height: 200,
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                        ),
                      ),
                    ),

                    // 提示文字
                    Transform.translate(
                      offset: const Offset(0, -12),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Text(
                          '扫描上方二维码，添加我为好友',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl, String name) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: avatarUrl.isNotEmpty
          ? CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(avatarUrl),
            )
          : CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
    );
  }
}
