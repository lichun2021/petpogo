import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/peer_api_client.dart';
import 'package:petpogo_app/core/providers/account_session_provider.dart';
import 'package:petpogo_app/features/device/data/models/device_model.dart';
import 'package:petpogo_app/features/device/data/repository/device_repository.dart';
import 'package:petpogo_app/features/device/data/wifi_setup_capability.dart';
import 'package:petpogo_app/features/device/device_detail_page.dart';
import 'package:petpogo_app/features/pet/data/models/pet_peer_models.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_peer_repository.dart';

const _mac = 'ipet-esp32-Device-03';
const _sample = {
  'code': 0,
  'info': {
    'battery': '57',
    'temp': '37.5',
    'led_r': '',
    'reportDataTime': 0,
  },
  'tip': '响应成功',
};

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, dynamic> response = _sample;
  Completer<void>? pendingBattery;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancelFuture) async {
    requests.add(options);
    if (options.uri.path.endsWith('/device/property/query') &&
        pendingBattery != null) {
      await pendingBattery!.future;
    }
    return ResponseBody.fromString(jsonEncode(response), 200, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

class _Devices implements DeviceRepository {
  @override
  Future<DeviceDetailModel> fetchDeviceDetail(String mac) async =>
      const DeviceDetailModel(name: '毛毛的项圈', mac: _mac);
  @override
  Future<OtaInfoModel> fetchOtaInfo(String mac) async => const OtaInfoModel();
  @override
  Future<bool> fetchOnlineState(String mac) async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  PetPeerRepository repo(_Adapter adapter) => PetPeerRepository(
      PeerApiClient(ApiClient(token: 'test-session', adapter: adapter)));

  test('battery query uses GET, signed gateway auth and the device MAC',
      () async {
    final adapter = _Adapter();
    final battery = await repo(adapter).fetchBattery(mac: _mac);
    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/sdkapi/peer/device/property/query');
    expect(request.uri.queryParameters, {'mac': _mac});
    expect(request.data, isNull);
    expect(request.headers['Authorization'], 'Bearer test-session');
    expect(request.headers['x-signature-version'], '2');
    expect(request.headers['token'], isNull); // 网关转换上游 token。
    expect(battery.known, isTrue);
    expect(battery.battery, 57);
  });

  test('numeric and string battery levels include a valid zero percent', () {
    for (final raw in ['57', 57, 57.0, '57.0', ' 57 ', 0, '0', 100, '100']) {
      final value = PetBattery.fromJson({'battery': raw});
      expect(value.known, isTrue, reason: '$raw');
      expect(value.battery, inInclusiveRange(0, 100));
    }
    expect(PetBattery.fromJson({'battery': '0'}).isLow, isTrue);
    expect(PetBattery.fromJson({'battery': '20'}).isLow, isFalse);
  });

  test('missing, malformed and out-of-range levels remain unknown', () {
    for (final raw in [
      null,
      '',
      ' ',
      'bad',
      -1,
      '-1',
      101,
      'NaN',
      'Infinity'
    ]) {
      final value = PetBattery.fromJson({'battery': raw});
      expect(value.known, isFalse, reason: '$raw');
      expect(value.battery, -1);
      expect(value.isLow, isFalse);
    }
  });

  test('empty device ID and absent info never become zero percent', () async {
    final adapter = _Adapter()..response = {'code': 0, 'info': null};
    final repository = repo(adapter);
    expect((await repository.fetchBattery(mac: '')).known, isFalse);
    expect(adapter.requests, isEmpty);
    expect((await repository.fetchBattery(mac: _mac)).known, isFalse);
  });

  test('business errors propagate instead of displaying a sample percentage',
      () async {
    final adapter = _Adapter()
      ..response = {'code': 3, 'info': null, 'tip': '设备暂不可用'};
    await expectLater(
        repo(adapter).fetchBattery(mac: _mac), throwsA(isA<Exception>()));
  });

  test('account change reloads the per-device battery cache', () async {
    final adapter = _Adapter();
    final container = ProviderContainer(overrides: [
      petPeerRepositoryProvider.overrideWithValue(repo(adapter)),
    ]);
    addTearDown(container.dispose);
    final listener = container.listen(deviceBatteryProvider(_mac), (_, __) {});
    addTearDown(listener.close);
    expect(
        (await container.read(deviceBatteryProvider(_mac).future)).battery, 57);
    adapter.response = {
      'code': 0,
      'info': {'battery': '19'}
    };
    container.read(accountSessionProvider.notifier).state++;
    expect(
        (await container.read(deviceBatteryProvider(_mac).future)).battery, 19);
    expect(adapter.requests, hasLength(2));
  });

  Future<void> mount(WidgetTester tester, _Adapter adapter) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        deviceRepositoryProvider.overrideWithValue(_Devices()),
        deviceListProvider.overrideWith((_) => DeviceListNotifier(_Devices())),
        wifiCollarMacsProvider.overrideWith((_) async => <String>{}),
        petPeerRepositoryProvider.overrideWithValue(repo(adapter)),
      ],
      child:
          const MaterialApp(home: DeviceDetailPage(mac: _mac, name: '毛毛的项圈')),
    ));
  }

  testWidgets('collar details show the real percentage from device properties',
      (tester) async {
    final adapter = _Adapter();
    await mount(tester, adapter);
    await tester.pumpAndSettle();
    expect(find.text('电量 57%'), findsOneWidget);
    expect(
        adapter.requests.where(
            (request) => request.uri.path.endsWith('/device/property/query')),
        hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a slow battery query does not block the device details',
      (tester) async {
    final pending = Completer<void>();
    final adapter = _Adapter()..pendingBattery = pending;
    await mount(tester, adapter);
    await tester.pumpAndSettle();
    expect(find.text('电量 -'), findsOneWidget);
    expect(find.textContaining('设备码 $_mac'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('电量 57%'), findsOneWidget);
  });

  testWidgets('an unavailable battery keeps the rest of the page usable',
      (tester) async {
    final adapter = _Adapter()
      ..response = {'code': 4, 'info': null, 'tip': '设备暂不可用'};
    await mount(tester, adapter);
    await tester.pumpAndSettle();
    expect(find.text('电量 -'), findsOneWidget);
    expect(find.textContaining('设备码 $_mac'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
