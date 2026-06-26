/// 宠物选择 BottomSheet — 用于宠小伊 AI 问诊入口
///
/// 加载流程：
///   1. 从 deviceListProvider 拿设备列表
///   2. 对每台设备并发调 PeerApi.fetchPetInfo 拿绑定宠物
///   3. 显示宠物卡片列表，用户选中后通过 onPicked 回调返回 petId

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/pet_avatar.dart';
import '../../device/data/repository/device_repository.dart';
import '../../device/data/models/device_model.dart';
import '../../pet/data/models/pet_peer_models.dart';
import '../../pet/data/repository/pet_peer_repository.dart';

class _PetWithDevice {
  final PetInfoModel pet;
  final DeviceModel device;
  const _PetWithDevice({required this.pet, required this.device});
}

class PetPickerSheet extends ConsumerStatefulWidget {
  /// 用户选中宠物后回调（petId）
  final void Function(String petId) onPicked;

  /// 预加载的宠物列表（传入则跳过 loading 状态，避免高度闪变）
  final List<_PetWithDevice>? preloaded;

  const PetPickerSheet({super.key, required this.onPicked, this.preloaded});

  /// 预加载宠物数据，再显示 Sheet（避免高度闪变）
  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required void Function(String petId) onPicked,
  }) async {
    // 在弹出之前预加载宠物数据，确保 Sheet 高度确定后再显示
    final preloaded = await _preload(ref);
    if (!context.mounted) return;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PetPickerSheet(
        onPicked: onPicked,
        preloaded: preloaded,
      ),
    );
  }

  /// 静态预加载（可在 show() 之前调用）
  static Future<List<_PetWithDevice>> _preload(WidgetRef ref) async {
    var deviceState = ref.read(deviceListProvider);
    if (deviceState.devices.isEmpty && !deviceState.isLoading) {
      await ref.read(deviceListProvider.notifier).load();
      deviceState = ref.read(deviceListProvider);
    } else if (deviceState.isLoading) {
      const maxWait = Duration(seconds: 8);
      final deadline = DateTime.now().add(maxWait);
      while (ref.read(deviceListProvider).isLoading &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(Duration(milliseconds: 200));
      }
      deviceState = ref.read(deviceListProvider);
    }

    final devices = deviceState.devices;
    final petRepo = ref.read(petPeerRepositoryProvider);
    final results = <_PetWithDevice>[];

    await Future.wait(devices.map((d) async {
      try {
        final pet = await petRepo.fetchPetInfo(deviceId: d.deviceId);
        if (pet.petName.isNotEmpty) {
          results.add(_PetWithDevice(pet: pet, device: d));
        }
      } catch (e) {
        debugPrint('[PetPickerSheet] 设备 ${d.displayName} 未绑定宠物: $e');
      }
    }));

    return results;
  }

  @override
  ConsumerState<PetPickerSheet> createState() => _PetPickerSheetState();
}

