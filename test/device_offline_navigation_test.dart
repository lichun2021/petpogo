import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/peer_api_client.dart';
import 'package:petpogo_app/core/router/app_router.dart';
import 'package:petpogo_app/core/router/app_routes.dart';
import 'package:petpogo_app/features/auth/controller/auth_controller.dart';
import 'package:petpogo_app/features/auth/data/auth_repository.dart';
import 'package:petpogo_app/features/auth/data/models/auth_model.dart';
import 'package:petpogo_app/features/device/controller/device_entry_guard.dart';
import 'package:petpogo_app/features/device/data/models/device_model.dart';
import 'package:petpogo_app/features/device/data/models/device_product_model.dart';
import 'package:petpogo_app/features/device/data/models/media_model.dart';
import 'package:petpogo_app/features/device/data/repository/device_repository.dart';
import 'package:petpogo_app/features/device/data/repository/media_repository.dart';
import 'package:petpogo_app/features/device/data/wifi_setup_capability.dart';
import 'package:petpogo_app/features/device/device_detail_page.dart';
import 'package:petpogo_app/features/device/device_list_page.dart';
import 'package:petpogo_app/features/device/robot_device_page.dart';
import 'package:petpogo_app/features/device/stream/device_stream_api.dart';
import 'package:petpogo_app/features/home/controller/ai_controller.dart';
import 'package:petpogo_app/features/home/home_page.dart';
import 'package:petpogo_app/features/home/widgets/pet_mood_section.dart';
import 'package:petpogo_app/features/pet/data/models/pet_peer_models.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_peer_repository.dart';
import 'package:petpogo_app/features/pet_circle/controller/pet_circle_pet_controller.dart';
import 'package:petpogo_app/features/profile/data/account_overview_provider.dart';
import 'package:petpogo_app/l10n/app_localizations.dart';

const _collar = DeviceModel(
    deviceId: 'collar',
    mac: 'collar-mac',
    name: '测试项圈',
    productAlias: 'COLLAR');
const _robot = DeviceModel(
    deviceId: 'robot', mac: 'robot-mac', name: '测试机器人', productAlias: 'ROBOT');

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

class _AuthRepo implements AuthRepository {
  @override
  Future<UserInfo?> restoreSession() => Completer<UserInfo?>().future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends AuthController {
  _Auth(super.repo, super.ref, bool loggedIn) {
    state = loggedIn
        ? const AuthState(
            status: AuthStatus.loggedIn,
            user: UserInfo(
              id: 'test-user',
              token: 'test-session',
              account: 'test-account',
              name: 'Test',
              merchantId: 1,
            ))
        : const AuthState.guest();
  }
}

class _Devices implements DeviceRepository {
  _Devices(this.items);
  final List<DeviceModel> items;
  int details = 0;
  @override
  Future<List<DeviceProductModel>> fetchProducts() async => [];
  @override
  Future<List<DeviceModel>> fetchDevices() async => items;
  @override
  Future<bool> fetchOnlineState(String mac) async =>
      items.firstWhere((d) => d.mac == mac).isOnline;
  @override
  Future<DeviceDetailModel> fetchDeviceDetail(String mac) async {
    details++;
    final device = items.firstWhere((d) => d.mac == mac);
    return DeviceDetailModel(
        name: device.displayName, mac: mac, onlineStatus: device.isOnline);
  }

