import 'package:dio/dio.dart';
import 'package:petpogo_app/core/api/peer_api_client.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_peer_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/api_exception.dart';
import 'package:petpogo_app/features/pet/data/models/pet_peer_models.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_repository.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_sync_repository.dart';

/// 可编程行为的假 ApiClient：按调用序号从 [behaviors] 里取一个动作执行。
class _Client implements ApiClient {
  final List<dynamic Function(String path, dynamic data)> behaviors;
  int _call = 0;
  final calls = <({String method, String path, dynamic data})>[];

  _Client(this.behaviors);

  dynamic _run(String method, String path, dynamic data) {
    calls.add((method: method, path: path, data: data));
    final behavior = behaviors[_call++];
    return behavior(path, data);
  }

  @override
  Future<T> post<T>(String path,
      {dynamic data, T Function(dynamic)? fromJson, Options? options}) async {
    final r = _run('POST', path, data);
    return fromJson != null ? fromJson(r) : r as T;
  }

  @override
  Future<T> put<T>(String path,
      {dynamic data, T Function(dynamic)? fromJson}) async {
    final r = _run('PUT', path, data);
    return fromJson != null ? fromJson(r) : r as T;
  }

  @override
  Future<void> delete(String path) async {
    _run('DELETE', path, null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

dynamic _ok(Map<String, dynamic> body) => (String path, dynamic data) => body;

dynamic Function(String, dynamic) _fail(int statusCode, [String msg = '']) =>
    (String path, dynamic data) => throw ApiException(
          message: msg,
          statusCode: statusCode,
        );

const _pet = PetInfoModel(
  petId: 'peer-123',
  petName: '小白',
  breed: '英短',
  sex: 'GG',
  avatar: 'https://x/a.jpg',
  deviceId: 'device-1',
);

void main() {
  test('create and both delete selectors only call the Peer proxy', () async {
    final client = _Client(List.generate(3, (_) => _ok({'code': 0})));
    final repo = PetPeerRepository(PeerApiClient(client));
    final result = await repo.createPet(
      petName: '小白', breed: '英短', age: 2, sex: 'GG', avatar: 'https://x/a.jpg',
    );
    expect(result.isSuccess, isTrue);
    await repo.deletePet(petId: 'peer-123');
    await repo.deletePet(deviceId: 'device-1');
    expect(client.calls.map((c) => c.path), [
      '/sdkapi/peer/pet/info/add',
      '/sdkapi/peer/pet/info/del',
      '/sdkapi/peer/pet/info/del',
    ]);
    expect(client.calls.every((c) => c.method == 'POST'), isTrue);
    expect(Uri.splitQueryString(client.calls[0].data as String), {
      'petName': '小白', 'breed': '英短', 'age': '2', 'sex': 'GG', 'avatar': 'https://x/a.jpg',
    });
    expect(Uri.splitQueryString(client.calls[1].data as String), {'petId': 'peer-123'});
    expect(Uri.splitQueryString(client.calls[2].data as String), {'deviceId': 'device-1'});
  });

  test('Peer create failure returns failure without a fallback SDK create', () async {
    final client = _Client([_fail(502)]);
    final result = await PetPeerRepository(PeerApiClient(client)).createPet(petName: '小白');
    expect(result.isError, isTrue);
    expect(client.calls.length, 1);
    expect(client.calls.single.path, '/sdkapi/peer/pet/info/add');
  });

  group('PetSyncRepository', () {
    test(
        'syncUpdate sends only PUT; create and delete belong to the backend',
        () async {
      final client = _Client([_ok({'success': true})]);
      await PetSyncRepository(PetRepository(client)).syncUpdate(_pet);
      expect(client.calls.length, 1);
      expect(client.calls.single.method, 'PUT');
      expect(client.calls.single.path, '/sdkapi/pet/peer-123');
    });

    test('syncUpdate swallows a failure (e.g. record never synced, 404) without throwing',
        () async {
      final client = _Client([_fail(404)]);
      await PetSyncRepository(PetRepository(client)).syncUpdate(_pet);
      expect(client.calls.length, 1);
      expect(client.calls.single.path, '/sdkapi/pet/peer-123');
    });

  });
}
