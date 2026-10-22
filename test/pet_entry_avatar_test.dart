import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// Override image_picker's native platform hook without invoking a phone picker.
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/api_exception.dart';
import 'package:petpogo_app/core/router/app_routes.dart';
import 'package:petpogo_app/features/auth/controller/auth_controller.dart';
import 'package:petpogo_app/features/auth/data/auth_repository.dart';
import 'package:petpogo_app/features/auth/data/models/auth_model.dart';
import 'package:petpogo_app/features/device/data/models/device_model.dart';
import 'package:petpogo_app/features/device/data/models/device_product_model.dart';
import 'package:petpogo_app/features/device/data/repository/device_repository.dart';
import 'package:petpogo_app/features/device/data/wifi_setup_capability.dart';
import 'package:petpogo_app/features/device/device_list_page.dart';
import 'package:petpogo_app/features/home/widgets/pet_mood_section.dart';
import 'package:petpogo_app/features/pet/data/models/pet_peer_models.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_peer_repository.dart';
import 'package:petpogo_app/features/pet/pet_edit_sheet.dart';
import 'package:petpogo_app/features/pet_circle/controller/pet_circle_pet_controller.dart';
import 'package:petpogo_app/shared/utils/oss_uploader.dart';

class _AuthRepo implements AuthRepository {
  @override
  Future<UserInfo?> restoreSession() => Completer<UserInfo?>().future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedIn extends AuthController {
  _SignedIn(super.repo, super.ref) {
    state = const AuthState(
        status: AuthStatus.loggedIn,
        user: UserInfo(
          id: 'test-user',
          token: 'test-token',
          account: 'test-account',
          name: 'Test',
          merchantId: 1,
        ));
  }
}

class _EmptyPets extends PetCirclePetController {
  _EmptyPets(super.ref);
  @override
  Future<void> loadIfNeeded() async {}
}

class _Devices implements DeviceRepository {
  List<DeviceModel> devices = [];
  int fetches = 0;
  bool fail = false;
  @override
  Future<List<DeviceProductModel>> fetchProducts() async => [];
  @override
  Future<List<DeviceModel>> fetchDevices() async {
    fetches++;
    if (fail) throw const ApiException(message: '设备列表暂时不可用');
    return devices;
  }

  @override
  Future<bool> fetchOnlineState(String mac) async => false;
  @override
  Future<DeviceDetailModel> fetchDeviceDetail(String mac) async =>
      const DeviceDetailModel();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pets implements PetPeerRepository {
  final avatars = <String?>[];
  @override
  Future<PetInfoModel> fetchPetInfo({String? mac, String? deviceId}) async =>
      const PetInfoModel();
  @override
  Future<void> updatePet(
      {required String petId,
      String? petName,
      String? breed,
      int? age,
      String? weight,
      String? sex,
      String? avatar}) async {
    avatars.add(avatar);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Picker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource(
          {required ImageSource source,
          ImagePickerOptions options = const ImagePickerOptions()}) async =>
      XFile('/tmp/petpogo-avatar.jpg');
}

class _Upload extends OssUploader {
  _Upload() : super(ApiClient());
  int uploads = 0;
  final pending = Completer<void>();
  @override
  Future<OssSignResult> getSign(
          {required String folder,
          required String mimeType,
          String? fileType}) async =>
      const OssSignResult(
          uploadUrl:
              'https://example-bucket.oss-cn-hangzhou.aliyuncs.com/avatar.jpg',
          key: 'avatar.jpg',
          cdnUrl: 'https://cdn.example/avatar.jpg');
  @override
  Future<void> uploadFile(
      {required String uploadUrl,
      required File file,
      void Function(double)? onProgress}) {
    uploads++;
    return pending.future;
  }
}

void main() {
  for (final hasDevice in [false, true]) {
    testWidgets(
        'home add uses ${hasDevice ? 'existing devices' : 'device binding'} when there is no pet',
        (tester) async {
      final devices = _Devices()
        ..devices = hasDevice
            ? [
                const DeviceModel(
                    deviceId: 'test-device', mac: 'test-mac', name: '项圈')
              ]
            : [];
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: PetMoodSection())),
        GoRoute(
            path: AppRoutes.bindDevice,
            builder: (_, __) => const Scaffold(body: Text('设备绑定入口'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        deviceRepositoryProvider.overrideWithValue(devices),
        petPeerRepositoryProvider.overrideWithValue(_Pets()),
        wifiCollarMacsProvider.overrideWith((ref) async => {}),
        authControllerProvider
            .overrideWith((ref) => _SignedIn(_AuthRepo(), ref)),
        petCirclePetControllerProvider.overrideWith((ref) => _EmptyPets(ref)),
      ], child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(devices.fetches, 1);
      expect(find.byType(DeviceListPage),
          hasDevice ? findsOneWidget : findsNothing);
      expect(find.text('设备绑定入口'), hasDevice ? findsNothing : findsOneWidget);
    });
  }

  for (final success in [true, false]) {
    testWidgets(
        'pet avatar ${success ? 'submits CDN URL after PUT' : 'keeps prior value after upload failure'}',
        (tester) async {
      final original = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = _Picker();
      addTearDown(() => ImagePickerPlatform.instance = original);
      final upload = _Upload();
      final pets = _Pets();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            ossUploaderProvider.overrideWithValue(upload),
            petPeerRepositoryProvider.overrideWithValue(pets),
          ],
          child: MaterialApp(
              home: Scaffold(
                  body: Builder(
                      builder: (context) => TextButton(
                            onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => const PetEditSheet(
                                    pet: PetInfoModel(
                                        petId: 'test-pet', petName: '毛毛'))),
                            child: const Text('打开编辑'),
                          ))))));
      await tester.tap(find.text('打开编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从相册选择'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(upload.uploads, 1);
      expect(pets.avatars, isEmpty);
      expect(find.byTooltip('保存'), findsNothing); // upload still pending
      if (success) {
        upload.pending.complete();
      } else {
        upload.pending.completeError(const ApiException(message: '头像上传失败，请重试'));
      }
      await tester.pumpAndSettle();
      if (!success) expect(find.text('头像上传失败，请重试'), findsOneWidget);
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();
      expect(pets.avatars, [success ? 'https://cdn.example/avatar.jpg' : null]);
    });
  }
}
