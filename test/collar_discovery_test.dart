import 'package:flutter/material.dart';
import 'package:petpogo_app/features/bind_device/widgets/collar_binding_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/bind_device/collar_bluetooth_access_dialog.dart';
import 'package:petpogo_app/features/bind_device/services/collar_bluetooth_access.dart';
import 'package:petpogo_app/features/bind_device/widgets/collar_discovery_panel.dart';

void main() {
  testWidgets('binding status fits compact viewport without scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(320, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(padding: const EdgeInsets.all(20), children: const [
      CollarSetupSteps(current: 2, finalLabel: '确认绑定'),
      CollarBindingStatus(
          bound: false,
          waiting: true,
          saved: true,
          reconfiguring: false,
          seconds: 12,
          queryFailed: false),
    ]))));
    expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .maxScrollExtent,
        0);
    expect(find.text('预计最多等待 48 秒'), findsOneWidget);
    expect(find.text('WiFi 配置已保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unconfirmed save and query failure stay visible',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: CollarBindingStatus(
                bound: false,
                waiting: true,
                saved: false,
                reconfiguring: true,
                seconds: 1,
                queryFailed: true))));
    expect(find.text('WiFi 配置已保存'), findsNothing);
    expect(find.text('蓝牙已断开，保存结果待确认'), findsOneWidget);
    expect(find.text('暂时无法查询，正在重试'), findsOneWidget);
    expect(find.text('确认目标项圈上线'), findsOneWidget);
  });

  testWidgets('success removes pending instructions', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: CollarBindingStatus(
                bound: true,
                waiting: false,
                saved: true,
                reconfiguring: false,
                seconds: 10,
                queryFailed: false,
                deviceName: '小白的项圈'))));
    expect(find.text('项圈绑定成功'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('小白的项圈已添加到你的设备'), findsOneWidget);
  });

  testWidgets('search animation fills outer circle', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: CollarDiscoveryPanel(
                scanning: true, foundCount: 0, onSearch: null))));
    final ring = find.byType(CircularProgressIndicator);
    expect(tester.getSize(ring), const Size(88, 88));
    expect(tester.getCenter(ring),
        tester.getCenter(find.byIcon(Icons.bluetooth_rounded)));
  });

  testWidgets('discovered collar offers next step while scan is active',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: CollarDiscoveryPanel(
                scanning: true, foundCount: 1, onSearch: null))));
    expect(find.text('发现附近的项圈'), findsOneWidget);
    expect(find.text('选择下方设备，继续设置 WiFi'), findsOneWidget);
    expect(find.text('正在寻找项圈'), findsNothing);
  });

  testWidgets('permission denial blocks entry; successful recheck allows entry',
      (tester) async {
    var access = CollarBluetoothAccess.denied;
    var entered = false;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      final allowed = await showDialog<bool>(
                          context: context,
                          builder: (_) => CollarBluetoothAccessDialog(
                              check: ({bool request = false}) async => access));
                      entered = allowed == true;
                    },
                    child: const Text('蓝牙配网'))))));
    await tester.tap(find.text('蓝牙配网'));
    await tester.pumpAndSettle();
    expect(entered, isFalse);
    expect(find.text('打开系统权限设置'), findsOneWidget);
    access = CollarBluetoothAccess.ready;
    await tester.tap(find.text('重新检测'));
    await tester.pumpAndSettle();
    expect(entered, isTrue);
  });

  for (final access in [
    CollarBluetoothAccess.bluetoothOff,
    CollarBluetoothAccess.locationOff
  ]) {
    testWidgets('$access keeps permission gate visible', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: CollarBluetoothAccessDialog(
                  check: ({bool request = false}) async => access))));
      await tester.pumpAndSettle();
      expect(find.text('重新检测'), findsOneWidget);
      expect(find.text('打开系统权限设置'), findsNothing);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('discovery fits narrow screen at text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var searches = 0;
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                  body: ListView(padding: const EdgeInsets.all(24), children: [
                const CollarSetupSteps(current: 0),
                CollarDiscoveryPanel(
                    scanning: false, foundCount: 0, onSearch: () => searches++),
              ])))));
      if (scale == 1.0) {
        expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .maxScrollExtent,
            0);
        expect(find.byIcon(Icons.pets_rounded), findsNothing);
      }
      await tester.ensureVisible(find.text('开始寻找项圈'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始寻找项圈'));
      expect(searches, 1);
      expect(find.text('打开系统权限设置'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
