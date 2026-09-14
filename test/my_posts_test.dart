import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/api_endpoints.dart';
import 'package:petpogo_app/core/api/api_exception.dart';
import 'package:petpogo_app/core/api/result.dart';
import 'package:petpogo_app/features/community/controller/my_posts_controller.dart';
import 'package:petpogo_app/features/community/data/models/post_model.dart';
import 'package:petpogo_app/features/community/data/post_repository.dart';
import 'package:petpogo_app/features/community/my_posts_page.dart';
import 'package:petpogo_app/l10n/app_localizations.dart';

PostModel post(String id, {String owner = 'me'}) => PostModel.fromJson({
      'id': id,
      'user_id': owner,
      'content': '帖子 $id',
      'nickname': '我',
      'created_at': '2026-09-14T10:00:00',
    });

class _Client implements ApiClient {
  dynamic payload;
  String? path;
  @override
  Future<T> post<T>(String path,
      {dynamic data, T Function(dynamic)? fromJson, Options? options}) async {
    this.path = path;
    payload = data;
    return {
      'list': [
        {'id': '1', 'user_id': 'me'},
        {'id': '2', 'user_id': 'other'},
      ]
    } as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements PostRepository {
  final requests =
      <({String owner, int page, Completer<Result<OwnPostsPage>> result})>[];
  @override
  Future<Result<OwnPostsPage>> fetchOwnPosts(
      {required String userId, int page = 1, int size = 20}) {
    final completer = Completer<Result<OwnPostsPage>>();
    requests.add((owner: userId, page: page, result: completer));
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Repository requests current author and rejects other authors',
      () async {
    final client = _Client();
    final result = await PostRepository(client)
        .fetchOwnPosts(userId: 'me', page: 2, size: 2);
    expect(client.path, ApiEndpoints.postAuthorsFeed);
    expect(client.payload, {
      'friendIds': ['me'],
      'page': 2,
      'size': 2
    });
    final data = (result as Success<OwnPostsPage>).data;
    expect(data.posts.single.id, '1');
    expect(data.hasMore, isTrue);
  });
  test(
      'Pagination failure preserves posts and retries same page without duplicates',
      () async {
    final repo = _Repo();
    final controller = MyPostsController(repo, 'me');
    addTearDown(controller.dispose);
    repo.requests[0].result
        .complete(Success(OwnPostsPage(posts: [post('1')], hasMore: true)));
    await Future<void>.delayed(Duration.zero);
    final more = controller.loadMore();
    repo.requests[1].result.complete(Failure(ApiException(message: 'network')));
    await more;
    expect(controller.state.posts.single.id, '1');
    expect(controller.state.page, 1);
    final retry = controller.loadMore();
    expect(repo.requests[2].page, 2);
    repo.requests[2].result.complete(
        Success(OwnPostsPage(posts: [post('1'), post('2')], hasMore: false)));
    await retry;
    expect(controller.state.posts.map((p) => p.id).toSet(), {'1', '2'});
  });
  test('Refresh discards an older pending pagination response', () async {
    final repo = _Repo();
    final controller = MyPostsController(repo, 'me');
    addTearDown(controller.dispose);
    repo.requests[0].result
        .complete(Success(OwnPostsPage(posts: [post('1')], hasMore: true)));
    await Future<void>.delayed(Duration.zero);
    final more = controller.loadMore();
    final refresh = controller.refresh();
    repo.requests[2].result
        .complete(Success(OwnPostsPage(posts: [post('new')], hasMore: false)));
    await refresh;
    repo.requests[1].result
        .complete(Success(OwnPostsPage(posts: [post('old')], hasMore: false)));
    await more;
    expect(controller.state.posts.single.id, 'new');
  });
  test('Changing account replaces its controller and visible posts', () async {
    final owner = StateProvider<String>((_) => 'me');
    final repo = _Repo();
    final container = ProviderContainer(overrides: [
      myPostsOwnerProvider.overrideWith((ref) => ref.watch(owner)),
      postRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.listen(myPostsControllerProvider, (_, __) {});
    repo.requests[0].result
        .complete(Success(OwnPostsPage(posts: [post('1')], hasMore: false)));
    await Future<void>.delayed(Duration.zero);
    container.read(owner.notifier).state = 'other';
    expect(container.read(myPostsControllerProvider).posts, isEmpty);
    expect(repo.requests.last.owner, 'other');
    repo.requests.last.result
        .complete(const Success(OwnPostsPage(posts: [], hasMore: false)));
    await Future<void>.delayed(Duration.zero);
  });
  testWidgets(
      'My posts page shows real controller content on narrow large-text screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          myPostsOwnerProvider.overrideWithValue('me'),
          postRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!),
            home: const MyPostsPage())));
    repo.requests[0].result
        .complete(Success(OwnPostsPage(posts: [post('1')], hasMore: false)));
    await tester.pumpAndSettle();
    expect(find.text('我的帖子'), findsOneWidget);
    expect(find.text('帖子 1'), findsOneWidget);
    expect(find.text('已经到底了'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