class _PetPickerSheetState extends ConsumerState<PetPickerSheet> {
  List<_PetWithDevice> _pets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 如果外部已预加载，直接使用，跳过 loading 闪变
    if (widget.preloaded != null) {
      _pets = widget.preloaded!;
      _loading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // ① 若设备列表尚未加载，先触发加载并等待完成
      var deviceState = ref.read(deviceListProvider);
      if (deviceState.devices.isEmpty && !deviceState.isLoading) {
        await ref.read(deviceListProvider.notifier).load();
        deviceState = ref.read(deviceListProvider);
      } else if (deviceState.isLoading) {
        // 正在加载中，等待最多 8 秒
        const maxWait = Duration(seconds: 8);
        final deadline = DateTime.now().add(maxWait);
        while (ref.read(deviceListProvider).isLoading &&
            DateTime.now().isBefore(deadline)) {
          await Future.delayed(Duration(milliseconds: 200));
        }
        deviceState = ref.read(deviceListProvider);
      }

      final devices = deviceState.devices;
      debugPrint('[宠小伊] PetPickerSheet 找到设备数=${devices.length}');

      final petRepo = ref.read(petPeerRepositoryProvider);
      final results = <_PetWithDevice>[];

      await Future.wait(devices.map((d) async {
        try {
          final pet = await petRepo.fetchPetInfo(deviceId: d.deviceId);
          debugPrint(
              '[宠小伊] 设备 ${d.displayName} → 宠物=${pet.petName} id=${pet.petId}');
          if (pet.petName.isNotEmpty) {
            results.add(_PetWithDevice(pet: pet, device: d));
          }
        } catch (e) {
          debugPrint('[宠小伊] 设备 ${d.displayName} 未绑定宠物: $e');
        }
      }));

      debugPrint('[宠小伊] PetPickerSheet 加载宠物数=${results.length}');

      if (mounted) {
        setState(() {
          _pets = results;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[宠小伊] PetPickerSheet 加载失败: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      // 最大高度限制，内容不足时自动收缩
      constraints: BoxConstraints(maxHeight: screenH * 0.55),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ← 自适应内容高度
        children: [
          // 顶部 handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 14),
          Text(
            '选择要咨询的宠物',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '宠小伊会基于该宠物的档案进行问诊',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 12),
          // 内容区：自适应，但最多撑到父 constraints 上限
          Flexible(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _buildContent(),
            ),
          ),
          SizedBox(height: bottomPad + 8),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return SizedBox(
        key: ValueKey('loading'),
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.secondary,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return _ErrorState(
          key: ValueKey('error'), message: _error!, onRetry: _load);
    }
    if (_pets.isEmpty) {
      return const _EmptyState(key: ValueKey('empty'));
    }

    // ── 动态高度计算 ──────────────────────────────────────
    // 每行 tile 约 76px（内容 48 + padding 14×2）
    // 间隔 10px，列表上下 padding：top=4 / bottom=12 → 共 16px
    const tileH = 76.0;
    const sepH = 10.0;
    const padV = 16.0; // 4 top + 12 bottom
    final visibleN = _pets.length.clamp(1, 5);
    final listH = padV + visibleN * tileH + (visibleN - 1) * sepH;

    return SizedBox(
      key: ValueKey('list'),
      height: listH,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        itemCount: _pets.length,
        separatorBuilder: (_, __) => SizedBox(height: sepH),
        itemBuilder: (context, i) {
          final pw = _pets[i];
          return _PetTile(
            pet: pw.pet,
            device: pw.device,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
              widget.onPicked(pw.pet.petId);
            },
          );
        },
      ),
    );
  }
}

// ── 宠物卡片 ──────────────────────────────────────────────
class _PetTile extends StatelessWidget {
  final PetInfoModel pet;
  final DeviceModel device;
  final VoidCallback onTap;
  const _PetTile({
    required this.pet,
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.secondary.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              spreadRadius: -4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            PetAvatar(imageUrl: pet.avatar, size: 48),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.petName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    [
                      if (pet.breed.isNotEmpty) pet.breed,
                      if (pet.age > 0) '${pet.age} 岁',
                      if (pet.sexDisplay.isNotEmpty) pet.sexDisplay,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '来自 ${device.displayName}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.secondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 空状态 ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('🔒', style: TextStyle(fontSize: 32)),
            ),
          ),
          SizedBox(height: 14),
          Text(
            '问诊功能暂不可用',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '请先绑定设备并完善宠物档案\n才能使用 AI 问诊功能',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // 关闭 sheet
                context.push(AppRoutes.bindDevice);
              },
              icon: Icon(Icons.add_circle_outline_rounded, size: 18),
              label: Text('去绑定设备'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: AppColors.error.withOpacity(0.8),
          ),
          SizedBox(height: 10),
          Text(
            '加载失败：$message',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text('重试')),
        ],
      ),
    );
  }
}
