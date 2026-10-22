import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/pet/data/models/pet_peer_models.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_peer_repository.dart';
import 'package:petpogo_app/features/pet/fence_manage_page.dart';
import 'package:petpogo_app/features/pet/pet_location_page.dart';
import 'package:petpogo_app/shared/utils/coord_transform.dart';

// Use a local tile image: these tests exercise the map and controls without
// relying on a third-party tile server or swallowing image errors.
final _tile = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=');

class _ImageHeaders implements HttpHeaders {
  @override
  void forEach(void Function(String, List<String>) action) =>
      action('content-type', ['image/png']);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _tile.length;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  bool get persistentConnection => true;
  @override
  String get reasonPhrase => 'OK';
  @override
  HttpHeaders get headers => _ImageHeaders();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(_tile).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ImageRequest implements HttpClientRequest {
  @override
  HttpHeaders get headers => _ImageHeaders();
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  Future<HttpClientResponse> close() async => _ImageResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ImageClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _ImageRequest();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ImageOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _ImageClient();
}

class _Positions implements PetPeerRepository {
  int queries = 0;
  PetPositionModel position = const PetPositionModel(
    latitude: '22.543',
    longitude: '113.935',
    address: '测试位置',
    reportTime: 1792627200000,
  );
  Completer<PetPositionModel>? pending;
  @override
  Future<PetPositionModel> fetchPosition(
      {String? mac, String? deviceId}) async {
    queries++;
    return pending?.future ?? Future.value(position);
  }

  @override
  Future<List<FenceModel>> fetchFences({String? mac, String? deviceId}) async =>
      [
        const FenceModel(
            fenceId: '1',
            fenceName: '家',
            radius: '300',
            latitude: '22.54',
            longitude: '113.93'),
      ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _mount(WidgetTester tester, _Positions repo,
    {Widget? child, double scale = 1}) async {
  final previous = HttpOverrides.current;
  HttpOverrides.global = _ImageOverrides();
  addTearDown(() => HttpOverrides.global = previous);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        petPeerRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child ??
            const PetLocationPage(deviceMac: 'test-device', petName: '毛毛'),
      )));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  test('invalid and placeholder coordinates cannot become a usable location',
      () {
    for (final (lat, lng) in [
      ('', ''),
      ('0', '0'),
      ('NaN', '113'),
      ('22', 'Infinity'),
      ('91', '113'),
      ('22', '181'),
      ('abc', '113'),
    ]) {
      expect(
          PetPositionModel(latitude: lat, longitude: lng).hasLocation, isFalse);
    }
    expect(
        PetPositionModel.fromJson({'latitude': 22.5, 'longitude': 113.9})
            .hasLocation,
        isTrue);
  });

  testWidgets('location does not invent GPS source, fence safety or a radius',
      (tester) async {
    final repo = _Positions();
    await _mount(tester, repo);
    expect(find.text('围栏状态待确认'), findsOneWidget);
    expect(find.text('设备定位'), findsOneWidget);
    expect(find.text('GPS'), findsNothing);
    expect(find.text('安全守护中'), findsNothing);
    expect(find.text('范围内'), findsNothing);
    expect(find.byType(CircleLayer), findsNothing);
    expect(repo.queries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'locator queries again, prevents duplicate taps and centers the new report',
      (tester) async {
    final repo = _Positions();
    await _mount(tester, repo);
    final oldTime = repo.position.reportTime;
    repo.pending = Completer<PetPositionModel>();
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pump();
    expect(repo.queries, 2);
    repo.pending!.complete(PetPositionModel(
        latitude: '23.13',
        longitude: '113.26',
        address: '新的设备上报位置',
        reportTime: oldTime + 60000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('新的设备上报位置', findRichText: true), findsOneWidget);
    final camera = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera;
    final expected = CoordTransform.wgs84ToGcj02(23.13, 113.26);
    expect(camera.center.latitude, closeTo(expected.latitude, .000001));
    expect(camera.center.longitude, closeTo(expected.longitude, .000001));
    expect(find.text('已获取设备上报位置'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unchanged report time remains visible and says no new report',
      (tester) async {
    final repo = _Positions();
    await _mount(tester, repo);
    final time = DateTime.fromMillisecondsSinceEpoch(repo.position.reportTime);
    final label =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.queries, 2);
    expect(find.text('设备尚未上报新位置'), findsOneWidget);
    expect(find.text(label), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('older response cannot replace the newer report on screen',
      (tester) async {
    final repo = _Positions();
    await _mount(tester, repo);
    repo.position = PetPositionModel(
        latitude: '23.13',
        longitude: '113.26',
        address: '过期位置',
        reportTime: repo.position.reportTime - 60000);
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('测试位置', findRichText: true), findsOneWidget);
    expect(find.textContaining('过期位置', findRichText: true), findsNothing);
    expect(find.text('设备尚未上报新位置'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing coordinates do not report a GPS signal failure',
      (tester) async {
    final repo = _Positions()..position = const PetPositionModel();
    await _mount(tester, repo);
    expect(find.text('暂无设备位置'), findsOneWidget);
    expect(find.text('GPS 无信号'), findsNothing);
    expect(find.byType(MarkerLayer), findsNothing);
    expect(find.byType(CircleLayer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location card and locator fit a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _mount(tester, _Positions(), scale: 2);
    expect(tester.takeException(), isNull);
    final locator = tester.getRect(find.byIcon(Icons.my_location_rounded));
    expect(locator.bottom,
        lessThan(tester.getRect(find.byType(SingleChildScrollView)).top));
  });

  testWidgets('fence list no longer hardcodes every fence as active',
      (tester) async {
    await _mount(tester, _Positions(),
        child: const FenceManagePage(
          deviceMac: 'test-device',
          petName: '毛毛',
        ));
    expect(find.text('活跃'), findsNothing);
    expect(find.text('状态待确认'), findsOneWidget);
    expect(find.text('半径 300m'), findsOneWidget);
  });
}
