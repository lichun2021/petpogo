import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/pet_toast.dart';
import '../device/data/repository/device_repository.dart';
import '../device/data/models/device_model.dart';
import '../device/device_list_page.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import '../pet/data/models/pet_peer_models.dart';
import '../pet/bind_pet_sheet.dart';
import '../pet/pet_members_page.dart';
import '../pet_circle/controller/pet_circle_pet_controller.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';
import '../../shared/utils/error_presenter.dart';
import '../../core/providers/raw_error_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/app_tokens.dart';

// ════════════════════════════════════════════════════════════
//  宠物列表页 — 使用 /pet/info/list 接口
//  不依赖设备，显示用户所有宠物（包括未绑定设备的）
// ════════════════════════════════════════════════════════════

class PetListPage extends ConsumerStatefulWidget {
  const PetListPage({super.key});

  @override
  ConsumerState<PetListPage> createState() => _PetListPageState();
}

class _PetListPageState extends ConsumerState<PetListPage> {
  List<PetInfoModel> _pets = [];
  Map<String, DeviceModel> _deviceMap = {}; // deviceId -> DeviceModel
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final petRepo = ref.read(petPeerRepositoryProvider);

      // 1. 获取宠物列表（新接口）
      final pets = await petRepo.fetchPetList();

      // 2. 获取设备列表，用于显示设备名称
      final devices = ref.read(deviceListProvider).devices;
      final deviceMap = <String, DeviceModel>{};
      for (final d in devices) {
        deviceMap[d.deviceId] = d;
      }

      if (mounted) {
        setState(() {
          _pets = pets;
          _deviceMap = deviceMap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _refresh() async {
    // 先刷新设备列表，再刷新宠物
    await ref.read(deviceListProvider.notifier).load();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('我的宠物'),
        centerTitle: false,
        actions: [
          if (_loading)
            Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)))
          else
            IconButton(
              icon: Icon(Icons.refresh_rounded),
              color: AppColors.onSurfaceVariant,
              onPressed: _refresh,
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_rounded,
            size: 48, color: AppColors.onSurfaceVariant),
        SizedBox(height: 12),
        Text('加载失败',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface)),
        SizedBox(height: 8),
        Text(ErrorPresenter.message(_error, fallback: '宠物列表加载失败，请稍后重试'),
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
            textAlign: TextAlign.center),
        if (ref.watch(showRawErrorProvider)) ...[
          const SizedBox(height: 6),
          SelectableText(_error.toString(),
              maxLines: 3,
              textAlign: TextAlign.center,
              style: AppTheme.monoData(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary)),
        ],
        SizedBox(height: 20),
        FilledButton(
            onPressed: _load,
            child: Text('重试',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontWeight: FontWeight.w700))),
      ]));
    }
    if (_pets.isEmpty) {
      return _buildEmpty(context);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        itemCount: _pets.length,
        separatorBuilder: (_, __) => SizedBox(height: 14),
        itemBuilder: (_, i) => _PetCard(
          pet: _pets[i],
          device: _pets[i].deviceId.isNotEmpty
              ? _deviceMap[_pets[i].deviceId]
              : null,
          onRefresh: _refresh,
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    // 检查是否有设备
    final hasDevices = ref.read(deviceListProvider).devices.isNotEmpty;
    return Center(
        child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('🐾', style: TextStyle(fontSize: 72)),
        SizedBox(height: 20),
        Text(
          '还没有添加宠物',
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface),
        ),
        SizedBox(height: 8),
        Text(
          hasDevices ? '点击设备卡片上的「绑定宠物」给设备绑定宠物' : '先绑定智能项圈或机器人，再为宠物建档',
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 13,
              color: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 32),
        FilledButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => DeviceListPage(),
                ));
          },
          icon: Icon(Icons.devices_rounded),
          label: Text(hasDevices ? '去绑定宠物' : '去添加设备',
              style: TextStyle(
                  fontFamily: AppFonts.primary, fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]),
    ));
  }
}

// ── 宠物卡片 ──────────────────────────────────────────────
class _PetCard extends ConsumerWidget {
  final PetInfoModel pet;
  final DeviceModel? device; // 可能为null（未绑定设备）
  final VoidCallback onRefresh;

  const _PetCard({
    required this.pet,
    this.device,
    required this.onRefresh,
  });

