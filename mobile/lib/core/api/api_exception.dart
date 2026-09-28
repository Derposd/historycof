import 'package:dio/dio.dart';

/// Ошибка API в удобном для UI виде. Backend отвечает
/// `{ statusCode, error, message }`, где message — строка или массив строк.
class ApiException implements Exception {
  ApiException({required this.message, this.code, this.statusCode, this.data = const {}});

  final String message;

  /// Машиночитаемый код: consent_required, otp_invalid, otp_cooldown, loyalty_unavailable…
  final String? code;
  final int? statusCode;
  final Map<String, dynamic> data;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == null;

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException(
        message: switch (e.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.sendTimeout => 'Сервер долго не отвечает. Проверьте интернет и попробуйте ещё раз',
          _ => 'Нет соединения с интернетом',
        },
      );
    }
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final raw = body['message'];
    final message = switch (raw) {
      final String s when s.isNotEmpty => s,
      final List<dynamic> l when l.isNotEmpty => l.first.toString(),
      _ => _fallback(res.statusCode),
    };
    final error = body['error'];
    return ApiException(message: message, code: error is String ? error : null, statusCode: res.statusCode, data: body);
  }

  static String _fallback(int? status) => switch (status) {
    401 => 'Сессия истекла, войдите заново',
    403 => 'Недостаточно прав',
    404 => 'Не найдено',
    429 => 'Слишком много попыток, подождите немного',
    503 => 'Сервис временно недоступен',
    _ => 'Что-то пошло не так. Попробуйте ещё раз',
  };

  /// Текст для показа пользователю из любой ошибки.
  static String messageOf(Object error) => switch (error) {
    final ApiException e => e.message,
    final DioException e => ApiException.fromDio(e).message,
    _ => 'Что-то пошло не так. Попробуйте ещё раз',
  };

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}
