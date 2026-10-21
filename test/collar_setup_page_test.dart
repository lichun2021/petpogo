import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/features/auth/data/auth_repository.dart';
import 'package:petpogo_app/features/auth/data/models/auth_model.dart';
import 'package:petpogo_app/features/bind_device/collar_bluetooth_setup_page.dart';
import 'package:petpogo_app/features/bind_device/services/collar_bluetooth_service.dart';
import 'package:petpogo_app/features/bind_device/services/collar_provisioning_protocol.dart';
import 'package:petpogo_app/features/bind_device/services/current_wifi.dart';
import 'package:petpogo_app/features/device/data/repository/device_repository.dart';

class _FakeService extends CollarBluetoothService {
  _FakeService(this._results);
  final Future<List<ScanResult>> Function() _results;
  @override
  Future<void> scan(void Function(List<ScanResult>) onResults) async =>
      onResults(await _results());
  @override
  Future<void> close() async {}
}

class _Client implements ApiClient {
  @override
  Future<String?> Function()? onRefreshToken;
  @override
  VoidCallback? onUnauthorized;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GuestRepo implements AuthRepository {
  @override
  Future<UserInfo?> restoreSession() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Devices implements DeviceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnavailableWifi extends CurrentWifiReader {
  const _UnavailableWifi();
  @override
  Future<CurrentWifiResult> read({bool requestPermission = true}) async =>
      const CurrentWifiResult.failure(CurrentWifiIssue.unavailable);
}

ScanResult _collar([String id = 'AA:BB:CC:DD:EE:01']) => ScanResult(
    device: BluetoothDevice.fromId(id),
    advertisementData: AdvertisementData(
        advName: CollarProvisioningProtocol.deviceName,
        txPowerLevel: null,
        appearance: null,
        connectable: true,
        manufacturerData: const {},
        serviceData: const {},
        serviceUuids: const []),
    rssi: -50,
    timeStamp: DateTime(2026, 10, 20));

Widget _page(_FakeService service,
        {double scale = 1, String? existingMac, String? deviceName}) =>
    ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_Client()),
          authRepositoryProvider.overrideWithValue(_GuestRepo()),
          deviceRepositoryProvider.overrideWithValue(_Devices()),
          currentWifiReaderProvider.overrideWithValue(const _UnavailableWifi()),
        ],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: CollarBluetoothSetupPage(
                productKey: 'collar',
                existingMac: existingMac,
                deviceName: deviceName,
                service: service)));

