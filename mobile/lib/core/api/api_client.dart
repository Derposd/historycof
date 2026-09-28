import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../auth/token_store.dart';
import '../config.dart';
import 'api_exception.dart';
import 'demo_interceptor.dart';

/// HTTP-клиент приложения: подставляет access-токен, при 401 один раз
/// обновляет пару через refresh-токен (с ротацией) и повторяет запрос.
/// Параллельные запросы ждут одно общее обновление.
class ApiClient {
  ApiClient({required this.tokens, required this.onSessionExpired, Dio? dio, String? baseUrl})
    : dio = dio ?? Dio(_options(baseUrl ?? AppConfig.apiUrl)),
      _refreshDio = Dio(_options(baseUrl ?? AppConfig.apiUrl)) {
    if (AppConfig.demo && dio == null) {
      final demo = DemoInterceptor();
      this.dio.interceptors.add(demo);
      _refreshDio.interceptors.add(demo);
    }
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final access = tokens.current?.access;
          if (access != null && options.extra['auth'] != false) {
            options.headers['Authorization'] = 'Bearer $access';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final req = error.requestOptions;
          final canRetry =
              error.response?.statusCode == 401 &&
              tokens.current != null &&
              req.extra['retried'] != true &&
              req.extra['auth'] != false;
          if (!canRetry) return handler.next(error);

          final refreshed = await _refresh();
          if (!refreshed) {
            onSessionExpired();
            return handler.next(error);
          }
          try {
            req.extra['retried'] = true;
            req.headers['Authorization'] = 'Bearer ${tokens.current!.access}';
            handler.resolve(await this.dio.fetch<dynamic>(req));
          } on DioException catch (e) {
            handler.next(e);
          }
        },
      ),
    );
  }

  final TokenStore tokens;
  final void Function() onSessionExpired;
  final Dio dio;
  final Dio _refreshDio;
  Completer<bool>? _refreshing;

  @visibleForTesting
  Dio get refreshDioForTest => _refreshDio;

  static BaseOptions _options(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
  );

  Future<bool> _refresh() {
    final pending = _refreshing;
    if (pending != null) return pending.future;
    final completer = _refreshing = Completer<bool>();
    () async {
      try {
        final current = tokens.current;
        if (current == null) return completer.complete(false);
        final res = await _refreshDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': current.refresh},
        );
        final body = res.data!;
        await tokens.save(Tokens(access: body['accessToken'] as String, refresh: body['refreshToken'] as String));
        completer.complete(true);
      } catch (_) {
        completer.complete(false);
      } finally {
        _refreshing = null;
      }
    }();
    return completer.future;
  }

  Future<T> _wrap<T>(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      return res.data as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query, bool auth = true}) => _wrap(
    () => dio.get<dynamic>(
      path,
      queryParameters: query,
      options: Options(extra: {'auth': auth}),
    ),
  );

  Future<T> post<T>(String path, {Object? data, bool auth = true}) => _wrap(
    () => dio.post<dynamic>(
      path,
      data: data,
      options: Options(extra: {'auth': auth}),
    ),
  );

  Future<T> patch<T>(String path, {Object? data}) => _wrap(() => dio.patch<dynamic>(path, data: data));

  Future<T> delete<T>(String path) => _wrap(() => dio.delete<dynamic>(path));
}