  void _openEdit(BuildContext context, WidgetRef ref) {
    // 如果有设备，传递mac；否则通过petId编辑
    if (device != null) {
      PetBindHelper.showEdit(
        context,
        mac: device!.mac,
        pet: pet,
      ).then((saved) {
        if (saved) {
          ref.read(petCirclePetControllerProvider.notifier).load();
          onRefresh();
        }
      });
    } else {
      // TODO: 未绑定设备的宠物编辑逻辑
      // 可以使用petId直接编辑
      PetToast.show(context, '未绑定设备的宠物暂不支持编辑');
    }
  }

  void _openMembers(BuildContext context) {
    if (pet.petId.isEmpty) {
      PetToast.error(context, '宠物ID无效');
      return;
    }

    final petIdInt = int.tryParse(pet.petId);
    if (petIdInt == null) {
      PetToast.error(context, '宠物ID格式错误');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetMembersPage(
          petId: petIdInt,
          petName: pet.petName,
          petAvatar: pet.avatar,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除宠物',
            style: TextStyle(
                fontFamily: AppFonts.primary, fontWeight: FontWeight.w800)),
        content: Text('确定要删除「${pet.petName}」吗？删除后数据不可恢复。',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                color: AppColors.onSurfaceVariant)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: AppColors.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(fontFamily: AppFonts.primary)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // 只传 petId，避免后端把设备关联一起删（与 device_detail_page 写法一致）
      await ref.read(petPeerRepositoryProvider).deletePet(
            petId: pet.petId.isNotEmpty ? pet.petId : null,
          );
      if (!context.mounted) return;
      PetToast.success(context, '宠物已删除');
      ref.read(petCirclePetControllerProvider.notifier).load();
      onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      PetToast.error(context, '删除失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attributes = [pet.breed.trim(), pet.sexDisplay.trim()]
        .where((value) => value.isNotEmpty)
        .join(' · ');

    // 信息行：年龄 · 体重（用 · 分隔，没有就不显示）
    final infoParts = <String>[
      if (pet.age > 0) '${pet.age}岁',
      if (pet.weight.isNotEmpty) '${pet.weight}kg',
    ];
    final infoText = infoParts.join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            spreadRadius: -4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 顶部：头像 + 名字/性别/品种 + 操作按钮 ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 头像
                GestureDetector(
                  onTap: () => _openEdit(context, ref),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.outlineVariant, width: 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: PetAvatar(imageUrl: pet.avatar, size: 56),
                  ),
                ),
                const SizedBox(width: 12),
                // 名字 / 性别 / 品种
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(pet.petName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      if (attributes.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x8),
                        Text(attributes,
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // ── 年龄·体重 信息行（有内容才显示）──
            if (infoText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 68),
                child: Text(
                  infoText,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            // 三个操作保留直达入口，独立一行，避免挤压长名字与属性。
            const SizedBox(height: AppSpacing.x12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              // 操作按钮：成员管理 + 编辑 + 删除
              _IconBtn(
                icon: Icons.group_outlined,
                label: '成员管理',
                color: AppColors.statusNeutral,
                onTap: () => _openMembers(context),
              ),
              const SizedBox(width: AppSpacing.x8),
              _IconBtn(
                icon: Icons.edit_outlined,
                label: '编辑资料',
                color: AppColors.brandPrimary,
                onTap: () => _openEdit(context, ref),
              ),
              const SizedBox(width: AppSpacing.x8),
              _IconBtn(
                icon: Icons.delete_outline_rounded,
                label: '删除宠物',
                color: AppColors.statusAlert,
                onTap: () => _confirmDelete(context, ref),
              ),
            ]),
            // ── 底部分隔线 + 设备标签 ──
            const SizedBox(height: 10),
            Divider(height: 1, thickness: 1, color: AppColors.outlineVariant),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  device != null
                      ? Icons.router_rounded
                      : Icons.link_off_rounded,
                  size: 13,
                  color: device != null
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    device?.displayName ?? '未绑定设备',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡片内的小图标按钮（描边圆形，hover 态）
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: Material(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.controlRadius,
          child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.controlRadius,
              child: SizedBox(
                  width: AppSize.touchMin,
                  height: AppSize.touchMin,
                  child: Icon(icon, size: AppIconSize.card, color: color))),
        ),
      ),
    );
  }
}
