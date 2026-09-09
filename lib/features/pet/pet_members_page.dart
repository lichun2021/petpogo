import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/pet_toast.dart';
import '../../shared/utils/wechat_share.dart';
import '../share/data/repository/share_repository.dart';
import 'data/models/pet_share_model.dart';
import 'data/repository/pet_share_repository.dart';
import '../../shared/widgets/app_error_view.dart';

// ── 宠物成员管理页 ─────────────────────────────────────────
/// 展示宠物的所有共享成员并支持移除
class PetMembersPage extends ConsumerStatefulWidget {
  final int petId;
  final String petName;
  final String petAvatar;

  const PetMembersPage({
    super.key,
    required this.petId,
    required this.petName,
    this.petAvatar = '',
  });

  @override
  ConsumerState<PetMembersPage> createState() => _PetMembersPageState();
}

class _PetMembersPageState extends ConsumerState<PetMembersPage> {
  List<PetMemberModel> _members = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // 延迟加载，让UI先显示
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await ref.read(petShareRepositoryProvider).fetchMembers(widget.petId);
      if (mounted) {
        setState(() {
          _members = list;
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

  bool _sharing = false;

  /// 生成宠物分享：创建口令 → createShare 生成链接 → 弹卡片
  Future<void> _sharePet() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    HapticFeedback.selectionClick();
    try {
      final repo = ref.read(petShareRepositoryProvider);
      final order = await repo.createShare(petId: widget.petId);

      final result = await ref.read(shareRepositoryProvider).createShare(
            type: 'pet',
            targetId: widget.petId.toString(),
            title: '邀请你共同管理宠物「${widget.petName}」',
            description: '这是一只可爱的宠物，打开链接添加后即可一起查看和管理。',
            imageUrl: widget.petAvatar.isNotEmpty ? widget.petAvatar : null,
            payload: {
              'order': order,
              'petId': widget.petId.toString(),
              'petName': widget.petName,
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
        PetToast.error(context, e, fallback: '生成分享失败，请重试');
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
      builder: (_) => _SharePetSheet(
        shareUrl: shareUrl,
        petName: widget.petName,
        petAvatar: widget.petAvatar,
      ),
    );
  }

  Future<void> _remove(PetMemberModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '移除成员',
          style: TextStyle(
              fontFamily: AppFonts.primary, fontWeight: FontWeight.w700),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('确认移除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    HapticFeedback.mediumImpact();

    try {
      await ref.read(petShareRepositoryProvider).removeMember(
            petId: widget.petId,
            userId: member.userId,
          );
      if (mounted) {
        PetToast.show(context, '已移除 ${member.displayName}');
        _load();
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
              widget.petName,
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
          // 分享（邀请）按钮
          IconButton(
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
            tooltip: '分享宠物',
            visualDensity: VisualDensity.compact,
            onPressed: _sharing ? null : _sharePet,
          ),
          // 刷新按钮
          SizedBox(
            width: 40,
            height: 40,
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
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppColors.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                    onPressed: _load,
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 有错误且没有数据时显示错误
    if (_error != null && _members.isEmpty) {
      return AppErrorView(error: _error, fallback: '成员列表加载失败，请稍后重试', onRetry: _load);
    }

    // 没有成员时显示空状态
    if (_members.isEmpty) {
      // 如果正在加载，显示加载中
      if (_loading) {
        return Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5),
        );
      }

      // 否则显示空状态
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.group_off_rounded,
              size: 72, color: AppColors.onSurfaceVariant.withOpacity(0.3)),
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
            '可通过分享功能邀请他人共同管理宠物',
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

    // 有数据时显示列表
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

// ── 成员卡片 ──────────────────────────────────────────────────────
class _MemberTile extends StatelessWidget {
  final PetMemberModel member;
  final VoidCallback onRemove;
  const _MemberTile({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final bool isOwner = member.isOwner;
    final bool isAdmin = member.isAdmin;

    // 角色配色
    final Color roleColor = isOwner
        ? AppColors.brandPrimary
        : isAdmin
            ? AppColors.brandPrimaryStrong
            : AppColors.statusNeutral;
    final IconData roleIcon = isOwner
        ? Icons.star_rounded
        : isAdmin
            ? Icons.admin_panel_settings_rounded
            : Icons.person_rounded;

    final String initial = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : '?';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            spreadRadius: -4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // 头像
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  roleColor.withValues(alpha: 0.75),
                  roleColor.withValues(alpha: 0.45),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 名称 + 账号
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName,
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // 角色标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(roleIcon, size: 10, color: roleColor),
                          const SizedBox(width: 3),
                          Text(
                            member.roleLabel,
                            style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: roleColor,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 移除按钮（主人不显示）
          if (!isOwner)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onRemove();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.22)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_remove_rounded,
                      size: 13, color: AppColors.error),
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
      ),
    );
  }
}

// ── 分享宠物底部弹窗 ──────────────────────────────────────
class _SharePetSheet extends StatelessWidget {
  final String shareUrl;
  final String petName;
  final String petAvatar;

  const _SharePetSheet({
    required this.shareUrl,
    required this.petName,
    this.petAvatar = '',
  });

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
          child: Icon(Icons.pets_rounded, color: AppColors.primary, size: 26),
        ),
        const SizedBox(height: 14),
        Text(
          '分享「$petName」',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '宠物分享',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '链接 24 小时内有效，对方打开即可添加宠物',
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
                debugPrint('[宠物分享] 微信分享 URL=$shareUrl');
                await shareWechatWebPage(
                  url: shareUrl,
                  title: '邀请你共同管理宠物「$petName」',
                  description: '这是一只可爱的宠物，打开链接即可添加。',
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
          color:
              filled ? AppColors.primary : AppColors.primary.withOpacity(0.08),
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
