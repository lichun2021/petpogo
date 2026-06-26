import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/pet_toast.dart';
import 'controller/pet_circle_controller.dart';
import 'controller/pet_circle_pet_controller.dart';
import 'data/models/pet_circle_post.dart';

class PetCirclePage extends ConsumerStatefulWidget {
  const PetCirclePage({super.key});

  @override
  ConsumerState<PetCirclePage> createState() => _PetCirclePageState();
}

class _PetCirclePageState extends ConsumerState<PetCirclePage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(
      () => ref.read(petCirclePetControllerProvider.notifier).loadIfNeeded(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 260) {
      ref.read(petCircleControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petCirclePetControllerProvider);
    final circleState = ref.watch(petCircleControllerProvider);
    final pets = petState.pets;

    if (pets.isNotEmpty &&
        (circleState.selectedPetId.isEmpty ||
            !pets.any((pet) => pet.id == circleState.selectedPetId))) {
      Future.microtask(() {
        ref.read(petCircleControllerProvider.notifier).selectPet(pets.first.id);
      });
    }

    final selectedPet = _findPet(pets, circleState.selectedPetId);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F6),
      body: Column(
        children: [
          _PetCircleHeader(
            pets: pets,
            loading: petState.isLoading && pets.isEmpty,
            errorMessage: petState.errorMessage,
            selectedPetId: circleState.selectedPetId,
            onSelect: (pet) {
              HapticFeedback.selectionClick();
              ref.read(petCircleControllerProvider.notifier).selectPet(pet.id);
            },
          ),
          Expanded(
            child: _buildBody(
              petState: petState,
              circleState: circleState,
              selectedPet: selectedPet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required PetCirclePetState petState,
    required PetCircleState circleState,
    required PetCirclePet? selectedPet,
  }) {
    if (petState.isLoading && petState.pets.isEmpty) {
      return const _CenteredState(
        icon: Icons.pets_rounded,
        title: '正在加载宠物',
        message: '稍等一下，正在同步你的宠物列表',
        loading: true,
      );
    }

    if (petState.errorMessage != null && petState.pets.isEmpty) {
      return _CenteredState(
        icon: Icons.cloud_off_rounded,
        title: '宠物加载失败',
        message: petState.errorMessage!,
        actionLabel: '重新加载',
        onAction: () {
          ref.read(petCirclePetControllerProvider.notifier).load();
        },
      );
    }

    if (petState.pets.isEmpty) {
      return const _CenteredState(
        icon: Icons.pets_rounded,
        title: '还没有宠物',
        message: '绑定设备并完善宠物档案后，AI 记录的日常会出现在这里',
      );
    }

    if (circleState.isLoading && circleState.posts.isEmpty) {
      return const _TimelineSkeleton();
    }

    if (circleState.errorMessage != null && circleState.posts.isEmpty) {
      return _CenteredState(
        icon: Icons.wifi_off_rounded,
        title: '动态加载失败',
        message: circleState.errorMessage!,
        actionLabel: '重新加载',
        onAction: () {
          final petId = circleState.selectedPetId;
          if (petId.isNotEmpty) {
            ref.read(petCircleControllerProvider.notifier).selectPet(petId);
          }
        },
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(petCircleControllerProvider.notifier).refresh(),
      child: circleState.posts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.14),
                _CenteredState(
                  icon: Icons.auto_awesome_rounded,
                  title: '还没有萌宠动态',
                  message: selectedPet == null
                      ? 'AI 记录到宠物日常后会自动出现在这里'
                      : 'AI 记录到 ${selectedPet.name} 的日常后会自动出现在这里',
                ),
              ],
            )
          : ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              itemCount: circleState.posts.length +
                  (circleState.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                if (index >= circleState.posts.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return _PetCirclePostTile(
                  post: circleState.posts[index],
                  fallbackPet: selectedPet,
                  onMore: () => _showPostActions(circleState.posts[index]),
                );
              },
            ),
    );
  }

  PetCirclePet? _findPet(List<PetCirclePet> pets, String selectedPetId) {
    for (final pet in pets) {
      if (pet.id == selectedPetId) return pet;
    }
    return pets.isEmpty ? null : pets.first;
  }

  void _showPostActions(PetCirclePost post) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded,
                      color: AppColors.error),
                  title: const Text('删除这条动态'),
                  subtitle: const Text('删除后 App 内不再展示'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final ok = await ref
                        .read(petCircleControllerProvider.notifier)
                        .deletePost(post.id);
                    if (!mounted) return;
                    if (ok) {
                      PetToast.success(context, '已删除');
                    } else {
                      final error =
                          ref.read(petCircleControllerProvider).errorMessage;
                      PetToast.error(context, error ?? '删除失败');
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: const Text('取消'),
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PetCircleHeader extends StatelessWidget {
  final List<PetCirclePet> pets;
  final bool loading;
  final String? errorMessage;
  final String selectedPetId;
  final ValueChanged<PetCirclePet> onSelect;

  const _PetCircleHeader({
    required this.pets,
    required this.loading,
    required this.errorMessage,
    required this.selectedPetId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F0F5),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 10,
      ),
      child: SizedBox(
        height: 92,
        child: loading
            ? const Center(
                child: _PetHeaderStatus(
                  icon: Icons.pets_rounded,
                  title: '正在同步宠物',
                  message: '从已绑定设备读取宠物档案',
                ),
              )
            : pets.isEmpty
                ? _PetHeaderStatus(
                    icon: errorMessage == null
                        ? Icons.pets_rounded
                        : Icons.cloud_off_rounded,
                    title: errorMessage == null ? '暂无宠物' : '宠物加载失败',
                    message: errorMessage == null
                        ? '绑定设备并添加宠物后，这里会显示宠物头像'
                        : '下拉页面或稍后重试',
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: pets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 18),
                    itemBuilder: (context, index) {
                      final pet = pets[index];
                      final selected = pet.id == selectedPetId ||
                          (selectedPetId.isEmpty && index == 0);
                      return _PetAvatarTab(
                        pet: pet,
                        selected: selected,
                        onTap: () => onSelect(pet),
                      );
                    },
                  ),
      ),
    );
  }
}

