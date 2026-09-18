import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/api_endpoints.dart';
import 'package:petpogo_app/core/api/result.dart';
import 'package:petpogo_app/features/pet/data/models/pet_model.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_repository.dart';

/// 记录最近一次调用的 path/data/method，其余方法交给 noSuchMethod 兜底。
class _Client implements ApiClient {
  String? path;
  dynamic payload;
  dynamic response;

  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? params, T Function(dynamic)? fromJson}) async {
    this.path = path;
    return fromJson != null ? fromJson(response) : response as T;
  }

  @override
  Future<T> post<T>(String path,
      {dynamic data, T Function(dynamic)? fromJson, Options? options}) async {
    this.path = path;
    payload = data;
    return fromJson != null ? fromJson(response) : response as T;
  }

  @override
  Future<T> put<T>(String path,
      {dynamic data, T Function(dynamic)? fromJson}) async {
    this.path = path;
    payload = data;
    return fromJson != null ? fromJson(response) : response as T;
  }

  @override
  Future<void> delete(String path) async {
    this.path = path;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _petJson = {
  'id': '55135763958784',
  'name': '小白',
  'avatar': null,
  'species': 'cat',
  'breed': '英短',
  'gender': 0,
  'birthday': null,
  'weight': null,
  'bio': null,
  'device_id': null,
};

void main() {
  group('PetRepository', () {
    test('fetchPets calls GET /sdkapi/pet/list and parses list', () async {
      final client = _Client()..response = [_petJson];
      final result = await PetRepository(client).fetchPets();
      expect(client.path, ApiEndpoints.petList);
      expect(client.path, '/sdkapi/pet/list');
      final pets = (result as Success<List<PetModel>>).data;
      expect(pets.single.name, '小白');
      expect(pets.single.type, 'cat');
    });

    test('fetchPetDetail calls GET /sdkapi/pet/:id and parses vitals',
        () async {
      final client = _Client()
        ..response = {
          ..._petJson,
          'satiety': 70,
          'mood': 55,
          'cleanliness': 50,
          'background_id': null,
          'model_id': null,
        };
      final result =
          await PetRepository(client).fetchPetDetail('55135763958784');
      expect(client.path, '/sdkapi/pet/55135763958784');
      final pet = (result as Success<PetModel>).data;
      expect(pet.satiety, 70);
      expect(pet.mood, 55);
      expect(pet.cleanliness, 50);
    });

    test('updatePet calls PUT /sdkapi/pet/:id with full payload', () async {
      final client = _Client()..response = {'success': true};
      const pet = PetModel(
        id: '55135763958784',
        name: '小白',
        type: 'cat',
        breed: '英短',
        gender: 'female',
        backgroundId: '1',
        modelId: '1',
      );
      final result = await PetRepository(client).updatePet(pet);
      expect(client.path, '/sdkapi/pet/55135763958784');
      expect(client.payload, {
        'id': '55135763958784',
        'name': '小白',
        'species': 'cat',
        'breed': '英短',
        'gender': 2,
        'backgroundId': '1',
        'modelId': '1',
      });
      expect(result.isSuccess, isTrue);
    });

  });
}
