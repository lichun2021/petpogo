import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petpogo_app/app.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:petpogo_app/features/auth/data/auth_repository.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/api_exception.dart';
import 'package:petpogo_app/features/auth/data/country_repository.dart';
import 'package:petpogo_app/features/profile/data/points_repository.dart';
import 'package:petpogo_app/features/profile/points_page.dart';
import 'package:petpogo_app/features/profile/check_in_page.dart';
import 'package:petpogo_app/features/profile/membership_page.dart';
import 'package:petpogo_app/shared/widgets/app_error_view.dart';

class _FailingClient implements ApiClient {
  final calls = <String>[];
  final int statusCode;
  _FailingClient({this.statusCode = 503});
  @override
  Future<T> post<T>(String path,
      {dynamic data, T Function(dynamic)? fromJson, Options? options}) async {
    calls.add(path);
    throw ApiException(message: '服务暂不可用', statusCode: statusCode);
  }

  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? params, T Function(dynamic)? fromJson}) async {
    calls.add(path);
    throw ApiException(message: '服务暂不可用', statusCode: statusCode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
      'login saves refresh credentials, rotation persists both tokens, logout removes them',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final client = _RefreshClient();
    final repo = AuthRepository(client, storage);
    final login = await repo.loginWithSms(phone: '13800138000', code: '123456');
    expect(login.isSuccess, isTrue);
    expect(await storage.read(key: 'auth_refresh_token'), 'refresh-one');
    expect(await repo.refreshSession(), 'access-two');
    expect(client.payloads.last, {'refreshToken': 'refresh-one'});
    expect(await storage.read(key: 'auth_token'), 'access-two');
    expect(await storage.read(key: 'auth_refresh_token'), 'refresh-two');
    await repo.logout();
    expect(await storage.read(key: 'auth_token'), isNull);
    expect(await storage.read(key: 'auth_refresh_token'), isNull);
  });

  test('login and password-reset SMS have distinct purposes', () async {
    final client = _PasswordClient();
    final repo = AuthRepository(client, const FlutterSecureStorage());
    expect((await repo.sendSms('13800138000')).isSuccess, isTrue);
    expect(client.payloads.last,
        {'phone': '13800138000', 'nationNum': '86', 'purpose': 'login'});
    expect(
        (await repo.sendSms('13800138000', purpose: 'password_reset'))
            .isSuccess,
        isTrue);
    expect(client.payloads.last['purpose'], 'password_reset');
  });
  test(
      'password setup sends code without old password; normal change sends old password',
      () async {
    final client = _PasswordClient();
    final repo = AuthRepository(client, const FlutterSecureStorage());
    expect(
        (await repo.changePassword(
                code: '123456', newPassword: 'PersonalPassword9'))
            .isSuccess,
        isTrue);
    expect(client.paths.last, '/sdkapi/user/password');
    expect(client.payloads.last,
        {'code': '123456', 'newPassword': 'PersonalPassword9'});
    expect(
        (await repo.changePassword(
                oldPassword: 'OldPassword9', newPassword: 'PersonalPassword9'))
            .isSuccess,
        isTrue);
    expect(client.payloads.last,
        {'oldPassword': 'OldPassword9', 'newPassword': 'PersonalPassword9'});
    final count = client.paths.length;
    expect(
        (await repo.changePassword(newPassword: 'PersonalPassword9')).isError,
        isTrue);
    expect(
        (await repo.changePassword(
                code: '123456',
                oldPassword: 'OldPassword9',
                newPassword: 'PersonalPassword9'))
            .isError,
        isTrue);
    expect(client.paths.length, count);
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PetPogoApp()));
    expect(find.byType(ProviderScope), findsOneWidget);
  });

  test('session validation does not accept a server failure as a valid token',
      () async {
    final repo = AuthRepository(_FailingClient(), const FlutterSecureStorage());
    await expectLater(repo.verifyToken(), throwsA(isA<ApiException>()));
  });
  test('session validation identifies an expired token', () async {
    final repo = AuthRepository(
        _FailingClient(statusCode: 401), const FlutterSecureStorage());
    expect(await repo.verifyToken(), isFalse);
  });
  test('country failures propagate instead of returning a fabricated list',
      () async {
    final client = _FailingClient();
    final repo = CountryRepository(client);
    await expectLater(repo.fetchList(), throwsA(isA<ApiException>()));
    await expectLater(repo.fetchDefault(), throwsA(isA<ApiException>()));
    expect(client.calls.length, 2);
  });

  for (final page in <Widget>[
    const PointsPage(),
    const CheckInPage(),
    const MembershipPage()
  ]) {
    testWidgets('${page.runtimeType} shows a retryable error without mock data',
        (tester) async {
      final client = _FailingClient();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          pointsRepositoryProvider.overrideWithValue(PointsRepository(client))
        ],
        child: MaterialApp(home: page),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      final before = client.calls.length;
      final error = tester.widget<AppErrorView>(find.byType(AppErrorView));
      error.onRetry!();
      await tester.pumpAndSettle();
      expect(client.calls.length, greaterThan(before));
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _PasswordClient implements ApiClient {
  final paths = <String>[];
  final payloads = <Map<String, dynamic>>[];
  @override
  Future<T> post<T>(String path,
      {dynamic data, T Function(dynamic)? fromJson, Options? options}) async {
    paths.add(path);
    payloads.add(Map<String, dynamic>.from(data as Map));
    return {'success': true} as T;
  }

  @override
  Future<T> put<T>(String path,
      {dynamic data, T Function(dynamic)? fromJson}) async {
    paths.add(path);
    payloads.add(Map<String, dynamic>.from(data as Map));
    return {'success': true, 'reLoginRequired': true} as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RefreshClient extends _PasswordClient {
  @override
  Future<T> post<T>(String path,
      {dynamic data, T Function(dynamic)? fromJson, Options? options}) async {
    paths.add(path);
    payloads.add(Map<String, dynamic>.from(data as Map));
    return (path.endsWith('/refresh')
        ? {
            'token': 'access-two',
            'peer': {'refreshToken': 'refresh-two'}
          }
        : {
            'token': 'access-one',
            'user': {'id': '1', 'phone': '13800138000'},
            'peer': {'refreshToken': 'refresh-one'}
          }) as T;
  }

  @override
  void setToken(String token) {}
  @override
  void clearToken() {}
}