  @override
  Future<OtaInfoModel> fetchOtaInfo(String mac) async => const OtaInfoModel();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeviceList extends DeviceListNotifier {
  _DeviceList(_Devices repo) : super(repo) {
    state = DeviceListState(devices: repo.items);
  }
}

class _Pets implements PetPeerRepository {
  @override
  Future<PetInfoModel> fetchPetInfo({String? mac, String? deviceId}) async =>
      const PetInfoModel(
          petId: 'test-pet', petName: '已绑定的宠物', deviceId: 'collar');
  @override
  Future<PetBattery> fetchBattery({required String mac}) async =>
      const PetBattery(battery: 57, known: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Circle extends PetCirclePetController {
  _Circle(super.ref, List<DeviceModel> devices) {
    state = PetCirclePetState(
        hasLoaded: true,
        pets: devices
            .map((d) => PetCirclePet(
                  pet: PetInfoModel(
                      petId: d.deviceId, petName: '宠物-${d.deviceId}'),
                  device: d,
                ))
            .toList());
  }
  @override
  Future<void> loadIfNeeded() async {}
}

class _Media implements MediaRepository {
  @override
  Future<MediaListResult> fetchList(
          {String? deviceId,
          int? type,
          int page = 1,
          int pageSize = 20}) async =>
      MediaListResult(total: 0, page: page, pageSize: pageSize, list: const []);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Adapter implements HttpClientAdapter {
  int starts = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancelFuture) async {
    if (options.path.endsWith('/pet/stream/start')) starts++;
    return ResponseBody.fromString(
        jsonEncode({'code': 4, 'info': null, 'tip': '测试媒体不可用'}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

Future<(_Devices, _Adapter)> _mount(WidgetTester tester, Widget page,
    List<DeviceModel> devices, _Observer observer,
    {bool loggedIn = false}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = _Devices(devices);
  final adapter = _Adapter();
  final client = ApiClient(adapter: adapter);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        deviceRepositoryProvider.overrideWithValue(repository),
        deviceListProvider.overrideWith((ref) => _DeviceList(repository)),
        wifiCollarMacsProvider.overrideWith(
            (ref) async => devices.map((d) => d.mac.toUpperCase()).toSet()),
        petPeerRepositoryProvider.overrideWithValue(_Pets()),
        petCirclePetControllerProvider
            .overrideWith((ref) => _Circle(ref, devices)),
        authControllerProvider
            .overrideWith((ref) => _Auth(_AuthRepo(), ref, loggedIn)),
        pointsBalanceProvider.overrideWith((ref) async => {}),
        checkInStatusProvider.overrideWith((ref) async => {}),
        aiPointsProvider.overrideWith((ref) async => {}),
        mediaRepositoryProvider.overrideWithValue(_Media()),
        deviceStreamApiProvider
            .overrideWithValue(DeviceStreamApi(PeerApiClient(client))),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        supportedLocales: const [Locale('zh')],
        navigatorObservers: [observer],
        home: page,
      )));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  observer.pushes = 0;
  return (repository, adapter);
}

Future<void> _dismiss(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 4));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  for (final device in [_collar, _robot]) {
    testWidgets(
        'offline ${device.productAlias} list card never opens a device page',
        (tester) async {
      final observer = _Observer();
      final (repo, adapter) =
          await _mount(tester, const DeviceListPage(), [device], observer);
      await tester.tap(find.text(device.displayName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(observer.pushes, 0);
      expect(repo.details, 0);
      expect(adapter.starts, 0);
      expect(find.byType(DeviceDetailPage), findsNothing);
      expect(find.byType(RobotDevicePage), findsNothing);
      expect(find.text(DeviceEntryGuard.offlineMessage), findsOneWidget);
      expect(find.text('解绑设备'), findsOneWidget);
      await _dismiss(tester);
    });

    testWidgets('offline ${device.productAlias} home hardware card never opens',
        (tester) async {
      final observer = _Observer();
      final (repo, adapter) =
          await _mount(tester, const HomePage(), [device], observer);
      await tester.scrollUntilVisible(find.text(device.displayName), 500,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(device.displayName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(observer.pushes, 0);
      expect(repo.details, 0);
      expect(adapter.starts, 0);
      expect(find.text(DeviceEntryGuard.offlineMessage), findsOneWidget);
      await _dismiss(tester);
    });

    testWidgets(
        'offline ${device.productAlias} pet avatar never opens hardware',
        (tester) async {
      final observer = _Observer();
      await _mount(
          tester, const Scaffold(body: PetMoodSection()), [device], observer,
          loggedIn: true);
      await tester.tap(find.text('宠物-${device.deviceId}'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(observer.pushes, 0);
      expect(find.text(DeviceEntryGuard.offlineMessage), findsOneWidget);
      await _dismiss(tester);
    });

    testWidgets('online ${device.productAlias} can still open normally',
        (tester) async {
      final online = device.copyWith(connect: true);
      final observer = _Observer();
      await _mount(tester, const DeviceListPage(), [online], observer);
      await tester.tap(find.text(online.displayName));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(observer.pushes, 1);
      expect(find.byType(device.isRobot ? RobotDevicePage : DeviceDetailPage),
          findsOneWidget);
      expect(find.text(DeviceEntryGuard.offlineMessage), findsNothing);
      await _dismiss(tester);
    });

    testWidgets(
        'online ${device.productAlias} pet avatar opens the correct hardware type',
        (tester) async {
      final online = device.copyWith(connect: true);
      final observer = _Observer();
      await _mount(
          tester, const Scaffold(body: PetMoodSection()), [online], observer,
          loggedIn: true);
      await tester.tap(find.text('宠物-${online.deviceId}'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(observer.pushes, 1);
      expect(find.byType(device.isRobot ? RobotDevicePage : DeviceDetailPage),
          findsOneWidget);
      await _dismiss(tester);
    });

    testWidgets(
        'notification route does not create an offline ${device.productAlias} detail page',
        (tester) async {
      final observer = _Observer();
      final page = Builder(builder: (context) {
        initAppRouter(ProviderScope.containerOf(context));
        final route = appRouter.configuration.routes
            .whereType<GoRoute>()
            .singleWhere((r) => r.path == AppRoutes.deviceDetailTemplate);
        final state = GoRouterState(
          appRouter.configuration,
          uri: Uri(path: AppRoutes.deviceDetail(device.mac)),
          matchedLocation: AppRoutes.deviceDetail(device.mac),
          fullPath: AppRoutes.deviceDetailTemplate,
          pathParameters: {'mac': device.mac},
          pageKey: ValueKey(device.mac),
        );
        return (route.pageBuilder!(context, state) as CustomTransitionPage)
            .child;
      });
      final (repo, adapter) =
          await _mount(tester, page, [device], observer, loggedIn: true);
      expect(find.byType(DeviceListPage), findsOneWidget);
      expect(find.byType(DeviceDetailPage), findsNothing);
      expect(find.byType(RobotDevicePage), findsNothing);
      expect(repo.details, 0);
      expect(adapter.starts, 0);
      await _dismiss(tester);
    });
  }

  testWidgets('offline bound pet row cannot bypass its device card gate',
      (tester) async {
    final observer = _Observer();
    await _mount(tester, const DeviceListPage(), [_collar], observer);
    await tester.tap(find.text('已绑定的宠物'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(observer.pushes, 0);
    expect(find.text(DeviceEntryGuard.offlineMessage), findsOneWidget);
    await _dismiss(tester);
  });

  for (final robot in [false, true]) {
    testWidgets(
        '${robot ? 'robot' : 'collar'} switcher keeps offline targets closed',
        (tester) async {
      final current =
          (robot ? _robot : _collar).copyWith(connect: true, name: '当前设备');
      final target = robot ? _collar : _robot;
      final observer = _Observer();
      await _mount(
          tester,
          robot
              ? RobotDevicePage(mac: current.mac, name: current.displayName)
              : DeviceDetailPage(mac: current.mac, name: current.displayName),
          [current, target],
          observer);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      observer.pushes = 0;
      await tester.tap(find.text(target.displayName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(observer.pushes, 0);
      expect(find.text('切换设备'), findsOneWidget);
      expect(find.text(DeviceEntryGuard.offlineMessage), findsOneWidget);
      expect(find.byType(robot ? RobotDevicePage : DeviceDetailPage),
          findsOneWidget);
      expect(find.byType(robot ? DeviceDetailPage : RobotDevicePage),
          findsNothing);
      await _dismiss(tester);
    });
  }
}
