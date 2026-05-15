import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/pet_toast.dart';
import '../../core/router/app_routes.dart';
import 'controller/im_controller.dart';
import 'data/repository/im_repository.dart';
import 'qr/my_qr_page.dart';
import 'qr/scan_add_friend_page.dart';

// ── 联系人全屏页（替代 BottomSheet）──────────────────────────
class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<V2TimFriendInfo> _friends = [];
  List<V2TimFriendInfo> _blacklist = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _loading = true);

    final repo = ref.read(imRepositoryProvider);

    // 好友列表（直接从 SDK 拉，getFriendList 已含 userProfile）
    final fl = await TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .getFriendList();
    final rawFriends = fl.data?.map((e) => e!).toList() ?? [];

    // 如果 userProfile 为 null，批量补充
    final needFetch = rawFriends
        .where((f) => f.userProfile?.nickName == null || f.userProfile!.nickName!.isEmpty)
        .map((f) => f.userID ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (needFetch.isNotEmpty) {
      final enriched = await repo.getFriendsInfo(needFetch);
      final enrichedMap = {for (final e in enriched) e.userID: e};
      for (int i = 0; i < rawFriends.length; i++) {
        final uid = rawFriends[i].userID;
        if (enrichedMap.containsKey(uid)) {
          rawFriends[i] = enrichedMap[uid]!;
        }
      }
    }

    // 黑名单列表
    final blResult = await repo.getBlackList();
    final bl = blResult.when(success: (l) => l, failure: (_) => <V2TimFriendInfo>[]);

    if (!mounted) return;
    setState(() {
      _friends   = rawFriends;
      _blacklist = bl;
      _loading   = false; // 不管 silent 与否，始终关闭 loading
    });
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '联系人',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 20,
            fontWeight: FontWeight.w800, color: AppColors.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            color: AppColors.onSurface,
            tooltip: '我的二维码',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyQrCodePage())),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            color: AppColors.onSurface,
            tooltip: '扫码加好友',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ScanAddFriendPage())),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 13,
              fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: '好友${_friends.isEmpty ? '' : ' ${_friends.length}'}'),
            Tab(text: '黑名单${_blacklist.isEmpty ? '' : ' ${_blacklist.length}'}'),
            const Tab(text: '设置'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5))
          : TabBarView(
              controller: _tab,
              children: [
                _FriendListTab(
                    friends: _friends,
                    onRefresh: () => _loadData(silent: true)),
                _BlacklistTab(
                    blacklist: _blacklist,
                    onRefresh: () => _loadData(silent: true)),
                _ContactSettingsTab(),
              ],
            ),
    );
  }
}

// ── 好友列表 Tab ──────────────────────────────────────────────
class _FriendListTab extends ConsumerStatefulWidget {
  final List<V2TimFriendInfo> friends;
  final VoidCallback onRefresh;
  const _FriendListTab({required this.friends, required this.onRefresh});

  @override
  ConsumerState<_FriendListTab> createState() => _FriendListTabState();
}

class _FriendListTabState extends ConsumerState<_FriendListTab> {
  late List<V2TimFriendInfo> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.friends);
  }

  @override
  void didUpdateWidget(_FriendListTab old) {
    super.didUpdateWidget(old);
    if (old.friends != widget.friends) _items = List.from(widget.friends);
  }

  void _showActions(V2TimFriendInfo f) {
    final uid  = f.userID ?? '';
    final name = f.friendRemark?.isNotEmpty == true
        ? f.friendRemark!
        : (f.userProfile?.nickName?.isNotEmpty == true
            ? f.userProfile!.nickName!
            : uid);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Row(children: [
                PetAvatar(imageUrl: f.userProfile?.faceUrl, size: 36, fallbackEmoji: '🐾'),
                const SizedBox(width: 10),
                Expanded(child: Text(name,
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: AppColors.onSurface))),
              ]),
            ),
            const Divider(height: 1, thickness: 0.5),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary),
              title: const Text('发送消息',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.chat(uid));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_rounded,
                  color: AppColors.error),
              title: const Text('删除好友',
                  style: TextStyle(color: AppColors.error,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                final ok = await ref
                    .read(imControllerProvider.notifier)
                    .deleteFriend(uid);
                if (!mounted) return;
                if (ok) {
                  // ① 立即本地移除，UI 立刻响应
                  setState(() => _items.removeWhere((x) => x.userID == uid));
                  PetToast.success(context, '已删除好友');
                  // ② 延迟 800ms 等 SDK 同步，再刷新父级
                  await Future.delayed(const Duration(milliseconds: 800));
                  if (mounted) widget.onRefresh();
                } else {
                  PetToast.error(context, '删除失败，请重试');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded,
                  color: AppColors.onSurfaceVariant),
              title: const Text('拉黑该用户',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface)),
              onTap: () async {
                Navigator.pop(context);
                final ok = await ref
                    .read(imControllerProvider.notifier)
                    .addToBlackList(uid);
                if (!mounted) return;
                if (ok) {
                  // ① 立即本地移除
                  setState(() => _items.removeWhere((x) => x.userID == uid));
                  PetToast.success(context, '已拉黑 $name');
                  // ② 延迟刷新父级（含黑名单列表）
                  await Future.delayed(const Duration(milliseconds: 800));
                  if (mounted) widget.onRefresh();
                } else {
                  PetToast.error(context, '拉黑失败，请重试');
                }
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🐾', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('还没有好友',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16,
                  fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
          SizedBox(height: 4),
          Text('在社区认识新朋友，加他们为好友吧～',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                  color: AppColors.onSurfaceVariant)),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final f    = _items[i];
        final uid  = f.userID ?? '';
        final name = f.friendRemark?.isNotEmpty == true
            ? f.friendRemark!
            : (f.userProfile?.nickName?.isNotEmpty == true
                ? f.userProfile!.nickName!
                : uid);
        final face = f.userProfile?.faceUrl;

        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            context.push(AppRoutes.chat(uid));
          },
          onLongPress: () => _showActions(f),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 12, spreadRadius: -4)],
            ),
            child: Row(children: [
              PetAvatar(imageUrl: face, size: 44, fallbackEmoji: '🐾'),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                      fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  if (f.userProfile?.selfSignature?.isNotEmpty == true)
                    Text(f.userProfile!.selfSignature!,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans',
                            fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              )),
              Icon(Icons.more_horiz_rounded,
                  color: AppColors.onSurfaceVariant, size: 20),
            ]),
          ),
        );
      },
    );
  }
}

