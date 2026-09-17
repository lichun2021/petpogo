import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/api_endpoints.dart';
import 'package:petpogo_app/features/digital_pet/data/repository/digital_pet_repository.dart';

class _Client implements ApiClient {
  dynamic response;
  String? path;
  dynamic payload;
  String? method;

  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? params, T Function(dynamic)? fromJson}) async {
    this.path = path;
    method = 'GET';
    return fromJson != null ? fromJson(response) : response as T;
  }

  @override
  Future<T> post<T>(String path,
      {dynamic data, T Function(dynamic)? fromJson, Options? options}) async {
    this.path = path;
    method = 'POST';
    payload = data;
    return fromJson != null ? fromJson(response) : response as T;
  }

  @override
  Future<T> put<T>(String path,
      {dynamic data, T Function(dynamic)? fromJson}) async {
    this.path = path;
    method = 'PUT';
    payload = data;
    return fromJson != null ? fromJson(response) : response as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DigitalPetRepository', () {
    test('fetchStatus parses a fully-configured pet', () async {
      final client = _Client()
        ..response = {
          'id': '55135763958784',
          'name': '小白',
          'species': 'cat',
          'breed': '英短',
          'gender': 0,
          'satiety': 66,
          'mood': 52,
          'cleanliness': 48,
          'background': {
            'id': '1',
            'name': '草地',
            'image_url': 'https://oss.example.com/grass.jpg'
          },
          'model': {
            'id': '1',
            'name': '橘猫形象',
            'glb_url': 'https://oss.example.com/cat.glb',
            'thumbnail_url': 'https://oss.example.com/cat_thumb.jpg'
          },
        };
      final result =
          await DigitalPetRepository(client).fetchStatus('55135763958784');
      expect(client.path, ApiEndpoints.petStatus('55135763958784'));
      expect(client.path, '/sdkapi/pet/55135763958784/status');
      final status = result.value!;
      expect(status.satiety, 66);
      expect(status.mood, 52);
      expect(status.cleanliness, 48);
      expect(status.background?.imageUrl, 'https://oss.example.com/grass.jpg');
      expect(status.model?.glbUrl, 'https://oss.example.com/cat.glb');
    });

    test('fetchStatus parses null background/model without throwing', () async {
      final client = _Client()
        ..response = {
          'id': '55135763958784',
          'name': '小白',
          'satiety': 70,
          'mood': 55,
          'cleanliness': 50,
          'background': null,
          'model': null,
        };
      final result =
          await DigitalPetRepository(client).fetchStatus('55135763958784');
      final status = result.value!;
      expect(status.background, isNull);
      expect(status.model, isNull);
      expect(status.satiety, 70);
    });

    test('interact posts interactionCode and parses updated stats + clipCode',
        () async {
      final client = _Client()
        ..response = {
          'satiety': 70,
          'mood': 55,
          'cleanliness': 50,
          'clipCode': 'feed',
        };
      final result =
          await DigitalPetRepository(client).interact('55135763958784', 'feed');
      expect(client.method, 'POST');
      expect(client.path, '/sdkapi/pet/55135763958784/interact');
      expect(client.payload, {'interactionCode': 'feed'});
      final r = result.value!;
      expect(r.satiety, 70);
      expect(r.clipCode, 'feed');
    });

    test('interact parses a null clipCode (interaction not mapped to an animation)',
        () async {
      final client = _Client()
        ..response = {
          'satiety': 70,
          'mood': 55,
          'cleanliness': 50,
          'clipCode': null,
        };
      final result =
          await DigitalPetRepository(client).interact('55135763958784', 'feed');
      expect(result.value!.clipCode, isNull);
    });

    test('fetchResources parses backgrounds/models/glbActions/interactionTypes',
        () async {
      final client = _Client()
        ..response = {
          'backgrounds': [
            {
              'id': '1',
              'name': '草地',
              'image_url': 'https://oss.example.com/grass.jpg'
            }
          ],
          'models': [
            {
              'id': '1',
              'name': '橘猫形象',
              'glb_url': 'https://oss.example.com/cat.glb',
              'thumbnail_url': 'https://oss.example.com/cat_thumb.jpg'
            }
          ],
          'glbActions': [
            {'id': '1', 'code': 'lying', 'name': '躺卧动画'}
          ],
          'interactionTypes': [
            {
              'id': '1',
              'code': 'feed',
              'name': '喂食',
              'icon_url': '',
              'satiety_delta': 20,
              'mood_delta': 5,
              'cleanliness_delta': 0,
              'clipCode': 'feed'
            }
          ],
        };
      final result = await DigitalPetRepository(client).fetchResources();
      expect(client.path, ApiEndpoints.petResources);
      expect(client.path, '/sdkapi/pet/resources');
      final res = result.value!;
      expect(res.backgrounds.single.name, '草地');
      expect(res.models.single.glbUrl, 'https://oss.example.com/cat.glb');
      expect(res.glbActions.single.code, 'lying');
      expect(res.interactionTypes.single.satietyDelta, 20);
    });

    test('fetchAction parses a reported action with mapped clipCode', () async {
      final client = _Client()
        ..response = {
          'code': 'lying',
          'reportedAt': '2026-09-16T04:35:15.911Z',
          'clipCode': 'lying',
        };
      final result =
          await DigitalPetRepository(client).fetchAction('55135763958784');
      expect(client.path, '/sdkapi/pet/55135763958784/action');
      expect(result.value!.code, 'lying');
      expect(result.value!.clipCode, 'lying');
    });

    test('fetchAction parses an unmapped action code (clipCode null)', () async {
      final client = _Client()
        ..response = {
          'code': 'lying',
          'reportedAt': '2026-09-16T04:35:15.911Z',
          'clipCode': null,
        };
      final result =
          await DigitalPetRepository(client).fetchAction('55135763958784');
      expect(result.value!.code, 'lying');
      expect(result.value!.clipCode, isNull);
    });

    test('fetchAction parses a device that has never reported (all null)',
        () async {
      final client = _Client()
        ..response = {'code': null, 'reportedAt': null, 'clipCode': null};
      final result =
          await DigitalPetRepository(client).fetchAction('55135763958784');
      expect(result.value!.code, isNull);
      expect(result.value!.reportedAt, isNull);
      expect(result.value!.clipCode, isNull);
    });

    test('updateResourceSelection sends only name + provided ids', () async {
      final client = _Client()..response = {'success': true};
      await DigitalPetRepository(client).updateResourceSelection(
        '55135763958784',
        currentName: '小白',
        backgroundId: '1',
      );
      expect(client.method, 'PUT');
      expect(client.path, '/sdkapi/pet/55135763958784');
      expect(client.payload, {'name': '小白', 'backgroundId': '1'});
    });

    test('updateResourceSelection can set modelId without touching backgroundId',
        () async {
      final client = _Client()..response = {'success': true};
      await DigitalPetRepository(client).updateResourceSelection(
        '55135763958784',
        currentName: '小白',
        modelId: '2',
      );
      expect(client.payload, {'name': '小白', 'modelId': '2'});
    });
  });
}
