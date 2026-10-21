import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:petpogo_app/features/bind_device/services/current_wifi.dart';
import 'package:petpogo_app/features/bind_device/widgets/current_wifi_name_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  const network = MethodChannel('dev.fluttercommunity.plus/network_info');
  late int permission, requestedPermission, requests, settings, reads;
  late bool locationEnabled;
  late FutureOr<String?> Function() name;

  setUp(() {
    permission = PermissionStatus.granted.index;
    requestedPermission = PermissionStatus.granted.index;
    requests = settings = reads = 0;
    locationEnabled = true;
    name = () => '"Home 2.4G"';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissions, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          expectSync(call.arguments, Permission.locationWhenInUse.value);
          return permission;
        case 'requestPermissions':
          expectSync(call.arguments, [Permission.locationWhenInUse.value]);
          requests++;
          permission = requestedPermission;
          return {Permission.locationWhenInUse.value: permission};
        case 'checkServiceStatus':
          return locationEnabled ? 1 : 0;
        case 'openAppSettings':
          settings++;
          return true;
        default:
          throw StateError('Unexpected permission method ${call.method}');
      }
    });
    messenger.setMockMethodCallHandler(network, (call) async {
      expectSync(call.method, 'wifiName');
      reads++;
      return name();
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissions, null);
    messenger.setMockMethodCallHandler(network, null);
  });

  Future<TextEditingController> mount(WidgetTester tester,
      {bool settle = true, double scale = 1}) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
          body: ListView(padding: const EdgeInsets.all(20), children: [
        CurrentWifiNameField(
          controller: controller,
          decoration: const InputDecoration(
              labelText: 'WiFi 名称',
              hintText: '输入 WiFi 名称',
              prefixIcon: Icon(Icons.wifi_rounded)),
        ),
      ])),
    )));
    if (settle) await tester.pumpAndSettle();
    return controller;
  }

  Future<void> resume(WidgetTester tester) async {
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
      'tapping an empty input retries a denied permission and fills SSID',
      (tester) async {
    permission = requestedPermission = PermissionStatus.denied.index;
    final controller = await mount(tester);
    expect(requests, 1);
    expect(reads, 0);
    expect(find.textContaining('允许位置权限后可自动获取'), findsOneWidget);
    requestedPermission = PermissionStatus.granted.index;
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(controller.text, 'Home 2.4G');
    expect(find.textContaining('允许位置权限后可自动获取'), findsNothing);
  });

  testWidgets('automatic-get action can retry without leaving the form',
      (tester) async {
    permission = requestedPermission = PermissionStatus.denied.index;
    final controller = await mount(tester);
    requestedPermission = PermissionStatus.granted.index;
    await tester.tap(find.text('自动获取'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(controller.text, 'Home 2.4G');
  });

  testWidgets(
      'blocked permission opens settings and resumes without another prompt',
      (tester) async {
    permission = PermissionStatus.permanentlyDenied.index;
    final controller = await mount(tester);
    expect(requests, 0);
    expect(find.text('去设置'), findsOneWidget);
    await tester.tap(find.text('去设置'));
    await tester.pumpAndSettle();
    expect(settings, 1);
    permission = PermissionStatus.granted.index;
    await resume(tester);
    expect(controller.text, 'Home 2.4G');
    expect(requests, 0);
  });

  testWidgets('resuming with permission still denied does not prompt again',
      (tester) async {
    permission = requestedPermission = PermissionStatus.denied.index;
    await mount(tester);
    expect(requests, 1);
    requestedPermission = PermissionStatus.granted.index;
    await resume(tester);
    expect(requests, 1);
    expect(reads, 0);
  });

  testWidgets('disabled location is explained and recovers after enabling it',
      (tester) async {
    locationEnabled = false;
    final controller = await mount(tester);
    expect(find.textContaining('请先打开手机的定位服务'), findsOneWidget);
    expect(reads, 0);
    locationEnabled = true;
    await resume(tester);
    expect(controller.text, 'Home 2.4G');
    expect(requests, 0);
  });

  testWidgets('a pending lookup never overwrites a name typed meanwhile',
      (tester) async {
    final pending = Completer<String?>();
    name = () => pending.future;
    final controller = await mount(tester, settle: false);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'My other WiFi');
    pending.complete('"Detected WiFi"');
    await tester.pumpAndSettle();
    expect(controller.text, 'My other WiFi');
    expect(reads, 1);
  });

  testWidgets(
      'editing then clearing a name also invalidates the pending lookup',
      (tester) async {
    final pending = Completer<String?>();
    name = () => pending.future;
    final controller = await mount(tester, settle: false);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Other');
    await tester.enterText(find.byType(TextFormField), '');
    pending.complete('"Detected WiFi"');
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
  });

  testWidgets('settings recovery preserves a manually entered name',
      (tester) async {
    permission = PermissionStatus.permanentlyDenied.index;
    final controller = await mount(tester);
    await tester.enterText(find.byType(TextFormField), 'Manual WiFi');
    permission = PermissionStatus.granted.index;
    await resume(tester);
    expect(controller.text, 'Manual WiFi');
    expect(reads, 0);
  });

  testWidgets('a lookup completing after leaving the form is ignored',
      (tester) async {
    final pending = Completer<String?>();
    name = () => pending.future;
    await mount(tester, settle: false);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete('"Home"');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('SSID normalization preserves spaces and internal quotes', () async {
    name = () => '" Home "Pet" "';
    expect((await const CurrentWifiReader().read()).name, ' Home "Pet" ');
    expect(requests, 0);
  });

  test('empty and unknown SSIDs remain available for manual input', () async {
    for (final raw in [null, '', '""', '<unknown ssid>', '"<unknown ssid>"']) {
      name = () => raw;
      final result = await const CurrentWifiReader().read();
      expect(result.name, isNull);
      expect(result.issue, CurrentWifiIssue.unavailable);
    }
  });

  testWidgets('lookup errors keep manual input usable', (tester) async {
    name = () => throw PlatformException(code: 'read_failed');
    final controller = await mount(tester);
    expect(find.textContaining('暂时无法获取名称'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Manual WiFi');
    expect(controller.text, 'Manual WiFi');
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('permission recovery fits a narrow screen at scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      permission = PermissionStatus.permanentlyDenied.index;
      await mount(tester, scale: scale);
      expect(find.text('去设置'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
