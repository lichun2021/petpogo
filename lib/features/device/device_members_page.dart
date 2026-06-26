import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/pet_toast.dart';
import 'data/models/device_model.dart';
import 'data/repository/device_repository.dart';

// ── 设备成员管理页 ─────────────────────────────────────────
/// 仅 OWNER 设备可进入，展示所有共享成员并支持移除
class DeviceMembersPage extends ConsumerStatefulWidget {
  final String mac;
  final String deviceId;
  final String deviceName;

  const DeviceMembersPage({
    super.key,
    required this.mac,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  ConsumerState<DeviceMembersPage> createState() => _DeviceMembersPageState();
}

class _DeviceMembersPageState extends ConsumerState<DeviceMembersPage> {
  List<DeviceMemberModel> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ref
          .read(deviceRepositoryProvider)
          .fetchMembers(widget.mac);
      if (mounted) setState(() { _members = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _remove(DeviceMemberModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '移除成员',
          style: TextStyle(fontFamily: AppFonts.primary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '确定要将「${member.displayName}」从共享列表中移除吗？',
          style: TextStyle(fontFamily: AppFonts.primary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('确认移除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    HapticFeedback.mediumImpact();

    try {
      await ref.read(deviceRepositoryProvider).removeMember(
        deviceId: widget.deviceId,
        userId: member.userId,
      );
      if (mounted) {
        PetToast.show(context, '已移除 ${member.displayName}');
        _load(); // 刷新列表
      }
    } catch (e) {
      if (mounted) PetToast.error(context, '移除失败，请重试');
    }
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
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '共享成员',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.deviceName,
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.onSurfaceVariant,
              onPressed: _load,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _members.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
      );
    }

    if (_error != null && _members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(fontFamily: AppFonts.primary,
                    fontSize: 13, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('重试')),
          ]),
        ),
      );
    }

    if (_members.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.group_off_rounded, size: 72,
              color: AppColors.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            '暂无共享成员',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '可通过分享功能邀请他人共同管理设备',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        itemCount: _members.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _MemberTile(
          member: _members[i],
          onRemove: () => _remove(_members[i]),
        ),
      ),
    );
  }
}

// ── 成员卡片 ──────────────────────────────────────────────
class _MemberTile extends StatelessWidget {
  final DeviceMemberModel member;
  final VoidCallback onRemove;
  const _MemberTile({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    // 角色颜色
    final Color roleColor;
    switch (member.type) {
      case '2':
        roleColor = const Color(0xFF60A5FA); // 管理员 — 蓝
      default:
        roleColor = AppColors.onSurfaceVariant; // 成员 — 灰
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.onSurface.withOpacity(0.06),
        ),
      ),
      child: Row(children: [
        // 头像占位（首字母）
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.6),
                AppColors.primary.withOpacity(0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 名称 + 账号 + 角色
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                member.displayName,
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              // 角色标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  member.roleLabel,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: roleColor,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Text(
              member.account,
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        // 移除按钮
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onRemove();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_remove_rounded, size: 14, color: AppColors.error),
              const SizedBox(width: 4),
              Text(
                '移除',
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
