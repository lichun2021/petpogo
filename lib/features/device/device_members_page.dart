import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/pet_toast.dart';
import '../../shared/utils/wechat_share.dart';
import '../share/data/repository/share_repository.dart';
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

  bool _sharing = false;

  /// 生成设备分享：push/add 拿口令 → createShare 生成链接 → 弹卡片
  Future<void> _shareDevice() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    HapticFeedback.selectionClick();
    try {
      final repo = ref.read(deviceRepositoryProvider);
      final order = await repo.createShareOrder(deviceId: widget.deviceId);

      final result = await ref.read(shareRepositoryProvider).createShare(
            type: 'device',
            targetId: widget.deviceId,
            title: '邀请你共同管理「${widget.deviceName}」',
            description: '打开链接，将设备添加到你的账户，即可一起查看和控制。',
            payload: {
              'order': order,
              'mac': widget.mac,
              'deviceId': widget.deviceId,
              'deviceName': widget.deviceName,
            },
            expireDays: 1, // 对齐口令 24h 有效期
          );
      if (!mounted) return;

      result.when(
        success: (share) {
          if (share.shareUrl.isEmpty) {
            PetToast.error(context, '分享链接生成失败');
            return;
          }
          _showShareSheet(share.shareUrl);
        },
        failure: (error) => PetToast.error(context, error.userMessage),
      );
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        PetToast.error(context, msg.contains('[iPet]') ? msg : '生成分享失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showShareSheet(String shareUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareDeviceSheet(
        shareUrl: shareUrl,
        deviceName: widget.deviceName,
      ),
    );
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
          // 分享按钮
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: _sharing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded),
              color: AppColors.primary,
              tooltip: '分享设备',
              onPressed: _sharing ? null : _shareDevice,
            ),
          ),
          // 刷新按钮：固定 48×48，防止 loading/idle 切换时宽度变化导致分享按钮位移
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: SizedBox(
              width: 48,
              height: 48,
              child: _loading
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      color: AppColors.onSurfaceVariant,
                      onPressed: _load,
                    ),
            ),
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
              Flexible(
                child: Text(
                  member.displayName,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
              member.displayAccount,
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

// ── 分享设备底部弹窗 ──────────────────────────────────────
/// 展示生成的分享链接，支持复制 / 微信分享
class _ShareDeviceSheet extends StatelessWidget {
  final String shareUrl;
  final String deviceName;
  const _ShareDeviceSheet({required this.shareUrl, required this.deviceName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 拖拽指示条
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.ios_share_rounded, color: AppColors.primary, size: 26),
        ),
        const SizedBox(height: 14),
        Text(
          '分享「$deviceName」',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '链接 24 小时内有效，对方打开即可添加设备',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        // 链接展示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Text(
            shareUrl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: _SheetButton(
              icon: Icons.copy_rounded,
              label: '复制链接',
              filled: false,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: shareUrl));
                if (context.mounted) {
                  Navigator.pop(context);
                  PetToast.success(context, '链接已复制');
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SheetButton(
              icon: Icons.wechat_rounded,
              label: '微信分享',
              filled: true,
              onTap: () async {
                Navigator.pop(context);
                await shareWechatWebPage(
                  url: shareUrl,
                  title: '邀请你共同管理「$deviceName」',
                  description: '打开链接，将设备添加到你的账户。',
                  scene: WechatShareScene.session,
                );
              },
            ),
          ),
        ]),
      ]),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _SheetButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? null
              : Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 18, color: filled ? Colors.white : AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : AppColors.primary,
            ),
          ),
        ]),
      ),
    );
  }
}
