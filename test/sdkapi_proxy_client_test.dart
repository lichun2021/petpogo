import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/api_client.dart';
import 'package:petpogo_app/core/api/api_endpoints.dart';
import 'package:petpogo_app/core/api/peer_api_client.dart';
import 'package:petpogo_app/core/config/app_config.dart';
import 'package:petpogo_app/features/auth/data/country_repository.dart';

class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <String>[];
  Stream<Uint8List>? streamResponse;
  Future<void>? cancellation;
  String response = '{"code":0,"info":{},"list":[]}';
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancelFuture) async {
    requests.add(options);
    cancellation = cancelFuture;
    bodies.add(
        body == null ? '' : utf8.decode(await body.expand((x) => x).toList()));
    if (streamResponse != null) {
      return ResponseBody(streamResponse!, 200, headers: {
        'content-type': ['text/event-stream']
      });
    }
    return ResponseBody.fromString(response, 200, headers: {
      'content-type': ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('direct SDK AI paths are signed and token refresh is respected',
      () async {
    final adapter = RecordingAdapter();
    final client = ApiClient(token: 'old', adapter: adapter)..setToken('new');
    await client.post(ApiEndpoints.healthDataOverview,
        data: {'pet_id': '123', 'account': 'stale'});
    final req = adapter.requests.single;
    expect(req.uri.toString(),
        '${AppConfig.apiBaseUrl}/sdkapi/ai-proxy/health-data/overview');
    expect(req.headers['Authorization'], 'Bearer new');
    expect(req.headers['x-api-key'], isNull);
    expect(req.headers['x-signature'], matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(req.headers['x-nonce'].toString().length, greaterThanOrEqualTo(16));
    expect(req.receiveTimeout, const Duration(seconds: 130));
    expect(jsonDecode(adapter.bodies.single), {'pet_id': '123'});
    client.clearToken();
    await client.post('/sdkapi/pet/list');
    expect(adapter.requests.last.headers['Authorization'], isNull);
    expect(adapter.requests.last.receiveTimeout, const Duration(seconds: 15));
  });
  test(
      'Peer form preserves long IDs and JSON shadow strings; sound remains JSON',
      () async {
    final adapter = RecordingAdapter();
    final peer = PeerApiClient(ApiClient(token: 'login', adapter: adapter));
    await peer.post('/device/shadow/update', params: {
      'mac': 'm',
      'data': '{"speed":50}',
      'deviceId': '1234647089750028288'
    });
    final req = adapter.requests.last;
    expect(req.uri.path, '/sdkapi/peer/device/shadow/update');
    expect(req.headers['token'], isNull);
    expect(req.contentType, Headers.formUrlEncodedContentType);
    expect(req.receiveTimeout, const Duration(seconds: 30));
    expect(Uri.splitQueryString(adapter.bodies.last)['deviceId'],
        '1234647089750028288');
    expect(Uri.splitQueryString(adapter.bodies.last)['data'], '{"speed":50}');
    await peer.soundPlay(mac: 'm', url: 'https://example.test/a.mp3');
    expect(jsonDecode(adapter.bodies.last)['volume'], 15);
    await peer.get('/pet/share/mylist', params: {'pageNo': 2});
    expect(adapter.requests.last.method, 'GET');
    expect(adapter.requests.last.uri.queryParameters['pageNo'], '2');
  });
  test(
      'country requests are signed without login and preserve bare default object',
      () async {
    final adapter = RecordingAdapter()
      ..response = '{"countryName":"中国","countryId":"CN","phoneId":"+86"}';
    final repo = CountryRepository(ApiClient(adapter: adapter));
    final country = await repo.fetchDefault();
    expect(country.countryId, 'CN');
    expect(
        adapter.requests.single.uri.path, '/sdkapi/peer/world/country/default');
    expect(adapter.requests.single.headers['Authorization'], isNull);
    expect(adapter.requests.single.headers['x-signature'], isNotNull);
    adapter.response =
        '{"code":0,"info":[{"id":"1","country":"中国","countryEn":"China","countryId":"CN","phoneId":"+86"}]}';
    expect(await repo.fetchList(), hasLength(1));
    expect(adapter.requests.last.uri.path, '/sdkapi/peer/world/country/list');
  });
  test('AI multipart keeps URL and pet ID; recording stop retains long budget',
      () async {
    final adapter = RecordingAdapter();
    final client = ApiClient(adapter: adapter);
    await client.post(ApiEndpoints.aiVoiceAnalyze,
        data: FormData.fromMap({
          'url': 'https://example.test/p.wav',
          'account': 'old',
          'pet_id': '999'
        }));
    expect(
        adapter.requests.last.contentType, startsWith('multipart/form-data'));
    expect(adapter.bodies.last, contains('name="url"'));
    expect(adapter.bodies.last, contains('name="pet_id"'));
    expect(adapter.bodies.last, isNot(contains('name="account"')));
    await client.post(ApiEndpoints.recordingStop, data: {'device_no': 'm'});
    expect(adapter.requests.last.receiveTimeout, const Duration(seconds: 310));
  });
  test('SSE stays streaming through the proxy and preserves split UTF-8 frames',
      () async {
    final adapter = RecordingAdapter();
    final bytes =
        utf8.encode('event: delta\ndata: "你好"\n\nevent: done\ndata: "你好"\n\n');
    adapter.streamResponse =
        Stream.fromIterable(bytes.map((b) => Uint8List.fromList([b])));
    final client = ApiClient(token: 'login', adapter: adapter);
    final frames = await client.postStream(ApiEndpoints.aiConsultMessagesStream,
        data: {'session_id': 's', 'text': 'hi'}).toList();
    expect(frames.map((f) => f.event), ['delta', 'done']);
    expect(frames.first.data, '"你好"');
    expect(
        adapter.requests.single.uri.path, '/sdkapi/ai-proxy/messages/stream');
    expect(adapter.requests.single.headers['Accept'], 'text/event-stream');
    expect(adapter.requests.single.responseType, ResponseType.stream);
    expect(adapter.requests.single.receiveTimeout, Duration.zero);
    await adapter.cancellation!.timeout(const Duration(seconds: 1));
  });
}