class _PetAvatarTab extends StatelessWidget {
  final PetCirclePet pet;
  final bool selected;
  final VoidCallback onTap;

  const _PetAvatarTab({
    required this.pet,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected ? const Color(0xFFFFB13B) : Colors.transparent,
                  width: 3,
                ),
              ),
              child: PetAvatar(
                imageUrl: pet.avatar,
                size: 54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              pet.name.isEmpty ? '宠物' : pet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.1,
                color: selected ? AppColors.primary : AppColors.onSurface,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetHeaderStatus extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _PetHeaderStatus({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.65),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetCirclePostTile extends StatelessWidget {
  final PetCirclePost post;
  final PetCirclePet? fallbackPet;
  final VoidCallback onMore;

  const _PetCirclePostTile({
    required this.post,
    required this.fallbackPet,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final name = post.petName.isNotEmpty
        ? post.petName
        : (fallbackPet?.name.isNotEmpty == true ? fallbackPet!.name : '萌宠');
    final avatar =
        post.petAvatar.isNotEmpty ? post.petAvatar : fallbackPet?.avatar ?? '';

    return Container(
      padding: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PetAvatar(imageUrl: avatar, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                  ),
                ),
                if (post.content.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.content.trim(),
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.38,
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (post.hasMedia) ...[
                  const SizedBox(height: 12),
                  _PetCircleMediaGrid(post: post),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _relativeTime(post.sourceTime ?? post.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    _MoreButton(onTap: onMore),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '$month-$day';
  }
}

class _PetCircleMediaGrid extends StatelessWidget {
  final PetCirclePost post;

  const _PetCircleMediaGrid({required this.post});

  @override
  Widget build(BuildContext context) {
    if (post.isVideo) {
      final url = post.displayMediaUrl;
      if (url.isEmpty) return const SizedBox.shrink();
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _NetworkImage(url: url),
              Container(color: Colors.black.withValues(alpha: 0.12)),
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final urls = post.mediaUrls.take(9).toList();
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) {
      return SizedBox(
        width: 230,
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _NetworkImage(url: urls.first),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: urls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: _NetworkImage(url: urls[index]),
        );
      },
    );
  }
}

class _NetworkImage extends StatelessWidget {
  final String url;

  const _NetworkImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: AppColors.surfaceContainerHigh),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.surfaceContainerHigh,
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHigh.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: const SizedBox(
          width: 34,
          height: 26,
          child: Icon(Icons.more_horiz_rounded, size: 22),
        ),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              )
            else
              Icon(icon, size: 50, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (_, __) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(width: 46, height: 46, radius: 999),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SkeletonBox(width: 78, height: 18, radius: 6),
                  SizedBox(height: 10),
                  _SkeletonBox(width: double.infinity, height: 16, radius: 6),
                  SizedBox(height: 7),
                  _SkeletonBox(width: 210, height: 16, radius: 6),
                  SizedBox(height: 12),
                  _SkeletonBox(width: 230, height: 160, radius: 10),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
