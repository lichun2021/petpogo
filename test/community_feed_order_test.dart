import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/community/controller/feed_controller.dart';
import 'package:petpogo_app/features/community/data/models/post_model.dart';
import 'package:petpogo_app/features/community/data/post_repository.dart';

class _Request {
  final int page;
  final String? tag;
  final result = Completer<List<PostModel>>();
  _Request(this.page, this.tag);
}

class _Posts implements PostRepository {
  final requests = <_Request>[];
  @override
  Future<List<PostModel>> fetchFriendFeed(
      {required List<String> friendIds,
      int page = 1,
      int size = 20,
      String? tag}) {
    final request = _Request(page, tag);
    requests.add(request);
    return request.result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<PostModel> _posts(String label, [int count = 20]) => List.generate(count,
    (index) => PostModel.fromJson({'id': '$label-$index', 'content': label}));

void main() {
  test('Old response cannot replace new category, and All clears tag',
      () async {
    final repo = _Posts();
    final controller = FriendFeedController(repo);
    addTearDown(controller.dispose);
    controller.setFriendsAndLoad(['friend'], tag: 'dog');
    controller.setTag('cat');
    repo.requests[1].result.complete(_posts('cat'));
    await Future<void>.delayed(Duration.zero);
    repo.requests[0].result.complete(_posts('dog'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.posts.first.content, 'cat');
    controller.setTag(null);
    expect(repo.requests.last.tag, isNull);
    repo.requests.last.result.complete(_posts('all'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.posts.first.content, 'all');
  });
  test('Pagination from old category cannot append into new category',
      () async {
    final repo = _Posts();
    final controller = FriendFeedController(repo);
    addTearDown(controller.dispose);
    controller.setFriendsAndLoad(['friend'], tag: 'dog');
    repo.requests[0].result.complete(_posts('dog'));
    await Future<void>.delayed(Duration.zero);
    final more = controller.loadMore();
    expect(repo.requests[1].page, 2);
    controller.setTag('cat');
    repo.requests[2].result.complete(_posts('cat', 1));
    await Future<void>.delayed(Duration.zero);
    repo.requests[1].result.complete(_posts('old dog page'));
    await more;
    expect(controller.state.posts.single.content, 'cat');
    expect(controller.state.page, 1);
  });
}
