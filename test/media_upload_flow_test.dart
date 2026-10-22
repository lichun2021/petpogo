import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/api_exception.dart';
import 'package:petpogo_app/features/auth/controller/auth_controller.dart';
import 'package:petpogo_app/features/auth/data/auth_repository.dart';
import 'package:petpogo_app/features/auth/data/models/auth_model.dart';
import 'package:petpogo_app/features/home/controller/ai_controller.dart';
import 'package:petpogo_app/features/home/data/repository/ai_repository.dart';
import 'package:petpogo_app/shared/utils/oss_uploader.dart';

const _uploadUrl = 'http://example-bucket.oss-cn-hangzhou.aliyuncs.com/'
    'avatar/a%20b.jpg?OSSAccessKeyId=test-key&Expires=1900000000&Signature=a%2Bb%2Fc%3D';
const _publicUrl = 'https://cdn.example/avatar/a%20b.jpg';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <List<int>>[];
  bool missingSign = false;
  int status = 200;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    bodies.add(stream == null ? [] : await stream.expand((b) => b).toList());
    final response = options.path.endsWith('/upload/sign')
        ? missingSign
            ? <String, dynamic>{}
            : {
                'uploadUrl': _uploadUrl,
                'cdnUrl': _publicUrl,
                'key': 'avatar/a b.jpg'
              }
        : {
            'success': true,
            'primary_emotion': {
              'label': 'happy',
              'label_zh': '开心',
              'confidence': .9
            },
          };
    return ResponseBody.fromString(jsonEncode(response), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

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
          token: 'test-session',
          account: 'test-account',
          name: 'Test',
          merchantId: 1,
        ));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy OSS V1 URLs upgrade only the protocol, preserving signed bytes',
      () {
    final secure = secureOssUploadUrl(_uploadUrl);
    expect(secure, 'https${_uploadUrl.substring(4)}');
    expect(secureOssUploadUrl(secure), secure);
    expect(
        OssSignResult.fromJson({
          'uploadUrl': _uploadUrl,
          'cdnUrl': _publicUrl,
          'key': 'avatar/a b.jpg',
        }).uploadUrl,
        secure);
  });

  test('unrecognized cleartext and deceptive OSS hosts cannot bypass HTTPS',
      () {
    for (final url in [
      '',
      'http://oss.example/file',
      _uploadUrl.replaceFirst('aliyuncs.com', 'aliyuncs.com.evil.example'),
      _uploadUrl.replaceFirst('http://', 'http://user@'),
      _uploadUrl.replaceFirst('aliyuncs.com/', 'aliyuncs.com:80/'),
      _uploadUrl.replaceFirst('Signature=', 'missing='),
      '$_uploadUrl#fragment',
    ]) {
      expect(() => secureOssUploadUrl(url), throwsArgumentError);
    }
  });

  test(
      'missing signing fields fail explicitly before PUT or profile submission',
      () {
    for (final json in [
      <String, dynamic>{},
      {'uploadUrl': _uploadUrl},
      {'uploadUrl': '', 'cdnUrl': _publicUrl}
    ]) {
      expect(
          () => OssSignResult.fromJson(json),
          throwsA(isA<ApiException>()
              .having((e) => e.message, 'message', '上传凭证不完整，请重试')));
    }
  });

  for (final voice in [true, false]) {
    test(
        '${voice ? 'voice' : 'image'} signs, uploads with HTTPS, then analyzes CDN URL',
        () async {
      final business = _Adapter();
      final storage = _Adapter();
      final client = ApiClient(token: 'test-session', adapter: business);
      final dio = Dio()..httpClientAdapter = storage;
      addTearDown(dio.close);
      final repo = AiRepository(client,
          uploader: OssUploader(client, uploadClient: dio));
      final dir = await Directory.systemTemp.createTemp('petpogo-media-');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}/sample.${voice ? 'wav' : 'png'}')
          .writeAsBytes([0, 1, 255]);
      final stages = <String>[];
      final result = voice
          ? await repo.uploadAndAnalyzeVoice(
              file: file,
              account: 'test-account',
              onProgress: (stage, _) => stages.add(stage))
          : await repo.uploadAndAnalyzeImage(
              file: file,
              account: 'test-account',
              onProgress: (stage, _) => stages.add(stage));
      expect(result.primaryEmotion.label, 'happy');
      expect(business.requests.map((r) => r.uri.path), [
        '/sdkapi/upload/sign',
        '/sdkapi/ai-proxy/${voice ? 'voice' : 'image'}/analyze',
      ]);
      expect(
          (jsonDecode(utf8.decode(business.bodies.first)) as Map)['mimeType'],
          voice ? 'audio/wav' : 'image/png');
      final upload = storage.requests.single;
      expect(upload.uri.toString(), 'https${_uploadUrl.substring(4)}');
      expect(upload.method, 'PUT');
      expect(storage.bodies.single, [0, 1, 255]);
      expect(upload.contentType, isNull);
      expect(upload.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')));
      final analysis = utf8.decode(business.bodies.last);
      expect(analysis, contains('name="url"\r\n\r\n$_publicUrl'));
      expect(stages, containsAllInOrder(['upload', 'analyzing', 'done']));
    });

    test('${voice ? 'voice' : 'image'} upload failure never starts analysis',
        () async {
      final business = _Adapter();
      final storage = _Adapter()..status = 403;
      final client = ApiClient(token: 'test-session', adapter: business);
      final dio = Dio()..httpClientAdapter = storage;
      addTearDown(dio.close);
      final repo = AiRepository(client,
          uploader: OssUploader(client, uploadClient: dio));
      final dir = await Directory.systemTemp.createTemp('petpogo-media-');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}/sample.wav').writeAsBytes([1]);
      Future<void> analyze() async {
        if (voice) {
          await repo.uploadAndAnalyzeVoice(file: file, account: 'test');
        } else {
          await repo.uploadAndAnalyzeImage(file: file, account: 'test');
        }
      }

      await expectLater(analyze(), throwsA(isA<DioException>()));
      expect(business.requests, hasLength(1));
      business.missingSign = true;
      await expectLater(analyze(), throwsA(isA<ApiException>()));
      expect(storage.requests, hasLength(1));
      expect(business.requests.every((r) => r.path.endsWith('/upload/sign')),
          isTrue);
    });
  }

  test(
      'AI controller exposes wrapped API and upload errors with actionable copy',
      () async {
    for (final (status, expected) in [
      (502, 'AI 服务暂时不可用，请稍后重试'),
      (429, '请求过于频繁或 AI 额度不足，请稍后再试'),
    ]) {
      final business = _Adapter();
      final storage = _Adapter();
      final client = ApiClient(token: 'test-session', adapter: business);
      final dio = Dio()..httpClientAdapter = storage;
      final repo = AiRepository(client,
          uploader: OssUploader(client, uploadClient: dio));
      final container = ProviderContainer(overrides: [
        aiRepositoryProvider.overrideWithValue(repo),
        authControllerProvider
            .overrideWith((ref) => _SignedIn(_AuthRepo(), ref)),
      ]);
      final dir = await Directory.systemTemp.createTemp('petpogo-media-');
      try {
        // A successful PUT switches state to analyzing; fail only that request.
        final file = await File('${dir.path}/sample.wav').writeAsBytes([1]);
        final controller = container.read(aiVoiceControllerProvider.notifier);
        final subscription =
            container.listen(aiVoiceControllerProvider, (_, next) {
          if (next.phase == AiPhase.analyzing) business.status = status;
        });
        await controller.analyzeVoice(file);
        expect(
            container.read(aiVoiceControllerProvider).errorMessage, expected);
        subscription.close();
      } finally {
        container.dispose();
        dio.close();
        await dir.delete(recursive: true);
      }
    }
  });
}
