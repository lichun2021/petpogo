import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/api_exception.dart';
import 'package:petpogo_app/core/api/result.dart';
import 'package:petpogo_app/core/push/push_service.dart';
import 'package:petpogo_app/features/auth/controller/auth_controller.dart';
import 'package:petpogo_app/features/auth/data/auth_repository.dart';
import 'package:petpogo_app/features/auth/data/models/auth_model.dart';
import 'package:petpogo_app/features/device/data/models/device_model.dart';
import 'package:petpogo_app/features/device/data/models/device_product_model.dart';
import 'package:petpogo_app/features/device/data/repository/device_repository.dart';
import 'package:petpogo_app/features/message/controller/im_controller.dart';
import 'package:petpogo_app/features/message/data/repository/im_repository.dart';
import 'package:petpogo_app/features/home/data/repository/ai_repository.dart';
import 'package:petpogo_app/features/home/data/models/ai_result_model.dart';

class _PausedAnalysis extends AiRepository {
  _PausedAnalysis(super.client);
  final uploaded = Completer<void>();
  int analyses = 0;
  @override
  Future<OssUploadToken> getUploadToken(
          {required String mimeType, required String folder}) async =>
      const OssUploadToken(
          uploadUrl: 'https://oss.example/upload',
          publicUrl: 'https://oss.example/file');
  @override
  Future<void> uploadToOss(
          {required String uploadUrl,
          required File file,
          void Function(double)? onProgress}) =>
      uploaded.future;
  @override
  Future<AiAnalysisResult> analyzeVoice(
      {required String audioUrl,
      required String account,
      String? petId}) async {
    analyses++;
    throw StateError('Old-account analysis must not start');
  }

  @override
  Future<AiAnalysisResult> analyzeImage(
      {required String imageUrl,
      required String account,
      String? petId}) async {
    analyses++;
    throw StateError('Old-account analysis must not start');
  }
}

class _AuthRepo implements AuthRepository {
  _AuthRepo(this.client);
  final ApiClient client;
  int logouts = 0;
  final profile = Completer<UserInfo?>();
  @override
  Future<UserInfo?> restoreSession() => Completer<UserInfo?>().future;
  @override
  Future<UserInfo?> fetchProfile() => profile.future;
  @override
  Future<void> logout() async {
    logouts++;
    client.clearToken();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _ImRepo implements ImRepository {
  int logouts = 0;
  @override
  Future<Result<void>> logout() async {
    logouts++;
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Im extends ImController {
  _Im(_ImRepo repo, Ref ref) : super(repo, ref) {
    state = ImState(isLoggedIn: true);
  }
}

class _Devices implements DeviceRepository {
  Completer<bool>? online;
  @override
  Future<List<DeviceProductModel>> fetchProducts() async => [];
  @override
  Future<List<DeviceModel>> fetchDevices() async => const [
        DeviceModel(
            deviceId: 'account-A-device', mac: 'AA', name: 'A private device')
      ];
  @override
  Future<bool> fetchOnlineState(String mac) =>
      online?.future ?? Future.value(false);
  @override
  Future<DeviceDetailModel> fetchDeviceDetail(String mac) async =>
      const DeviceDetailModel();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final voice in [true, false]) {
    test(
        '${voice ? 'voice' : 'image'} analysis cannot continue after an account change during upload',
        () async {
      final client = ApiClient(token: 'account-A');
      final repo = _PausedAnalysis(client);
      final pending = voice
          ? repo.uploadAndAnalyzeVoice(
              file: File('unused.wav'), account: 'account-A')
          : repo.uploadAndAnalyzeImage(
              file: File('unused.jpg'), account: 'account-A');
      await Future<void>.delayed(Duration.zero);
      client.clearToken();
      client.setToken('account-B', newSession: true);
      repo.uploaded.complete();
      await expectLater(pending, throwsA(isA<ApiException>()));
      expect(repo.analyses, 0);
    });
  }
  test('push identity cleanup runs after any in-flight identity binding',
      () async {
    final calls = <String>[];
    final oldBinding = Completer<Map<String, dynamic>>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('jpush');
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'setAlias' && calls.length == 1)
        return oldBinding.future;
      return <String, dynamic>{};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final binding = PushService.setAlias('account-A');
    PushService.pendingRoute = '/old-account';
    final cleanup = PushService.clearAlias();
    expect(PushService.pendingRoute, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['setAlias']);
    oldBinding.complete({});
    await Future.wait([binding, cleanup]);
    expect(calls, ['setAlias', 'deleteAlias']);
    await PushService.setAlias('account-B');
    expect(calls, ['setAlias', 'deleteAlias', 'setAlias']);
  });
  for (final expired in [false, true]) {
    test(
        '${expired ? 'expired' : 'normal'} logout clears IM, credentials and account cache',
        () async {
      final client = ApiClient(token: 'account-A-token');
      final authRepo = _AuthRepo(client);
      final imRepo = _ImRepo();
      final devices = _Devices()..online = Completer<bool>();
      final c = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(client),
        deviceRepositoryProvider.overrideWithValue(devices),
        authControllerProvider
            .overrideWith((ref) => AuthController(authRepo, ref)),
        imControllerProvider.overrideWith((ref) => _Im(imRepo, ref)),
      ]);
      addTearDown(c.dispose);
      final loading = c.read(deviceListProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(deviceListProvider).devices, hasLength(1));
      final auth = c.read(authControllerProvider.notifier);
      if (expired) {
        await auth.forceLogout();
      } else {
        await auth.logout();
      }
      expect(c.read(authControllerProvider).isGuest, isTrue);
      expect(client.token, isNull);
      expect(imRepo.logouts, 1);
      expect(authRepo.logouts, 1);
      expect(c.read(imControllerProvider).isLoggedIn, isFalse);
      expect(c.read(deviceListProvider).devices, isEmpty);
      devices.online!.complete(true);
      await loading;
      expect(c.read(deviceListProvider).devices, isEmpty);
    });
  }

  test('a profile response started before logout cannot restore the account',
      () async {
    final client = ApiClient();
    final repo = _AuthRepo(client);
    final c = ProviderContainer(overrides: [
      authControllerProvider.overrideWith((ref) => AuthController(repo, ref)),
      imControllerProvider.overrideWith((ref) => _Im(_ImRepo(), ref)),
    ]);
    addTearDown(c.dispose);
    final auth = c.read(authControllerProvider.notifier);
    final request = auth.refreshUser();
    await auth.logout();
    repo.profile.complete(const UserInfo(
        id: 'old-id',
        token: 'old-token',
        account: 'old',
        name: 'Old',
        merchantId: 1));
    await request;
    expect(c.read(authControllerProvider).isGuest, isTrue);
    expect(c.read(authControllerProvider).user, isNull);
  });
}
