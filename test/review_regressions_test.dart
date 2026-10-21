import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/logging/app_log.dart';
import 'package:petpogo_app/shared/theme/app_colors.dart';
import 'package:petpogo_app/shared/theme/color_schemes.dart';
import 'package:petpogo_app/shared/utils/oss_uploader.dart';
import 'package:petpogo_app/shared/widgets/glass_bottom_nav.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <List<int>>[];
  int status = 200;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    bodies.add(
        stream == null ? [] : await stream.expand((bytes) => bytes).toList());
    return ResponseBody.fromString('{}', status, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.5, 2.0, 3.0]) {
      testWidgets('navigation fits width $width and text scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              bottomNavigationBar:
                  GlassBottomNav(currentIndex: 0, onTap: (_) {}, items: const [
            NavItem(icon: Icons.home_outlined, label: '首页'),
            NavItem(icon: Icons.pets_outlined, label: 'Digital pet'),
            NavItem(icon: Icons.people_outline, label: '社区'),
            NavItem(icon: Icons.pets_outlined, label: '萌宠圈'),
            NavItem(icon: Icons.person_outline, label: '我的'),
          ])),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(NavButton).first).height,
            greaterThanOrEqualTo(48));
        expect(find.text('萌宠圈'), findsOneWidget);
      });
    }
  }

  test('metadata text has readable contrast across the selectable themes', () {
    addTearDown(() => AppColors.setScheme(warmPinkScheme));
    for (final scheme in kColorSchemes) {
      AppColors.setScheme(scheme);
      for (final background in [
        AppColors.surfacePage,
        AppColors.surfaceCard,
        AppColors.surfaceSunken
      ]) {
        final a = AppColors.textTertiary.computeLuminance();
        final b = background.computeLuminance();
        final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: scheme.key);
      }
    }
  });

  test('logs remove URL credentials, quoted secrets, share codes and phones',
      () {
    final safe = AppLog.redact(
        'https://user:pass@oss.example/file?signature=private#secret '
        'petpogo://share?code=share-secret Bearer access-secret '
        'password="secret with spaces" {"refreshToken":"refresh-secret"} '
        'code=private-code phone=13812345678');
    for (final secret in [
      'user:pass',
      'private',
      'access-secret',
      'secret with spaces',
      'refresh-secret',
      'share-secret',
      '13812345678'
    ]) {
      expect(safe, isNot(contains(secret)));
    }
    expect(safe, contains('138****5678'));
  });

  test('operational logs use an allowlist instead of recording payloads', () {
    final original = debugPrint;
    final messages = <String>[];
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    try {
      AppLog.event('http.error', level: 'warning', fields: {
        'requestId': 'request-1',
        'status': 403,
        'password': 'secret',
        'body': 'private',
      });
    } finally {
      debugPrint = original;
    }
    final event = jsonDecode(messages.single) as Map;
    expect(event['requestId'], 'request-1');
    expect(event.containsKey('password'), isFalse);
    expect(event.containsKey('body'), isFalse);
  });

  test(
      'authenticated client rejects external and cleartext destinations before sending',
      () async {
    final adapter = _Adapter();
    final client = ApiClient(token: 'private', adapter: adapter);
    for (final url in [
      'https://untrusted.example/sdkapi/private',
      'http://api.jxpetai.com/sdkapi/private'
    ]) {
      await expectLater(client.get<dynamic>(url), throwsA(isA<DioException>()));
    }
    expect(adapter.requests, isEmpty);
  });

  test('parallel requests have distinct correlation IDs', () async {
    final adapter = _Adapter();
    final client = ApiClient(adapter: adapter);
    await Future.wait(
        [client.get<dynamic>('/sdkapi/a'), client.get<dynamic>('/sdkapi/a')]);
    final ids = adapter.requests
        .map((request) => request.headers['X-Request-ID'])
        .toSet();
    expect(ids.length, 2);
    expect(ids, isNot(contains(null)));
  });

  test('HTTP failures retain their correlation ID in operational logs',
      () async {
    final adapter = _Adapter()..status = 503;
    final client = ApiClient(adapter: adapter);
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    try {
      await expectLater(client.get<dynamic>('/sdkapi/unavailable'),
          throwsA(isA<DioException>()));
    } finally {
      debugPrint = original;
    }
    final error = messages
        .map((message) => jsonDecode(message) as Map)
        .singleWhere((event) => event['event'] == 'http.error');
    expect(error['status'], 503);
    expect(error['requestId'], adapter.requests.single.headers['X-Request-ID']);
    expect(error['durationMs'], isA<int>());
  });

  test(
      'shared uploader streams exact bytes without auth or inferred Content-Type',
      () async {
    final adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final uploader = OssUploader(ApiClient(), uploadClient: dio);
    await uploader.uploadBytes(
        uploadUrl: 'https://oss.example/file?signature=private',
        bytes: [0, 1, 255]);
    expect(adapter.bodies.single, [0, 1, 255]);
    expect(adapter.requests.single.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')));
    expect(adapter.requests.single.contentType, isNull);
    adapter.status = 302;
    await expectLater(
        uploader.uploadBytes(uploadUrl: 'https://oss.example/file', bytes: [1]),
        throwsA(isA<DioException>()));
    final before = adapter.requests.length;
    await expectLater(
        uploader.uploadBytes(uploadUrl: 'http://oss.example/file', bytes: [1]),
        throwsA(isA<ArgumentError>()));
    expect(adapter.requests.length, before);
    dio.close();
  });
}
