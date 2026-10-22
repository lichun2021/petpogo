import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:petpogo_app/features/pet/services/navigation_map_app.dart';
import 'package:petpogo_app/features/pet/widgets/pet_navigation_sheet.dart';

void main() {
  const gcj = LatLng(22.540123, 113.940456);
  const gps = LatLng(22.543, 113.935);
  Uri uri(NavigationMapApp app, {bool isIOS = false}) => app.navigationUri(
      isIOS: isIOS,
      gcjPosition: gcj,
      gpsPosition: gps,
      destinationName: '毛毛 & Friends 的位置');

  test('Android and iOS lists put AMap first and only iOS offers Apple Maps',
      () {
    expect(NavigationMapApp.forPlatform(isIOS: false), [
      NavigationMapApp.amap,
      NavigationMapApp.tencent,
      NavigationMapApp.baidu,
    ]);
    expect(NavigationMapApp.forPlatform(isIOS: true), [
      NavigationMapApp.amap,
      NavigationMapApp.tencent,
      NavigationMapApp.baidu,
      NavigationMapApp.apple,
    ]);
  });

  test('AMap uses the platform scheme and already-converted coordinates', () {
    final android = uri(NavigationMapApp.amap);
    final ios = uri(NavigationMapApp.amap, isIOS: true);
    expect(android.scheme, 'androidamap');
    expect(ios.scheme, 'iosamap');
    expect(android.host, 'navi');
    expect(android.queryParameters['lat'], '22.540123');
    expect(android.queryParameters['lon'], '113.940456');
    expect(android.queryParameters['dev'], '0');
    expect(android.queryParameters['poiname'], '毛毛 & Friends 的位置');
    expect(android.queryParameters.containsKey('Friends'), isFalse);
    expect(android.toString(), contains('%20'));
    expect(android.toString(), isNot(contains('+')));
  });

  test('Tencent and Baidu use GCJ02 while Apple retains GPS coordinates', () {
    final tencent = uri(NavigationMapApp.tencent);
    expect(tencent.scheme, 'qqmap');
    expect(tencent.path, '/routeplan');
    expect(tencent.queryParameters['tocoord'], '22.540123,113.940456');
    expect(tencent.queryParameters['to'], '毛毛 & Friends 的位置');
    final baidu = uri(NavigationMapApp.baidu);
    expect(baidu.scheme, 'baidumap');
    expect(baidu.queryParameters['destination'], '22.540123,113.940456');
    expect(baidu.queryParameters['coord_type'], 'gcj02');
    final apple = uri(NavigationMapApp.apple, isIOS: true);
    expect(apple.scheme, 'maps');
    expect(apple.queryParameters['daddr'], '22.543000,113.935000');
  });

  Future<void> open(WidgetTester tester,
      {bool isIOS = false,
      double scale = 1,
      required Future<bool> Function(NavigationMapApp) navigate}) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(body: Builder(builder: (context) {
        return TextButton(
            onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .88),
                  builder: (_) => PetNavigationSheet(
                      isIOS: isIOS,
                      destinationName: '毛毛的位置',
                      onNavigate: navigate),
                ),
            child: const Text('打开导航'));
      })),
    ));
    await tester.tap(find.text('打开导航'));
    await tester.pumpAndSettle();
  }

  testWidgets('AMap is recommended and selected by default', (tester) async {
    final calls = <NavigationMapApp>[];
    await open(tester, navigate: (app) async {
      calls.add(app);
      return true;
    });
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('腾讯地图'), findsOneWidget);
    expect(find.text('百度地图'), findsOneWidget);
    expect(find.text('苹果地图'), findsNothing);
    expect(tester.getTopLeft(find.text('高德地图')).dy,
        lessThan(tester.getTopLeft(find.text('腾讯地图')).dy));
    await tester.tap(find.text('开始导航'));
    await tester.pumpAndSettle();
    expect(calls, [NavigationMapApp.amap]);
    expect(find.byType(PetNavigationSheet), findsNothing);
  });

  testWidgets('failed handoff keeps the list open so another map can be chosen',
      (tester) async {
    final calls = <NavigationMapApp>[];
    await open(tester, isIOS: true, navigate: (app) async {
      calls.add(app);
      return app == NavigationMapApp.baidu;
    });
    expect(find.text('苹果地图'), findsOneWidget);
    await tester.tap(find.text('腾讯地图'));
    expect(calls, isEmpty);
    await tester.tap(find.text('开始导航'));
    await tester.pumpAndSettle();
    expect(find.textContaining('未能打开腾讯地图'), findsOneWidget);
    await tester.tap(find.text('百度地图'));
    await tester.pump();
    expect(find.textContaining('未能打开腾讯地图'), findsNothing);
    await tester.tap(find.text('开始导航'));
    await tester.pumpAndSettle();
    expect(calls, [NavigationMapApp.tencent, NavigationMapApp.baidu]);
    expect(find.byType(PetNavigationSheet), findsNothing);
  });

  testWidgets('exceptions during handoff show a recoverable message',
      (tester) async {
    await open(tester,
        navigate: (_) async => throw StateError('not installed'));
    await tester.tap(find.text('开始导航'));
    await tester.pumpAndSettle();
    expect(find.textContaining('未能打开高德地图'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending handoff ignores duplicate taps and selection changes',
      (tester) async {
    var calls = 0;
    final pending = Completer<bool>();
    await open(tester, navigate: (_) {
      calls++;
      return pending.future;
    });
    await tester.tap(find.text('开始导航'));
    await tester.pump();
    await tester.tap(find.text('正在打开…'));
    await tester.tap(find.text('腾讯地图'));
    expect(calls, 1);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('未能打开高德地图'), findsOneWidget);
  });

  testWidgets('closing and reopening restores AMap as the default',
      (tester) async {
    NavigationMapApp? chosen;
    await open(tester, navigate: (app) async {
      chosen = app;
      return true;
    });
    await tester.tap(find.text('百度地图'));
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(chosen, isNull);
    await tester.tap(find.text('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始导航'));
    await tester.pumpAndSettle();
    expect(chosen, NavigationMapApp.amap);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('iOS list scrolls on a 320 wide screen at text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester,
          isIOS: true, scale: scale, navigate: (_) async => false);
      await tester.scrollUntilVisible(find.text('开始导航'), 100,
          scrollable: find
              .descendant(
                  of: find.byType(PetNavigationSheet),
                  matching: find.byType(Scrollable))
              .first);
      await tester.tap(find.text('开始导航'));
      await tester.pumpAndSettle();
      expect(find.textContaining('未能打开高德地图'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
