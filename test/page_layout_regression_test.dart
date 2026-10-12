import 'package:petpogo_app/features/device/device_detail_page.dart';
import 'package:petpogo_app/features/device/device_list_page.dart';
import 'package:petpogo_app/features/device/data/models/device_model.dart';
import 'package:petpogo_app/features/device/data/wifi_setup_capability.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/features/auth/data/auth_repository.dart';
import 'package:petpogo_app/features/auth/data/models/auth_model.dart';
import 'package:petpogo_app/features/profile/profile_edit_dialog.dart';
import 'package:petpogo_app/features/device/widgets/date_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/result.dart';
import 'package:petpogo_app/features/device/data/repository/device_repository.dart';
import 'package:petpogo_app/features/music/data/music_models.dart';
import 'package:petpogo_app/features/music/data/music_repository.dart';
import 'package:petpogo_app/features/music/pet_music_page.dart';
import 'package:petpogo_app/features/pet/data/models/pet_peer_models.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_peer_repository.dart';
import 'package:petpogo_app/features/pet/pet_list_page.dart';
import 'package:petpogo_app/features/pet_circle/data/models/pet_circle_post.dart';

class _Music implements MusicRepository {
  @override
  Future<Result<List<MusicCategory>>> fetchCatalogResult() async =>
      const Success([MusicCategory(name: '放松助眠', songs: [])]);
  @override
  Future<Result<List<Playlist>>> fetchPlaylistsResult() async => const Success([
        Playlist(id: 1, name: '这是一张名字很长很长的晚安陪伴歌单', songCount: 3),
      ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pets implements PetPeerRepository {
  @override
  Future<List<PetInfoModel>> fetchPetList() async => const [
        PetInfoModel(
            petId: '1',
            petName: '名字很长很长的布偶猫',
            breed: '布偶猫',
            sex: 'GG_sterilization'),
      ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Devices implements DeviceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _longMac = 'ipet-esp32-Dev-030012345678901234567890';
const _longName = '这是一个很长很长的项圈名称用于测试小屏幕';

class _LayoutDeviceRepository extends _Devices {
  @override
  Future<DeviceDetailModel> fetchDeviceDetail(String mac) async =>
      const DeviceDetailModel(name: _longName, mac: _longMac);
  @override
  Future<OtaInfoModel> fetchOtaInfo(String mac) async => const OtaInfoModel();
  @override
  Future<bool> fetchOnlineState(String mac) async => false;
}

class _LayoutPetRepository extends _Pets {
  @override
  Future<PetInfoModel> fetchPetInfo({String? mac, String? deviceId}) async =>
      const PetInfoModel();
}

class _LayoutDeviceList extends DeviceListNotifier {
  _LayoutDeviceList() : super(_LayoutDeviceRepository()) {
    state = const DeviceListState(devices: [
      DeviceModel(
          deviceId: '1', mac: _longMac, name: _longName, productAlias: 'COLLAR')
    ]);
  }
}

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('device cards and switcher fit long IDs at $width / $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget app(Widget page) => ProviderScope(
                overrides: [
                  deviceRepositoryProvider
                      .overrideWithValue(_LayoutDeviceRepository()),
                  petPeerRepositoryProvider
                      .overrideWithValue(_LayoutPetRepository()),
                  deviceListProvider.overrideWith((_) => _LayoutDeviceList()),
                  wifiCollarMacsProvider
                      .overrideWith((_) async => {_longMac.toUpperCase()}),
                ],
                child: MaterialApp(
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: TextScaler.linear(scale)),
                        child: child!),
                    home: page));
        await tester.pumpWidget(
            app(const DeviceDetailPage(mac: _longMac, name: _longName)));
        await tester.pumpAndSettle();
        expect(find.text('设备码 $_longMac'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(app(const DeviceListPage()));
        await tester.pumpAndSettle();
        expect(find.text('设备码 $_longMac'), findsOneWidget);
        expect(find.text('重新配网'), findsOneWidget);
        expect(find.text('解绑设备'), findsOneWidget);
        expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
        final actionY = tester.getCenter(find.text('重新配网')).dy;
        expect(tester.getCenter(find.text('管理共享')).dy, closeTo(actionY, 1));
        expect(tester.getCenter(find.text('解绑设备')).dy, closeTo(actionY, 1));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('解绑设备'));
        await tester.tap(find.text('解绑设备'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('重新配网'));
        await tester.tap(find.text('重新配网'));
        await tester.pumpAndSettle();
        expect(find.text('更换项圈 WiFi'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('Profile fields survive storage and can be cleared by server', () {
    const user = UserInfo(
        token: 'test',
        account: 'test',
        name: '小雨',
        merchantId: 1,
        id: '1',
        gender: 2,
        birthday: '1995-06-18',
        email: 'user@example.com',
        peerGatewayUrl: '/gateway');
    final restored = UserInfo.fromStorageMap(user.toStorageMap());
    expect(restored.gender, 2);
    expect(restored.birthday, '1995-06-18');
    expect(restored.email, 'user@example.com');
    final cleared =
        UserInfo.fromProfileJson(restored, {'birthday': null, 'email': null});
    expect(cleared.birthday, '');
    expect(cleared.email, '');
    expect(cleared.peerGatewayUrl, '/gateway');
    expect(cleared.copyWith(name: '新名字').gender, 2);
  });
  for (final width in [320.0, 390.0]) {
    testWidgets(
        'Profile dialog fits keyboard at $width with large text and keeps confirmation visible',
        (tester) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
          _profileApp(_ProfileClient(), _ProfileRepo(), scale: 1.5));
      await tester.tap(find.text('编辑资料'));
      await tester.pumpAndSettle();
      expect(find.text('个人资料'), findsOneWidget);
      expect(find.byTooltip('保存'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final check = tester.getRect(find.byTooltip('保存'));
      expect(check.bottom, lessThan(440));
      expect(check.width, greaterThanOrEqualTo(44));
      await tester.ensureVisible(find.byKey(const ValueKey('profile-email')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('个人资料'), findsNothing);
    });
  }
  testWidgets(
      'Profile labels align and birthday picker does not expand the form',
      (tester) async {
    await tester.pumpWidget(_profileApp(_ProfileClient(), _ProfileRepo()));
    await tester.tap(find.text('编辑资料'));
    await tester.pumpAndSettle();
    final nameLeft = tester.getTopLeft(find.text('昵称')).dx;
    expect(tester.getTopLeft(find.text('生日')).dx, nameLeft);
    expect(tester.getTopLeft(find.text('邮箱')).dx, nameLeft);
    final form = find.byType(ProfileEditDialog);
    final before = tester.getRect(form);
    final field = find.byKey(const ValueKey('profile-birthday'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(tester.getRect(form), before);
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2001, 2, 3));
    await tester.tap(find.byTooltip('关闭').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(field).controller!.text, '1995-06-18');
    await tester.tap(field);
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2001, 2, 3));
    await tester.tap(find.byTooltip('确定生日'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(field).controller!.text, '2001-02-03');
    expect(tester.getRect(form), before);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Profile validates email and preserves input after failed save',
      (tester) async {
    final repo = _ProfileRepo()..fail = true;
    await tester.pumpWidget(_profileApp(_ProfileClient(), repo));
    await tester.tap(find.text('编辑资料'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('profile-email')), 'broken');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入有效邮箱'), findsOneWidget);
    expect(repo.saved, isNull);
    await tester.enterText(
        find.byKey(const ValueKey('profile-email')), 'new@example.com');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(find.text('new@example.com'), findsOneWidget);
    expect(find.text('个人资料'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(repo.saved, {
      'nickname': '小雨',
      'gender': 2,
      'birthday': '1995-06-18',
      'email': 'new@example.com'
    });
    expect(find.text('个人资料'), findsNothing);
  });
  testWidgets('Older server leaves email disabled; cancel never saves',
      (tester) async {
    final repo = _ProfileRepo();
    await tester
        .pumpWidget(_profileApp(_ProfileClient(emailSupported: false), repo));
    await tester.tap(find.text('编辑资料'));
    await tester.pumpAndSettle();
    final email = tester
        .widget<TextFormField>(find.byKey(const ValueKey('profile-email')));
    expect(email.enabled, isFalse);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(repo.saved, isNull);
  });
  testWidgets('No recorded dates shows empty calendar without crashing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showRecordDatePickerSheet(
                        context: context,
                        availableDates: [],
                        initialDate: null),
                    child: const Text('日历'))))));
    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(find.text('暂无可选日期'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('Music and pet cards fit width $width, scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget app(Widget page) => ProviderScope(
                overrides: [
                  musicRepositoryProvider.overrideWithValue(_Music()),
                  petPeerRepositoryProvider.overrideWithValue(_Pets()),
                  deviceListProvider
                      .overrideWith((_) => DeviceListNotifier(_Devices())),
                ],
                child: MaterialApp(
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: TextScaler.linear(scale)),
                        child: child!),
                    home: page));
        await tester.pumpWidget(app(const PetMusicPage()));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('3 首'), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(find.text('3 首'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(app(const PetListPage()));
        await tester.pumpAndSettle();
        expect(find.text('布偶猫 · 公(绝育)'), findsOneWidget);
        expect(find.text('♂ 公'), findsNothing);
        for (final label in ['成员管理', '编辑资料', '删除宠物']) {
          final button = find.byTooltip(label);
          expect(button, findsOneWidget);
          expect(tester.getSize(button).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('Image cover fallback and video without cover remain distinct', () {
    final image = PetCirclePost.fromJson(
        {'mediaType': 'image', 'coverUrl': 'https://example.test/pet.jpg'});
    expect(image.imageUrls, ['https://example.test/pet.jpg']);
    final video = PetCirclePost.fromJson({
      'mediaType': 'video',
      'mediaUrls': ['https://example.test/pet.mp4']
    });
    expect(video.imageUrls, isEmpty);
    expect(video.displayMediaUrl, isEmpty);
  });
}

class _ProfileClient implements ApiClient {
  @override
  Future<String?> Function()? onRefreshToken;
  @override
  VoidCallback? onUnauthorized;
  _ProfileClient({this.emailSupported = true});
  final bool emailSupported;
  @override
  Future<T> get<T>(String path,
          {Map<String, dynamic>? params,
          T Function(dynamic)? fromJson}) async =>
      {
        'nickname': '小雨',
        'gender': 2,
        'birthday': '1995-06-18',
        if (emailSupported) 'email': null
      } as T;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileRepo implements AuthRepository {
  bool fail = false;
  Map<String, dynamic>? saved;
  @override
  Future<UserInfo?> restoreSession() async => null;
  @override
  Future<void> updateProfile(
      {required String nickname,
      required int gender,
      required String birthday,
      String? email}) async {
    if (fail) throw Exception('保存失败');
    saved = {
      'nickname': nickname,
      'gender': gender,
      'birthday': birthday,
      'email': email
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _profileApp(_ProfileClient client, _ProfileRepo repo,
        {double scale = 1}) =>
    ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authRepositoryProvider.overrideWithValue(repo)
        ],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => showDialog<bool>(
                            context: context,
                            builder: (_) => const ProfileEditDialog()),
                        child: const Text('编辑资料'))))));
