import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../device/data/repository/device_repository.dart';
import '../device/data/models/device_model.dart';
import '../device/device_detail_page.dart';
import '../bind_device/scan_qr_page.dart';

// ── 设备列表页 ────────────────────────────────────────────
class DeviceListPage extends ConsumerWidget {
  const DeviceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceListProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('我的设备',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          if (state.isLoading)
            const Padding(padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.onSurfaceVariant,
              onPressed: () => ref.read(deviceListProvider.notifier).load(),
            ),
        ],
      ),
      body: _buildBody(context, ref, state),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ScanQrPage(deviceType: '智能宠物设备'),
              ));
              // 绑定成功后刷新列表
              ref.read(deviceListProvider.notifier).load();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
            label: const Text('扫码绑定新设备',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, DeviceListState state) {
    if (state.isLoading && state.devices.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5));
    }
    if (state.errorMessage != null && state.devices.isEmpty) {
      return _buildError(context, ref, state.errorMessage!);
    }
    if (state.devices.isEmpty) {
      return _buildEmpty(context, ref);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(deviceListProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: state.devices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _DeviceCard(device: state.devices[i]),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.devices_other_rounded, size: 72, color: AppColors.onSurfaceVariant.withOpacity(0.4)),
      const SizedBox(height: 16),
      const Text('还没有绑定设备', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
      const SizedBox(height: 8),
      const Text('点击下方按钮添加设备', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
          fontSize: 13, color: AppColors.onSurfaceVariant)),
    ]));
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String msg) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(msg, textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => ref.read(deviceListProvider.notifier).load(),
          child: const Text('重试'),
        ),
      ]),
    ));
  }

  void _showBindSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BindOptionsSheet(ref: ref),
    );
  }
}

// ── 设备卡片 ──────────────────────────────────────────────
class _DeviceCard extends StatelessWidget {
  final DeviceModel device;
  const _DeviceCard({required this.device});

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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1e1e2e),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: device.isOnline ? AppColors.primary.withOpacity(0.18) : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.router_rounded,
                color: device.isOnline ? AppColors.primaryContainer : Colors.white38, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(device.displayName, style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text('MAC: ${device.mac}', style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                fontSize: 11, color: Colors.white.withOpacity(0.4))),
            const SizedBox(height: 6),
            Row(children: [
              Container(width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: device.isOnline ? const Color(0xFF4ADE80) : Colors.white30,
                    shape: BoxShape.circle,
                  )),
              const SizedBox(width: 5),
              Text(device.isOnline ? '在线' : '离线',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: device.isOnline ? const Color(0xFF4ADE80) : Colors.white38)),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: device.isOnline ? const Color(0xFF4ADE80).withOpacity(0.15) : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(device.isOnline ? '在线' : '离线',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: device.isOnline ? const Color(0xFF4ADE80) : Colors.white38)),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
          ]),
        ]),
      ),
    );
  }
}

// ── 绑定 BottomSheet ──────────────────────────────────────
class _BindOptionsSheet extends StatelessWidget {
  final WidgetRef ref;
  const _BindOptionsSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Text('添加设备', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        _OptionTile(
          icon: Icons.qr_code_scanner_rounded, title: '扫描二维码', subtitle: '扫描设备底部的二维码',
          color: AppColors.secondary,
          onTap: () async {
            Navigator.pop(context);
            await Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ScanQrPage(deviceType: '智能宠物设备'),
            ));
            ref.read(deviceListProvider.notifier).load();
          },
        ),
        const SizedBox(height: 12),
        _OptionTile(
          icon: Icons.input_rounded, title: '手动输入 MAC', subtitle: '输入设备的 MAC 地址',
          color: AppColors.primary, onTap: () { Navigator.pop(context); _showMacInput(context); },
        ),
      ]),
    );
  }

  void _showMacInput(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('输入 MAC 地址', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
      content: TextField(controller: ctrl,
        decoration: InputDecoration(
          hintText: 'e.g. AA:BB:CC:DD:EE:FF',
          filled: true, fillColor: AppColors.surfaceContainer,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            if (ctrl.text.isNotEmpty) {
              try {
                await ref.read(deviceRepositoryProvider).bindDevice(mac: ctrl.text);
                await ref.read(deviceListProvider.notifier).load();
              } catch (e) {
                debugPrint('[DeviceList] 绑定失败: $e');
              }
            }
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('绑定'),
        ),
      ],
    ));
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Color color; final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18))),
      child: Row(children: [
        Container(width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          Text(subtitle, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: AppColors.onSurfaceVariant)),
        ])),
        Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant, size: 20),
      ]),
    ));
  }
}
