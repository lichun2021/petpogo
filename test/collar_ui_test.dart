import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/bind_device/collar_bluetooth_access_dialog.dart';
import 'package:petpogo_app/features/bind_device/services/collar_bluetooth_access.dart';
import 'package:petpogo_app/features/bind_device/widgets/collar_binding_status.dart';
import 'package:petpogo_app/features/bind_device/widgets/collar_discovery_panel.dart';
import 'package:petpogo_app/features/bind_device/widgets/collar_ui.dart';

Widget _host(Widget body, {double scale = 1, bool disableAnimations = false}) =>
    MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: disableAnimations),
            child: child!),
        home: Scaffold(body: body));

void _narrow(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('setup steps check off finished steps', (tester) async {
    await tester.pumpWidget(_host(const CollarSetupSteps(current: 2)));
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
    await tester
        .pumpWidget(_host(const CollarSetupSteps(current: 2, completed: true)));
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
  });

  testWidgets('notice card pairs every tone with its own icon', (tester) async {
    for (final (tone, icon) in [
      (CollarNoticeTone.info, Icons.info_outline_rounded),
      (CollarNoticeTone.warning, Icons.warning_amber_rounded),
      (CollarNoticeTone.error, Icons.error_outline_rounded),
    ]) {
      await tester
          .pumpWidget(_host(CollarNoticeCard(tone: tone, message: '提示内容')));
      expect(find.byIcon(icon), findsOneWidget);
      expect(find.text('提示内容'), findsOneWidget);
    }
  });

  testWidgets('notice card shows its title and runs its action',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(CollarNoticeCard(
        tone: CollarNoticeTone.error,
        title: '配网失败',
        message: '请稍后重试',
        action: TextButton(onPressed: () => taps++, child: const Text('重试')))));
    expect(find.text('配网失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(taps, 1);
  });

  testWidgets('device tile only reacts when enabled and fades when dimmed',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(CollarDeviceTile(
        title: '宠物智能项圈', subtitle: '点击设置 WiFi', onTap: () => taps++)));
    await tester.tap(find.text('宠物智能项圈'));
    expect(taps, 1);
    await tester.pumpWidget(_host(const CollarDeviceTile(
        title: '宠物智能项圈', subtitle: '同名项圈', dimmed: true)));
    await tester.tap(find.text('宠物智能项圈'));
    expect(taps, 1);
    final faded = find.descendant(
        of: find.byType(CollarDeviceTile), matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(faded).opacity, .5);
  });

  testWidgets('discovery panel explains a failed search and offers a retry',
      (tester) async {
    var searches = 0;
    await tester.pumpWidget(_host(CollarDiscoveryPanel(
        scanning: false,
        foundCount: 0,
        error: '暂未发现项圈',
        onSearch: () => searches++)));
    expect(find.text('暂未发现项圈'), findsOneWidget);
    expect(find.text('开始寻找项圈'), findsNothing);
    await tester.tap(find.text('重新搜索'));
    expect(searches, 1);
  });

  testWidgets('search stays disabled while a scan is still running',
      (tester) async {
    var searches = 0;
    await tester.pumpWidget(_host(CollarDiscoveryPanel(
        scanning: true, foundCount: 1, onSearch: () => searches++)));
    await tester.tap(find.text('搜索中…'));
    expect(searches, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('pairing guide opens from the help link and closes again',
      (tester) async {
    await tester.pumpWidget(_host(
        CollarDiscoveryPanel(scanning: false, foundCount: 0, onSearch: () {})));
    await tester.tap(find.text('蓝灯没有闪烁？'));
    await tester.pumpAndSettle();
    expect(find.text('让项圈进入配网模式'), findsOneWidget);
    expect(find.textContaining('连续按复位键 3 次'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('让项圈进入配网模式'), findsNothing);
  });

  testWidgets('hero badge pulses only while searching and motion is allowed',
      (tester) async {
    Widget badge({required bool pulse, bool reduce = false}) =>
        _host(CollarHeroBadge(icon: Icons.bluetooth_rounded, pulse: pulse),
            disableAnimations: reduce);
    await tester.pumpWidget(badge(pulse: false));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(badge(pulse: true));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(badge(pulse: true, reduce: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(badge(pulse: true));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(badge(pulse: false));
    expect(tester.hasRunningAnimations, isFalse);
  });

  CollarBindingStatus status(
          {bool bound = false,
          bool waiting = false,
          bool queryFailed = false,
          int seconds = 0,
          String? error}) =>
      CollarBindingStatus(
          bound: bound,
          waiting: waiting,
          saved: true,
          reconfiguring: false,
          seconds: seconds,
          queryFailed: queryFailed,
          error: error);

  Widget scrolling(Widget child) => _host(SingleChildScrollView(child: child));

  testWidgets('binding status icon follows the confirmed state',
      (tester) async {
    await tester.pumpWidget(scrolling(status(bound: true)));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(scrolling(status(waiting: true, seconds: 30)));
    expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        .5);
    expect(find.text('预计最多等待 30 秒'), findsOneWidget);
    await tester.pumpWidget(scrolling(status(error: '等待绑定超时')));
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('failure reason stays folded until it is opened', (tester) async {
    await tester.pumpWidget(scrolling(status(error: '等待绑定超时，请再次查询')));
    expect(find.text('查看原因与处理方法'), findsOneWidget);
    expect(find.text('等待绑定超时，请再次查询'), findsNothing);
    await tester.tap(find.text('查看原因与处理方法'));
    await tester.pumpAndSettle();
    expect(find.text('等待绑定超时，请再次查询'), findsOneWidget);
  });

  testWidgets('sending view reports progress and opens the details',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(_host(SingleChildScrollView(
        child: CollarSendingView(
            progress: '正在写入 WiFi 名称', seconds: 7, onDetails: () => opened++))));
    expect(find.text('正在写入 WiFi 名称'), findsOneWidget);
    expect(find.text('已用时 7 秒'), findsOneWidget);
    await tester.tap(find.text('查看详细进度'));
    expect(opened, 1);
  });

  for (final (access, title) in [
    (CollarBluetoothAccess.denied, '需要蓝牙权限'),
    (CollarBluetoothAccess.bluetoothOff, '请打开手机蓝牙'),
    (CollarBluetoothAccess.locationOff, '请打开定位服务'),
    (CollarBluetoothAccess.unsupported, '当前设备不支持'),
  ]) {
    testWidgets('permission gate explains $access', (tester) async {
      await tester.pumpWidget(_host(CollarBluetoothAccessDialog(
          check: ({bool request = false}) async => access)));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.text('暂不配网'), findsOneWidget);
      expect(
          find.text('重新检测'),
          access == CollarBluetoothAccess.unsupported
              ? findsNothing
              : findsOneWidget);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('permission gate fits 320 wide at scale $scale',
        (tester) async {
      _narrow(tester);
      await tester.pumpWidget(_host(
          CollarBluetoothAccessDialog(
              check: ({bool request = false}) async =>
                  CollarBluetoothAccess.denied),
          scale: scale));
      await tester.pumpAndSettle();
      expect(find.text('打开系统权限设置'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pairing guide fits 320 wide at scale $scale', (tester) async {
      _narrow(tester);
      await tester.pumpWidget(_host(
          ListView(children: [
            CollarDiscoveryPanel(
                scanning: false, foundCount: 0, onSearch: () {})
          ]),
          scale: scale));
      await tester.scrollUntilVisible(find.text('蓝灯没有闪烁？'), 200);
      await tester.tap(find.text('蓝灯没有闪烁？'));
      await tester.pumpAndSettle();
      expect(find.text('知道了'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