void _surface(WidgetTester tester, {double width = 390}) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('a single collar leads to the WiFi form and validates the name',
      (tester) async {
    _surface(tester);
    await tester.pumpWidget(_page(_FakeService(() async => [_collar()])));
    await tester.pumpAndSettle();
    expect(find.text('发现附近的项圈'), findsOneWidget);
    await tester.tap(find.text('宠物智能项圈'));
    await tester.pumpAndSettle();
    expect(find.text('为项圈设置 WiFi'), findsOneWidget);
    expect(find.text('已选择，等待连接'), findsOneWidget);
    await tester.tap(find.text('配网并绑定账号'));
    await tester.pumpAndSettle();
    expect(find.text(CollarProvisioningProtocol.validateSsid('')!),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same-named collars stay unselectable until only one is left',
      (tester) async {
    _surface(tester);
    await tester.pumpWidget(_page(
        _FakeService(() async => [_collar(), _collar('AA:BB:CC:DD:EE:02')])));
    await tester.pumpAndSettle();
    expect(find.text('发现多台同名项圈，请关闭其他项圈的配网模式后重新搜索。'), findsOneWidget);
    expect(find.text('同名项圈，暂时无法选择'), findsNWidgets(2));
    await tester.tap(find.text('同名项圈，暂时无法选择').first);
    await tester.pumpAndSettle();
    expect(find.text('为项圈设置 WiFi'), findsNothing);
  });

  testWidgets('a failed search shows the reason and recovers on retry',
      (tester) async {
    _surface(tester);
    var calls = 0;
    const reason = '蓝牙或权限状态已变化，请返回配网入口重新检测';
    await tester.pumpWidget(_page(_FakeService(() async {
      if (calls++ == 0) throw const CollarProvisioningException(reason);
      return [_collar()];
    })));
    await tester.pumpAndSettle();
    expect(find.text(reason), findsOneWidget);
    await tester.tap(find.text('重新搜索'));
    await tester.pumpAndSettle();
    expect(find.text(reason), findsNothing);
    expect(find.text('发现附近的项圈'), findsOneWidget);
  });

  testWidgets('an empty search suggests checking the blue light',
      (tester) async {
    _surface(tester);
    await tester.pumpWidget(_page(_FakeService(() async => [])));
    await tester.pumpAndSettle();
    expect(find.text('暂未发现项圈，请确认蓝灯闪烁，并将项圈靠近手机后重新搜索。'), findsOneWidget);
    expect(find.text('重新搜索'), findsOneWidget);
  });

  testWidgets('the radar stays on screen until the search finishes',
      (tester) async {
    _surface(tester);
    final pending = Completer<List<ScanResult>>();
    await tester.pumpWidget(_page(_FakeService(() => pending.future)));
    await tester.pump();
    expect(find.text('正在寻找项圈'), findsOneWidget);
    expect(find.text('搜索中…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete([_collar()]);
    await tester.pumpAndSettle();
    expect(find.text('发现附近的项圈'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('submitting without a signed-in account keeps the input',
      (tester) async {
    _surface(tester);
    await tester.pumpWidget(_page(_FakeService(() async => [_collar()])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('宠物智能项圈'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'HomeWiFi');
    await tester.enterText(find.byType(TextFormField).last, 'secret-pass');
    await tester.tap(find.text('配网并绑定账号'));
    await tester.pumpAndSettle();
    expect(find.text('请先登录账号，再进行蓝牙绑定'), findsOneWidget);
    expect(find.text('项圈已重启，查看设备列表'), findsOneWidget);
    expect(find.text('HomeWiFi'), findsOneWidget);
    expect(find.text('配网并绑定账号'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('form and error card fit 320 wide at scale $scale',
        (tester) async {
      _surface(tester, width: 320);
      await tester.pumpWidget(
          _page(_FakeService(() async => [_collar()]), scale: scale));
      await tester.pumpAndSettle();
      await tester.tap(find.text('宠物智能项圈'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Home');
      await tester.scrollUntilVisible(find.text('配网并绑定账号'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('配网并绑定账号'));
      await tester.pumpAndSettle();
      expect(find.text('请先登录账号，再进行蓝牙绑定'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('re-provisioning keeps the collar bound to the account',
      (tester) async {
    _surface(tester);
    await tester.pumpWidget(_page(_FakeService(() async => [_collar()]),
        existingMac: 'AA:BB:CC:DD:EE:01', deviceName: '小白的项圈'));
    await tester.pumpAndSettle();
    expect(find.text('更换项圈 WiFi'), findsOneWidget);
    expect(find.text('正在为「小白的项圈」更换 WiFi，仍绑定当前账号'), findsOneWidget);
    await tester.tap(find.text('宠物智能项圈'));
    await tester.pumpAndSettle();
    expect(find.text('更新 WiFi 并重新连接'), findsOneWidget);
    expect(find.text('确认上线'), findsOneWidget);
  });

  testWidgets('changing the collar clears the previous error', (tester) async {
    _surface(tester);
    await tester.pumpWidget(_page(_FakeService(() async => [_collar()])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('宠物智能项圈'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'HomeWiFi');
    await tester.tap(find.text('配网并绑定账号'));
    await tester.pumpAndSettle();
    expect(find.text('请先登录账号，再进行蓝牙绑定'), findsOneWidget);
    await tester.tap(find.text('更换'));
    await tester.pumpAndSettle();
    expect(find.text('请先登录账号，再进行蓝牙绑定'), findsNothing);
    expect(find.text('发现附近的项圈'), findsOneWidget);
  });

  testWidgets('diagnostics sheet lists what the page recorded', (tester) async {
    _surface(tester);
    await tester.pumpWidget(_page(_FakeService(() async => [_collar()])));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('配网诊断记录'));
    await tester.pumpAndSettle();
    expect(find.text('配网诊断记录'), findsOneWidget);
    expect(find.text('复制日志'), findsOneWidget);
    expect(find.textContaining('scan results: 1 matching collars'),
        findsOneWidget);
  });
}
