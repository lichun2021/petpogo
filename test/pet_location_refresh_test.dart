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
import 'package:petpogo_app/features/pet/services/pet_location_services.dart';
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
  Object? error;
  @override
  Future<PetPositionModel> fetchPosition(
      {String? mac, String? deviceId}) async {
    queries++;
    if (error != null) throw error!;
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
    {Widget? child,
    double scale = 1,
    DateTime Function()? clock,
    PetAddressLookup? addressLookup}) async {
  final previous = HttpOverrides.current;
  HttpOverrides.global = _ImageOverrides();
  addTearDown(() => HttpOverrides.global = previous);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        petPeerRepositoryProvider.overrideWithValue(repo),
        petLocationClockProvider
            .overrideWithValue(clock ?? () => DateTime(2026, 10, 23, 9, 30)),
        petAddressLookupProvider
            .overrideWithValue(addressLookup ?? (lat, lng) async => ''),
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

  testWidgets(
      'refresh time advances even when coordinates and report time are unchanged',
      (tester) async {
    final repo = _Positions();
    var now = DateTime(2026, 10, 23, 9, 30);
    await _mount(tester, repo, clock: () => now);
    final originalReport =
        tester.widget<Text>(find.textContaining('设备上报 ')).data;
    expect(find.text('刷新 09:30:00'), findsOneWidget);
    now = now.add(const Duration(seconds: 7));
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.queries, 2);
    expect(find.text('设备尚未上报新位置'), findsOneWidget);
    expect(find.text('刷新 09:30:07'), findsOneWidget);
    expect(find.text(originalReport!), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'failed refresh shows the attempt time and keeps the last report time',
      (tester) async {
    final repo = _Positions();
    var now = DateTime(2026, 10, 23, 9, 30);
    await _mount(tester, repo, clock: () => now);
    final originalReport =
        tester.widget<Text>(find.textContaining('设备上报 ')).data;
    now = now.add(const Duration(seconds: 12));
    repo.error = StateError('test connection failed');
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('刷新失败 09:30:12'), findsOneWidget);
    expect(find.text(originalReport!), findsOneWidget);
    expect(find.byType(MarkerLayer), findsOneWidget);
  });

  test('unreported-address placeholders are missing data rather than addresses',
      () {
    for (final address in [
      '',
      ' ',
      '地址未上报',
      '未上报地址',
      '地址没有上报',
      '未知',
      'null',
      'UNKNOWN'
    ]) {
      expect(PetPositionModel(address: address).reportedAddress, isEmpty);
    }
    expect(
        const PetPositionModel(address: ' 深圳市南山区 ').reportedAddress, '深圳市南山区');
  });

  testWidgets('valid device coordinates resolve an unreported address',
      (tester) async {
    final repo = _Positions()
      ..position = const PetPositionModel(
        latitude: '22.543',
        longitude: '113.935',
        address: '地址未上报',
        reportTime: 1792627200000,
      );
    final coordinates = <(double, double)>[];
    await _mount(tester, repo, addressLookup: (lat, lng) async {
      coordinates.add((lat, lng));
      return '深圳市南山区';
    });
    expect(coordinates, [(22.543, 113.935)]);
    expect(find.textContaining('深圳市南山区', findRichText: true), findsOneWidget);
    expect(find.textContaining('地址未上报', findRichText: true), findsNothing);
    expect(find.byType(MarkerLayer), findsOneWidget);
  });

  testWidgets('same coordinates keep their resolved address across refreshes',
      (tester) async {
    final repo = _Positions()
      ..position = const PetPositionModel(
        latitude: '22.543',
        longitude: '113.935',
        address: '',
        reportTime: 1792627200000,
      );
    var lookups = 0;
    await _mount(tester, repo, addressLookup: (lat, lng) async {
      lookups++;
      return '深圳市南山区';
    });
    repo.position = const PetPositionModel(
      latitude: '22.5430',
      longitude: '113.9350',
      address: '地址未上报',
      reportTime: 1792627260000,
    );
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('深圳市南山区', findRichText: true), findsOneWidget);
    expect(lookups, 1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an old address lookup cannot overwrite the new device position',
      (tester) async {
    final repo = _Positions()
      ..position = const PetPositionModel(
        latitude: '22.543',
        longitude: '113.935',
        reportTime: 1792627200000,
      );
    final oldLookup = Completer<String>();
    await _mount(tester, repo, addressLookup: (lat, lng) async {
      if (lat == 22.543) return oldLookup.future;
      return '新的位置地址';
    });
    repo.position = const PetPositionModel(
      latitude: '23.13',
      longitude: '113.26',
      reportTime: 1792627260000,
    );
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    oldLookup.complete('旧的位置地址');
    await tester.pump();
    expect(find.textContaining('新的位置地址', findRichText: true), findsOneWidget);
    expect(find.textContaining('旧的位置地址', findRichText: true), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('refresh during address lookup reuses the pending lookup',
      (tester) async {
    final repo = _Positions()
      ..position = const PetPositionModel(
        latitude: '22.543',
        longitude: '113.935',
        reportTime: 1792627200000,
      );
    final pending = Completer<String>();
    var lookups = 0;
    await _mount(tester, repo, addressLookup: (lat, lng) {
      lookups++;
      return pending.future;
    });
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(lookups, 1);
    pending.complete('深圳市南山区');
    await tester.pump();
    expect(find.textContaining('深圳市南山区', findRichText: true), findsOneWidget);
    expect(find.text('正在解析地址...'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'address lookup failure keeps coordinates and can retry on refresh',
      (tester) async {
    final repo = _Positions()
      ..position = const PetPositionModel(
        latitude: '22.543',
        longitude: '113.935',
        reportTime: 1792627200000,
      );
    var lookups = 0;
    await _mount(tester, repo, addressLookup: (lat, lng) async {
      if (++lookups == 1) throw StateError('test geocoder unavailable');
      return '深圳市南山区';
    });
    expect(find.textContaining('地址暂未解析', findRichText: true), findsOneWidget);
    expect(find.textContaining('22.543, 113.935', findRichText: true),
        findsOneWidget);
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(lookups, 2);
    expect(find.textContaining('深圳市南山区', findRichText: true), findsOneWidget);
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
