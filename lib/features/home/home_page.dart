import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import 'widgets/device_card.dart';
import 'widgets/ai_translate_panel.dart';
import 'widgets/no_device_banner.dart';

/// 首页 — 设计稿 Image 1/2 还原
/// 布局：玻璃态 AppBar → 问候语 → AI 翻译面板 → 设备列表
/// 全局：surface 背景，无分割线
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // TODO: 从 Riverpod provider 读取
  final bool _hasDevice = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      // ── FAB: 添加设备 ───────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.secondaryContainer,
        foregroundColor: AppColors.onSecondaryContainer,
        elevation: 0,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: CustomScrollView(
        slivers: [
          // ── AppBar（玻璃态）────────────────────────
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.surface.withOpacity(0.8),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            flexibleSpace: ClipRect(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.8),
                ),
              ),
            ),
            title: Row(
              children: [
                Icon(Icons.pets_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 6),
                Text(
                  'PetPogo',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  child: Icon(Icons.person_rounded, color: AppColors.onSurfaceVariant, size: 20),
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
                const Text(
                  'Hello, Human!',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to understand what Buddy is thinking today?',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                // ── AI 翻译面板 ────────────────────────
                const AiTranslatePanel(),

                const SizedBox(height: 28),

                // ── 设备区 ─────────────────────────────
                if (_hasDevice) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Connected Devices',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        '2 Devices Active',
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
                  DeviceCard(
                    deviceType: 'KeyTracker',
                    deviceName: 'KeyTracker',
                    isOnline: true,
                    battery: 85,
                    location: '南山区科技园',
                  ),
                  const SizedBox(height: 12),
                  DeviceCard(
                    deviceType: 'PetPhone',
                    deviceName: 'PetPhone',
                    isOnline: true,
                    battery: 72,
                    location: '南山区科技园',
                    nowPlaying: 'Calming Pet Melodies',
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
