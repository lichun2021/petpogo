import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart' show AppL10nX;
import '../../core/router/app_routes.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_tokens.dart';
import '../../shared/widgets/app_error_view.dart';
import 'controller/my_posts_controller.dart';
import 'viewer/post_viewer_page.dart';
import 'widgets/community_post_card.dart';

class MyPostsPage extends ConsumerStatefulWidget {
  const MyPostsPage({super.key});
  @override
  ConsumerState<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends ConsumerState<MyPostsPage> {
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300 &&
          ref.read(myPostsControllerProvider).outcome.isSuccess) {
        ref.read(myPostsControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    await context.push(AppRoutes.publishPost);
    if (mounted) await ref.read(myPostsControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myPostsControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surfacePage,
      appBar: AppBar(
          title: Text(context.l10n.profileMyPosts),
          centerTitle: false,
          actions: [
            TextButton.icon(
                onPressed: _publish,
                icon: const Icon(Icons.add_rounded),
                label: const Text('发布'))
          ]),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myPostsControllerProvider.notifier).refresh(),
        child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (state.loading)
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
              if (!state.loading &&
                  state.posts.isEmpty &&
                  state.outcome.isSuccess)
                SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.x24),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.article_outlined,
                                  size: AppSpacing.x48,
                                  color: AppColors.textSecondary),
                              const SizedBox(height: AppSpacing.x16),
                              Text('还没有发布帖子',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: AppSpacing.x8),
                              Text('记录和毛孩子在一起的时光',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: AppSpacing.x24),
                              FilledButton(
                                  onPressed: _publish,
                                  child: const Text('发布第一条帖子')),
                            ]))),
              if (state.posts.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.x12),
                  sliver: SliverLayoutBuilder(
                      builder: (context, constraints) =>
                          SliverMasonryGrid.count(
                            crossAxisCount: constraints.crossAxisExtent < 330 &&
                                    MediaQuery.textScalerOf(context).scale(12) >
                                        16
                                ? 1
                                : 2,
                            mainAxisSpacing: AppSpacing.x12,
                            crossAxisSpacing: AppSpacing.x12,
                            childCount: state.posts.length,
                            itemBuilder: (_, index) => CommunityPostCard(
                                key: ValueKey(state.posts[index].id),
                                post: state.posts[index],
                                index: index,
                                onAvatarTap: null,
                                onLike: null,
                                onTap: () => Navigator.of(context,
                                        rootNavigator: true)
                                    .push(MaterialPageRoute<void>(
                                        builder: (_) => PostViewerPage(
                                            posts:
                                                List.unmodifiable(state.posts),
                                            initialIndex: index,
                                            syncWithFeed: false)))),
                          )),
                ),
              state.outcome.when(
                success: (_) => SliverToBoxAdapter(
                    child: state.loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.x24),
                            child: Center(child: CircularProgressIndicator()))
                        : state.hasMore
                            ? Center(
                                child: TextButton(
                                    onPressed: () => ref
                                        .read(
                                            myPostsControllerProvider.notifier)
                                        .loadMore(),
                                    child: const Text('加载更多')))
                            : state.posts.isNotEmpty
                                ? Padding(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.x24),
                                    child: Center(
                                        child: Text('已经到底了',
                                            style: TextStyle(
                                                color:
                                                    AppColors.textSecondary))))
                                : const SizedBox.shrink()),
                failure: (error) => SliverToBoxAdapter(
                    child: AppErrorView(
                        error: error,
                        fallback: '帖子加载失败，请重试',
                        onRetry: () => state.failedRefresh ||
                                state.posts.isEmpty ||
                                !state.hasMore
                            ? ref
                                .read(myPostsControllerProvider.notifier)
                                .refresh()
                            : ref
                                .read(myPostsControllerProvider.notifier)
                                .loadMore())),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x24)),
            ]),
      ),
    );
  }
}
