import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_colors.dart';
import '../../app.dart' show AppL10nX;
import '../device/data/repository/device_repository.dart';
import '../device/device_list_page.dart';
import '../device/device_detail_page.dart';
import '../bind_device/device_type_sheet.dart';
import 'widgets/ai_translate_panel.dart';
import 'widgets/ai_image_panel.dart';
import 'widgets/no_device_banner.dart';
import 'widgets/pet_mood_section.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.surface,
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
            automaticallyImplyLeading: false,
            title: const SizedBox.shrink(), // 隐藏标题
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _ScanButton(),
            ),
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

                // ── 宠物情绪卡片 ────────────────────────
                const PetMoodSection(),

                const SizedBox(height: 28),

                // ── 设备区（真实数据）────────────────────
                _HomeDeviceSection(),

              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 首页设备区 ────────────────────────────────────────────
class _HomeDeviceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceListProvider);
    final l10n  = context.l10n;
    final onlineCount = state.devices.where((d) => d.isOnline).length;

    if (state.isLoading && state.devices.isEmpty) {
      return const Center(
        heightFactor: 1,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
        ),
      );
    }

    if (state.devices.isEmpty) {
      return const NoDeviceBanner();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l10n.homeConnectedDevices,
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 20,
                fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppColors.onSurface)),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceListPage())),
          child: Text(l10n.homeDevicesActive(onlineCount),
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
      ]),
      const SizedBox(height: 14),
      ...state.devices.take(3).expand((d) => [
        _HomeDeviceCard(device: d),
        const SizedBox(height: 12),
      ]),
      if (state.devices.length > 3)
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceListPage())),
          child: Center(child: Text('查看全部 ${state.devices.length} 台设备',
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                  fontWeight: FontWeight.w600, color: AppColors.primary))),
        ),
    ]);
  }
}

// ── 首页设备小卡片 ─────────────────────────────────────────
class _HomeDeviceCard extends StatelessWidget {
  final dynamic device; // DeviceModel
  const _HomeDeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => DeviceDetailPage(mac: device.mac, name: device.displayName),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(
                color: device.isOnline ? AppColors.primary.withOpacity(0.12) : Colors.black12,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.router_rounded, size: 22,
                  color: device.isOnline ? AppColors.primary : AppColors.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(device.displayName, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            Row(children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: device.isOnline ? const Color(0xFF4ADE80) : AppColors.onSurfaceVariant,
                    shape: BoxShape.circle,
                  )),
              const SizedBox(width: 5),
              Text(device.isOnline ? '在线' : '离线',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                      fontWeight: FontWeight.w700, color: device.isOnline ? AppColors.secondary : AppColors.onSurfaceVariant)),
            ]),
          ])),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant, size: 20),
        ]),
      ),
    );
  }
}

// ── 左上角扫描按钮（先选类型再扫码） ────────────────────────
class _ScanButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.qr_code_scanner_rounded),
      color: AppColors.primary,
      iconSize: 26,
      onPressed: () async {
        HapticFeedback.mediumImpact();
        final ok = await DeviceTypeSheet.show(context);
        if (ok) ref.read(deviceListProvider.notifier).load();
      },
    );
  }
}
