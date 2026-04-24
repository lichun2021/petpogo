import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../app.dart' show AppL10nX;
import 'widgets/device_card.dart';
import 'widgets/ai_translate_panel.dart';
import 'widgets/ai_image_panel.dart';
import 'widgets/no_device_banner.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final bool _hasDevice = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.secondaryContainer,
        foregroundColor: AppColors.onSecondaryContainer,
        elevation: 0,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: CustomScrollView(
        slivers: [
          // ── AppBar 固定顶部 ──────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: AppColors.surface.withOpacity(0.95),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            title: const SizedBox.shrink(), // 隐藏标题
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  child: Icon(Icons.person_rounded,
                      color: AppColors.onSurfaceVariant, size: 20),
                ),
              ),
            ],
          ),

          // ── 主内容 ──────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── 问候语 ─────────────────────────────
                Text(
                  l10n.homeGreeting,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.homeSubtitle,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                // ── AI 语音识别面板 ─────────────────────
                const AiTranslatePanel(),

                const SizedBox(height: 16),

                // ── AI 图像情绪识别面板 ─────────────────
                const AiImagePanel(),

                const SizedBox(height: 28),

                // ── 设备区 ─────────────────────────────
                if (_hasDevice) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.homeConnectedDevices,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        l10n.homeDevicesActive(2),
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const DeviceCard(
                    deviceType: '项圈',
                    deviceName: '宠物项圈',
                    isOnline: true,
                    battery: 85,
                    location: '南山区科技园',
                  ),
                  const SizedBox(height: 12),
                  const DeviceCard(
                    deviceType: '机器人',
                    deviceName: '宠物机器人',
                    isOnline: true,
                    battery: 72,
                    location: '南山区科技园',
                    nowPlaying: '轻音乐 - 舒缓放松',
                  ),
                ] else ...[
                  const NoDeviceBanner(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
