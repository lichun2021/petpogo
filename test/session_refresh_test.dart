import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:petpogo_app/features/bind_device/services/provisioning_account.dart';
import 'package:petpogo_app/shared/utils/error_presenter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/features/auth/data/auth_repository.dart';

class SessionAdapter implements HttpClientAdapter {
  final requests = <Map<String, dynamic>>[];
  int refreshes = 0;
  int refreshStatus = 200;
  String refreshMessage = '账号不存在';
  bool rejectRetry = false;
  bool rotate = true;
  DioExceptionType? failure;
  Completer<void>? refreshGate;
  Completer<void>? businessGate;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancelFuture) async {
    final bytes = body == null ? <int>[] : await body.expand((b) => b).toList();
    requests.add({
      'path': options.path,
      'headers': Map.of(options.headers),
      'body': utf8.decode(bytes)
    });
    final refreshing = options.path == '/sdkapi/auth/refresh';
    if (refreshing) {
      refreshes++;
      await refreshGate?.future;
      if (failure != null)
        throw DioException(requestOptions: options, type: failure!);
    }
    if (!refreshing) await businessGate?.future;
    final status = refreshing
        ? refreshStatus
        : options.headers['Authorization'] == 'Bearer fresh' && !rejectRetry
            ? 200
            : 401;
    return ResponseBody.fromString(
        jsonEncode(status == 200
            ? refreshing
                ? {
                    'token': 'fresh',
                    'peer': {
                      'granwinToken': 'fresh',
                      if (rotate) 'refreshToken': 'rotated'
                    }
                  }
                : {'ok': true}
            : {'message': refreshing ? refreshMessage : '登录已过期'}),
        status,
        headers: {
          'content-type': ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionAdapter adapter;
  late ApiClient client;
  late AuthRepository repository;
  late FlutterSecureStorage storage;
  late int logouts;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'old',
      'auth_refresh_token': 'refresh',
      'auth_id': 'same-user'
    });
    storage = const FlutterSecureStorage();
    adapter = SessionAdapter();
    client = ApiClient(token: 'old', adapter: adapter);
    repository = AuthRepository(client, storage);
    client.onRefreshToken = repository.refreshSession;
    logouts = 0;
    client.onUnauthorized = () {
      logouts++;
      client.clearToken();
    };
  });
  test(
      'concurrent 401s share refresh, persist credentials, and re-sign each retry',
      () async {
    adapter.refreshGate = Completer<void>();
    final pending =
        List.generate(4, (i) => client.post('/sdkapi/test/$i', data: {'i': i}));
    while (adapter.refreshes == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(adapter.refreshes, 1);
    adapter.refreshGate!.complete();
    await Future.wait(pending);
    expect(adapter.refreshes, 1);
    expect(logouts, 0);
    expect(client.token, 'fresh');
    expect(await storage.read(key: 'auth_token'), 'fresh');
    expect(await storage.read(key: 'auth_peer_granwin_token'), 'fresh');
    expect(await storage.read(key: 'auth_refresh_token'), 'rotated');
    for (var i = 0; i < 4; i++) {
      final calls = adapter.requests
          .where((r) => r['path'] == '/sdkapi/test/$i')
          .toList();
      expect(calls, hasLength(2));
      expect(calls[0]['body'], calls[1]['body']);
      expect(calls[1]['headers']['Authorization'], 'Bearer fresh');
      expect(calls[0]['headers']['x-nonce'],
          isNot(calls[1]['headers']['x-nonce']));
      expect(calls[0]['headers']['x-signature'],
          isNot(calls[1]['headers']['x-signature']));
      expect(calls[1]['headers']['x-timestamp'], isNotNull);
    }
  });
  test(
      'refresh retains provisioning account identity, logout or switch does not',
      () async {
    final before = await repository.restoreSession();
    await client.get('/sdkapi/test');
    final after = await repository.restoreSession();
    expect(before!.token, isNot(after!.token));
    expect(isProvisioningAccount(before.id, after.id), isTrue);
    expect(isProvisioningAccount(before.id, 'another-user'), isFalse);
    expect(isProvisioningAccount(before.id, null), isFalse);
    expect(isProvisioningAccount(null, null), isFalse);
  });
  test('missing rotated refreshToken preserves previous credential', () async {
    adapter.rotate = false;
    await client.get('/sdkapi/test');
    expect(await storage.read(key: 'auth_refresh_token'), 'refresh');
  });
  test(
      'retry 401 stops after one replay and does not invalidate refresh credentials',
      () async {
    adapter.rejectRetry = true;
    await expectLater(repository.verifyToken(), throwsA(isA<DioException>()));
    expect(adapter.refreshes, 1);
    expect(adapter.requests.where((r) => r['path'] == '/sdkapi/user/profile'),
        hasLength(2));
    expect(logouts, 0);
    expect(client.token, 'fresh');
  });
  for (final status in [404, 500, 502, 503, 401]) {
    test(
        'refresh $status with no explicit revocation preserves account and offers retry',
        () async {
      adapter.refreshStatus = status;
      await expectLater(
          client.get('/sdkapi/test'),
          throwsA(isA<DioException>().having(
              (e) => ErrorPresenter.message(e), 'message', contains('重试'))));
      expect(adapter.refreshes, 1);
      expect(logouts, 0);
      expect(client.token, 'old');
      expect(await storage.read(key: 'auth_refresh_token'), 'refresh');
    });
  }
  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.receiveTimeout
  ]) {
    test('refresh $type preserves account', () async {
      adapter.failure = type;
      await expectLater(
          client.get('/sdkapi/test'), throwsA(isA<DioException>()));
      expect(logouts, 0);
      expect(client.token, 'old');
    });
  }
  test('explicit refresh revocation logs out without recursively refreshing',
      () async {
    adapter.refreshStatus = 401;
    adapter.refreshMessage = '登录凭证已失效';
    await expectLater(client.get('/sdkapi/test'), throwsA(isA<DioException>()));
    expect(adapter.refreshes, 1);
    expect(logouts, 1);
    expect(client.token, isNull);
  });
  test('late old-account 401 is not replayed under new account', () async {
    adapter.businessGate = Completer<void>();
    final request = client.get('/sdkapi/test');
    final assertion = expectLater(request, throwsA(isA<DioException>()));
    while (adapter.requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    client.clearToken();
    client.setToken('other-account', newSession: true);
    adapter.businessGate!.complete();
    await assertion;
    expect(client.token, 'other-account');
    expect(adapter.refreshes, 0);
    expect(adapter.requests, hasLength(1));
    expect(logouts, 0);
  });

  test('old refresh completion does not overwrite or log out new account',
      () async {
    final refresh = Completer<String?>();
    var started = false;
    client.onRefreshToken = () {
      started = true;
      return refresh.future;
    };
    final assertion =
        expectLater(client.get('/sdkapi/test'), throwsA(isA<DioException>()));
    while (!started) {
      await Future<void>.delayed(Duration.zero);
    }
    client.clearToken();
    client.setToken('other-account', newSession: true);
    refresh.complete('stale-renewed-token');
    await assertion;
    expect(client.token, 'other-account');
    expect(logouts, 0);
    expect(adapter.requests, hasLength(1));
  });

  test('logout during refresh cannot revive old session', () async {
    adapter.refreshGate = Completer<void>();
    final request = client.get('/sdkapi/test');
    final assertion = expectLater(request, throwsA(isA<DioException>()));
    while (adapter.refreshes == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    await repository.logout();
    adapter.refreshGate!.complete();
    await assertion;
    expect(client.token, isNull);
    expect(await storage.read(key: 'auth_token'), isNull);
  });
}
