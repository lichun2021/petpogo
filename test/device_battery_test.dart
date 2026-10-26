import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/peer_api_client.dart';
import 'package:petpogo_app/core/providers/account_session_provider.dart';
import 'package:petpogo_app/shared/theme/app_colors.dart';
import 'package:petpogo_app/features/device/data/models/device_model.dart';
import 'package:petpogo_app/features/device/data/models/media_model.dart';
import 'package:petpogo_app/features/device/data/repository/device_repository.dart';
import 'package:petpogo_app/features/device/data/repository/media_repository.dart';
import 'package:petpogo_app/features/device/data/wifi_setup_capability.dart';
import 'package:petpogo_app/features/device/device_detail_page.dart';
import 'package:petpogo_app/features/device/widgets/hardware_device_header.dart';
import 'package:petpogo_app/features/device/widgets/hardware_battery_indicator.dart';
import 'package:petpogo_app/features/device/widgets/device_battery_status.dart';
import 'package:petpogo_app/features/device/robot_device_page.dart';
import 'package:petpogo_app/features/device/stream/device_stream_api.dart';
import 'package:petpogo_app/features/pet/data/models/pet_peer_models.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_peer_repository.dart';

const _mac = 'ipet-esp32-Device-03';
const _sample = {
  'code': 0,
  'info': {
    'battery': '57',
    'charge': 'false',
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

class _Media implements MediaRepository {
  @override
  Future<MediaListResult> fetchList({
    String? deviceId,
    int? type,
    int page = 1,
    int pageSize = 20,
  }) async =>
      MediaListResult(total: 0, page: page, pageSize: pageSize, list: const []);

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
    final request = adapter.requests.singleWhere(
        (request) => request.uri.path.endsWith('/device/property/query'));
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

  test(
      'charge accepts boolean and string true without treating false as charging',
      () {
    for (final charge in [true, 'true', 'TRUE', ' true ']) {
      expect(
          PetBattery.fromJson({'battery': '34', 'charge': charge}).isCharging,
          isTrue);
    }
    for (final charge in [
      false,
      'false',
      'FALSE',
      ' false ',
      '',
      null,
      0,
      1,
      '1'
    ]) {
      expect(
          PetBattery.fromJson({'battery': '34', 'charge': charge}).isCharging,
          isFalse);
    }
    expect(PetBattery.fromJson({'battery': '34'}).isCharging, isFalse);
  });

  test('charge remains available when the percentage has not been reported',
      () {
    for (final battery in ['', null, 'bad', -1, 101]) {
      final status =
          PetBattery.fromJson({'battery': battery, 'charge': 'true'});
      expect(status.known, isFalse);
      expect(status.isCharging, isTrue);
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

  Future<void> mount(WidgetTester tester, _Adapter adapter,
      {bool robot = false, Widget? home}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        deviceRepositoryProvider.overrideWithValue(_Devices()),
        deviceListProvider.overrideWith((_) => DeviceListNotifier(_Devices())),
        wifiCollarMacsProvider.overrideWith((_) async => <String>{}),
        petPeerRepositoryProvider.overrideWithValue(repo(adapter)),
        mediaRepositoryProvider.overrideWithValue(_Media()),
        deviceStreamApiProvider.overrideWithValue(
            DeviceStreamApi(PeerApiClient(ApiClient(adapter: adapter)))),
      ],
      child: MaterialApp(
          home: home ??
              (robot
                  ? const RobotDevicePage(mac: _mac, name: '毛毛的机器人')
                  : const DeviceDetailPage(mac: _mac, name: '毛毛的项圈'))),
    ));
  }

  Future<void> mountRobot(WidgetTester tester, _Adapter adapter,
      {Widget? home}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const permissions =
        MethodChannel('flutter.baseflow.com/permissions/methods');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const recorder = MethodChannel('com.llfbandit.record/messages');
    messenger.setMockMethodCallHandler(recorder, (call) async {
      if (call.method == 'hasPermission') return true;
      if (call.method == 'isRecording' || call.method == 'isPaused')
        return false;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(recorder, null));
    // 电量查询独立于摄像头：即使视频初始化失败，也能展示电量。
    messenger.setMockMethodCallHandler(permissions, (_) async {
      throw PlatformException(code: 'camera-unavailable');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(permissions, null));
    await mount(tester, adapter, robot: true, home: home);
    // 机器人页包含持续动画，按帧推进而不等待全部动画结束。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  HardwareBatteryPainter batteryPainter(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(find.descendant(
        of: find.byType(HardwareBatteryIndicator),
        matching: find.byType(CustomPaint)));
    return paint.painter! as HardwareBatteryPainter;
  }

  for (final robot in [false, true]) {
    testWidgets(
        '${robot ? 'robot' : 'collar'} charging icon follows charge even if battery stays the same',
        (tester) async {
      final adapter = _Adapter()
        ..response = {
          'code': 0,
          'info': {'battery': '34', 'charge': 'false'},
        };
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      if (robot) {
        await mountRobot(tester, adapter);
      } else {
        await mount(tester, adapter);
        await tester.pumpAndSettle();
      }
      expect(find.text('34%'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsNothing);

      adapter.response = {
        'code': 0,
        'info': {'battery': '34', 'charge': 'true'}
      };
      await tester.pump(const Duration(seconds: 10));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('34%'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.bolt_rounded));
      expect(icon.color, AppColors.charging);
      expect(batteryPainter(tester).fraction, closeTo(.34, .001));
      expect(batteryPainter(tester).color, AppColors.charging);
      expect(find.textContaining('充电'), findsNothing);

      adapter.response = {
        'code': 0,
        'info': {'battery': '34', 'charge': false}
      };
      await tester.pump(const Duration(seconds: 10));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.bolt_rounded), findsNothing);
      expect(batteryPainter(tester).color, AppColors.textOnBrand);
      expect(find.text('34%'), findsOneWidget);
      for (final level in [50, 19, 20, 0]) {
        adapter.response = {
          'code': 0,
          'info': {'battery': '$level', 'charge': 'false'}
        };
        await tester.pump(const Duration(seconds: 10));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('$level%'), findsOneWidget);
        expect(batteryPainter(tester).fraction, closeTo(level / 100, .001));
        expect(batteryPainter(tester).color,
            level < 20 ? AppColors.batteryLow : AppColors.textOnBrand);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        '${robot ? 'robot' : 'collar'} shows charging without inventing a missing percentage',
        (tester) async {
      final adapter = _Adapter()
        ..response = {
          'code': 0,
          'info': {'battery': '', 'charge': 'true'},
        };
      if (robot) {
        await mountRobot(tester, adapter);
      } else {
        await mount(tester, adapter);
        await tester.pumpAndSettle();
      }
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      expect(tester.widget<Icon>(find.byIcon(Icons.bolt_rounded)).color,
          AppColors.charging);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final robot in [false, true]) {
    for (final success in [true, false]) {
      testWidgets(
          '${robot ? 'robot' : 'collar'} entry hides cached battery and ${success ? 'loads fresh data' : 'keeps failures unknown'}',
          (tester) async {
        final adapter = _Adapter();
        final home = Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => robot
                                  ? const RobotDevicePage(
                                      mac: _mac, name: '毛毛的机器人')
                                  : const DeviceDetailPage(
                                      mac: _mac, name: '毛毛的项圈'))),
                      child: const Text('打开设备详情'),
                    )));
        if (robot) {
          await mountRobot(tester, adapter, home: home);
        } else {
          await mount(tester, adapter, home: home);
          await tester.pumpAndSettle();
        }
        final container =
            ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
        late ProviderSubscription<AsyncValue<PetBattery>> listener;
        final cached = await tester.runAsync(() async {
          listener = container.listen(deviceBatteryProvider(_mac), (_, __) {});
          return container.read(deviceBatteryProvider(_mac).future);
        });
        addTearDown(listener.close);
        expect(cached!.battery, 57);
        final pending = Completer<void>();
        adapter.pendingBattery = pending;
        adapter.response = success
            ? {
                'code': 0,
                'info': {'battery': '34', 'charge': 'true'}
              }
            : {'code': 4, 'info': null, 'tip': '设备暂不可用'};
        await tester.tap(find.text('打开设备详情'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('57%'), findsNothing);
        expect(find.text('—'), findsOneWidget);
        // A slow initial request must not be restarted by the polling timer.
        await tester.pump(const Duration(seconds: 11));
        expect(
            adapter.requests
                .where((r) => r.uri.path.endsWith('/device/property/query')),
            hasLength(2));
        pending.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('57%'), findsNothing);
        expect(find.text(success ? '34%' : '—'), findsOneWidget);
        expect(find.byIcon(Icons.bolt_rounded),
            success ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  for (final robot in [false, true]) {
    testWidgets(
        '${robot ? 'robot' : 'collar'} refreshes on returning and on resuming the app',
        (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final adapter = _Adapter();
      if (robot) {
        await mountRobot(tester, adapter);
      } else {
        await mount(tester, adapter);
        await tester.pumpAndSettle();
      }
      final context = tester.element(find.byType(DeviceBatteryStatus));
      unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('返回设备')),
              ))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final pending = Completer<void>();
      adapter.pendingBattery = pending;
      adapter.response = {
        'code': 0,
        'info': {'battery': '34', 'charge': 'false'}
      };
      await tester.tap(find.text('返回设备'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('57%'), findsNothing);
      expect(find.text('—'), findsOneWidget);
      pending.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('34%'), findsOneWidget);
      adapter.pendingBattery = null;
      adapter.response = {
        'code': 0,
        'info': {'battery': '19', 'charge': 'false'}
      };
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('19%'), findsOneWidget);
      expect(batteryPainter(tester).color, AppColors.batteryLow);
      expect(
          adapter.requests
              .where((r) => r.uri.path.endsWith('/device/property/query')),
          hasLength(3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('robot details use the same signed device battery endpoint',
      (tester) async {
    final adapter = _Adapter();
    await mountRobot(tester, adapter);
    expect(find.text('57%'), findsOneWidget);
    expect(find.byType(HardwareDeviceHeader), findsOneWidget);
    expect(find.textContaining('电量 '), findsNothing);
    final request = adapter.requests.singleWhere(
        (request) => request.uri.path.endsWith('/device/property/query'));
    expect(request.method, 'GET');
    expect(request.uri.path, '/sdkapi/peer/device/property/query');
    expect(request.uri.queryParameters, {'mac': _mac});
    expect(request.headers['Authorization'], 'Bearer test-session');
    expect(request.headers['x-signature-version'], '2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('robot controls remain visible while battery loads',
      (tester) async {
    final pending = Completer<void>();
    final adapter = _Adapter()..pendingBattery = pending;
    await mountRobot(tester, adapter);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('毛毛的机器人'), findsOneWidget);
    expect(find.text('遥控'), findsOneWidget);
    expect(find.text('摄影'), findsOneWidget);
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('57%'), findsOneWidget);
    expect(find.byType(HardwareDeviceHeader), findsOneWidget);
    expect(find.textContaining('电量 '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final robot in [false, true]) {
    testWidgets(
        '${robot ? "robot" : "collar"} battery refreshes every 10 seconds while visible',
        (tester) async {
      final adapter = _Adapter();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      if (robot) {
        await mountRobot(tester, adapter);
      } else {
        await mount(tester, adapter);
        await tester.pumpAndSettle();
      }
      int requests() => adapter.requests
          .where((r) => r.uri.path.endsWith('/device/property/query'))
          .length;
      final initial = requests();
      adapter.response = {
        'code': 0,
        'info': {'battery': '41'}
      };
      await tester.pump(const Duration(seconds: 9));
      expect(requests(), initial);
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
      expect(requests(), initial + 1);
      expect(find.text('41%'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
      expect(requests(), initial + 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('robot details show unknown battery when the query fails',
      (tester) async {
    final adapter = _Adapter()
      ..response = {'code': 4, 'info': null, 'tip': '设备暂不可用'};
    await mountRobot(tester, adapter);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('毛毛的机器人'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collar details show the real percentage from device properties',
      (tester) async {
    final adapter = _Adapter();
    await mount(tester, adapter);
    await tester.pumpAndSettle();
    expect(find.text('57%'), findsOneWidget);
    expect(find.byType(HardwareDeviceHeader), findsOneWidget);
    expect(find.textContaining('电量 '), findsNothing);
    expect(
        adapter.requests.where(
            (request) => request.uri.path.endsWith('/device/property/query')),
        hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('collar keeps a single device title and the rename entry',
      (tester) async {
    await mount(tester, _Adapter());
    await tester.pumpAndSettle();
    expect(find.text('毛毛的项圈'), findsOneWidget);
    await tester.tap(find.byTooltip('修改设备名称'));
    await tester.pumpAndSettle();
    expect(find.text('设备备注'), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '毛毛的项圈');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a slow battery query does not block the device details',
      (tester) async {
    final pending = Completer<void>();
    final adapter = _Adapter()..pendingBattery = pending;
    await mount(tester, adapter);
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('设备码 $_mac'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('57%'), findsOneWidget);
    expect(find.byType(HardwareDeviceHeader), findsOneWidget);
    expect(find.textContaining('电量 '), findsNothing);
  });

  testWidgets('an unavailable battery keeps the rest of the page usable',
      (tester) async {
    final adapter = _Adapter()
      ..response = {'code': 4, 'info': null, 'tip': '设备暂不可用'};
    await mount(tester, adapter);
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('设备码 $_mac'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets(
        'hardware header keeps long names and actions usable at 320 / $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var back = 0;
      var switched = 0;
      var wifi = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
            body: Column(children: [
          HardwareDeviceHeader(
            name: '这是一个很长的硬件设备名称，用来确认切换入口仍可点击',
            batteryPercent: 0,
            online: false,
            onBack: () => back++,
            onSwitchDevice: () => switched++,
            actions: [
              IconButton(
                  tooltip: '重新配网',
                  onPressed: () => wifi++,
                  icon: const Icon(Icons.wifi_rounded)),
              IconButton(
                  tooltip: '添加设备',
                  onPressed: () {},
                  icon: const Icon(Icons.add_circle_outline_rounded)),
            ],
          )
        ])),
      ));
      expect(find.text('0%'), findsOneWidget);
      expect(find.textContaining('电量 '), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('返回'));
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.tap(find.byTooltip('重新配网'));
      expect((back, switched, wifi), (1, 1, 1));
      expect(
          tester
              .getSize(
                  find.widgetWithIcon(IconButton, Icons.arrow_back_ios_rounded))
              .width,
          greaterThanOrEqualTo(48));
    });
  }
}
