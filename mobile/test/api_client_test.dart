import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:history_coffee/core/api/api_client.dart';
import 'package:history_coffee/core/api/api_exception.dart';
import 'package:history_coffee/core/auth/token_store.dart';

/// Фейковый HTTP-адаптер: отвечает по пути и записывает запросы.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions o) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(o);
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  test('401 → refresh → повтор запроса с новым токеном', () async {
    final store = MemoryTokenStore(const Tokens(access: 'old', refresh: 'r1'));
    var expired = false;
    final adapter = FakeAdapter((o) {
      if (o.path == '/me') {
        return o.headers['Authorization'] == 'Bearer new' ? json(200, {'ok': true}) : json(401, {});
      }
      if (o.path == '/auth/refresh') return json(200, {'accessToken': 'new', 'refreshToken': 'r2'});
      return json(404, {});
    });
    final client = ApiClient(tokens: store, onSessionExpired: () => expired = true, baseUrl: 'https://api.test');
    client.dio.httpClientAdapter = adapter;
    // refresh идёт через отдельный Dio — подменяем адаптер и ему
    client.refreshDioForTest.httpClientAdapter = adapter;

    final res = await client.get<Map<String, dynamic>>('/me');
    expect(res['ok'], isTrue);
    expect(store.current!.refresh, 'r2');
    expect(expired, isFalse);
  });

  test('параллельные 401 обновляют токен один раз', () async {
    final store = MemoryTokenStore(const Tokens(access: 'old', refresh: 'r1'));
    var refreshes = 0;
    final adapter = FakeAdapter((o) {
      if (o.path == '/auth/refresh') {
        refreshes++;
        return json(200, {'accessToken': 'new', 'refreshToken': 'r2'});
      }
      return o.headers['Authorization'] == 'Bearer new' ? json(200, {'ok': true}) : json(401, {});
    });
    final client = ApiClient(tokens: store, onSessionExpired: () {}, baseUrl: 'https://api.test');
    client.dio.httpClientAdapter = adapter;
    client.refreshDioForTest.httpClientAdapter = adapter;

    await Future.wait([client.get<dynamic>('/a'), client.get<dynamic>('/b'), client.get<dynamic>('/c')]);
    expect(refreshes, 1);
  });

  test('refresh не удался — сессия завершается, ошибка 401 пробрасывается', () async {
    final store = MemoryTokenStore(const Tokens(access: 'old', refresh: 'revoked'));
    var expired = false;
    final adapter = FakeAdapter((o) => json(401, {'message': 'Сессия истекла, войдите заново'}));
    final client = ApiClient(tokens: store, onSessionExpired: () => expired = true, baseUrl: 'https://api.test');
    client.dio.httpClientAdapter = adapter;
    client.refreshDioForTest.httpClientAdapter = adapter;

    await expectLater(
      client.get<dynamic>('/me'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(expired, isTrue);
  });

  test('публичные запросы не отправляют токен', () async {
    final store = MemoryTokenStore(const Tokens(access: 'tkn', refresh: 'r'));
    final adapter = FakeAdapter((o) => json(200, {}));
    final client = ApiClient(tokens: store, onSessionExpired: () {}, baseUrl: 'https://api.test');
    client.dio.httpClientAdapter = adapter;

    await client.get<dynamic>('/menu', auth: false);
    await client.get<dynamic>('/me');
    expect(adapter.requests[0].headers.containsKey('Authorization'), isFalse);
    expect(adapter.requests[1].headers['Authorization'], 'Bearer tkn');
  });
}