// ── 黑名单 Tab ─────────────────────────────────────────────────
class _BlacklistTab extends ConsumerWidget {
  final List<V2TimFriendInfo> blacklist;
  final VoidCallback onRefresh;
  const _BlacklistTab({required this.blacklist, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (blacklist.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🛡️', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('黑名单为空',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16,
                  fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
          SizedBox(height: 4),
          Text('被拉黑的用户将无法向你发送消息',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                  color: AppColors.onSurfaceVariant)),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: blacklist.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final f    = blacklist[i];
        final uid  = f.userID ?? '';
        final name = f.userProfile?.nickName?.isNotEmpty == true
            ? f.userProfile!.nickName!
            : uid;
        final face = f.userProfile?.faceUrl;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: AppColors.cardShadow, blurRadius: 12, spreadRadius: -4)],
          ),
          child: Row(children: [
            Stack(children: [
              PetAvatar(imageUrl: face, size: 44, fallbackEmoji: '🐾'),
              Positioned.fill(child: ClipOval(
                child: Container(color: Colors.black.withOpacity(0.35),
                    child: const Icon(Icons.block_rounded,
                        color: Colors.white, size: 20)),
              )),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface.withOpacity(0.6))),
                const Text('已被拉黑',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11, color: AppColors.error)),
              ],
            )),
            TextButton(
              onPressed: () async {
                final ok = await ref
                    .read(imRepositoryProvider)
                    .removeFromBlackList(uid);
                final success = ok.when(
                    success: (_) => true, failure: (_) => false);
                if (!ctx.mounted) return;
                if (success) {
                  PetToast.success(ctx, '已将 $name 移出黑名单');
                  // 延迟 800ms 再刷新，避免 SDK 竞态
                  await Future.delayed(const Duration(milliseconds: 800));
                  if (ctx.mounted) onRefresh();
                } else {
                  PetToast.error(ctx, '操作失败，请重试');
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                backgroundColor: AppColors.primaryContainer.withOpacity(0.15),
              ),
              child: const Text('移出黑名单',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
        );
      },
    );
  }
}

// ── 设置 Tab（QR 快捷入口）────────────────────────────────────
class _ContactSettingsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingItem(
          icon: Icons.qr_code_rounded,
          iconColor: AppColors.primary,
          title: '我的二维码',
          subtitle: '分享给好友，让他们扫码添加你',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MyQrCodePage())),
        ),
        const SizedBox(height: 8),
        _SettingItem(
          icon: Icons.qr_code_scanner_rounded,
          iconColor: const Color(0xFF34C759),
          title: '扫码加好友',
          subtitle: '扫描对方的二维码快速添加好友',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ScanAddFriendPage())),
        ),
      ],
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final VoidCallback onTap;
  const _SettingItem({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: AppColors.cardShadow, blurRadius: 12, spreadRadius: -4)],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            Text(subtitle, style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                color: AppColors.onSurfaceVariant)),
          ],
        )),
        Icon(Icons.chevron_right_rounded,
            color: AppColors.onSurfaceVariant, size: 20),
      ]),
    ),
  );
}
