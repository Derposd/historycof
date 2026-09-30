import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../providers.dart';
import 'guest_profile.dart';
import 'token_store.dart';

/// Состояние входа: `null` — гость не авторизован (приложение работает,
/// но бонусы и история обращений недоступны), иначе — профиль.
final authControllerProvider = AsyncNotifierProvider<AuthController, GuestProfile?>(AuthController.new);

/// Удобный синхронный доступ: авторизован ли гость прямо сейчас.
final isSignedInProvider = Provider<bool>((ref) => ref.watch(authControllerProvider).value != null);

class AuthController extends AsyncNotifier<GuestProfile?> {
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  @override
  Future<GuestProfile?> build() async {
    final tokens = await _tokens.load();
    if (tokens == null) return null;
    try {
      return await _fetchProfile();
    } on ApiException catch (e) {
      if (e.isUnauthorized || e.statusCode == 404) {
        await _tokens.clear();
        return null;
      }
      // Нет сети — показываем закэшированный профиль, чтобы не выкидывать гостя.
      final cached = await _tokens.readProfileCache();
      if (cached != null) return GuestProfile.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      rethrow;
    }
  }

  Future<GuestProfile> _fetchProfile() async {
    final json = await ref.read(apiClientProvider).get<Map<String, dynamic>>('/me');
    final profile = GuestProfile.fromJson(json);
    await _tokens.writeProfileCache(jsonEncode(profile.toJson()));
    return profile;
  }

  Future<OtpRequestResult> requestOtp(String phone) async {
    final json = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>('/auth/otp/request', data: {'phone': phone}, auth: false);
    return OtpRequestResult.fromJson(json);
  }

  Future<GuestProfile> verifyOtp({
    required String phone,
    required String code,
    bool acceptPersonalData = false,
    bool acceptMarketing = false,
    String? name,
  }) async {
    final json = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/auth/otp/verify',
          auth: false,
          data: {
            'phone': phone,
            'code': code,
            if (acceptPersonalData) 'acceptPersonalData': true,
            if (acceptMarketing) 'acceptMarketing': true,
            if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          },
        );
    await _tokens.save(Tokens(access: json['accessToken'] as String, refresh: json['refreshToken'] as String));
    final profile = GuestProfile.fromJson(json['guest'] as Map<String, dynamic>);
    await _tokens.writeProfileCache(jsonEncode(profile.toJson()));
    state = AsyncData(profile);
    return profile;
  }

  Future<void> refreshProfile() async {
    if (_tokens.current == null) return;
    state = AsyncData(await _fetchProfile());
  }

  Future<void> updateProfile({String? name, bool? pushNewsEnabled, String? birthday}) async {
    final json = await ref
        .read(apiClientProvider)
        .patch<Map<String, dynamic>>(
          '/me',
          data: {'name': ?name, 'pushNewsEnabled': ?pushNewsEnabled, 'birthday': ?birthday},
        );
    final profile = GuestProfile.fromJson(json);
    await _tokens.writeProfileCache(jsonEncode(profile.toJson()));
    state = AsyncData(profile);
  }

  Future<void> acceptConsent() async {
    final json = await ref.read(apiClientProvider).post<Map<String, dynamic>>('/me/consent');
    state = AsyncData(GuestProfile.fromJson(json));
  }

  Future<void> logout() async {
    final refresh = _tokens.current?.refresh;
    if (refresh != null) {
      // Отзываем refresh-токен на сервере, но не ждём сеть для выхода.
      unawaited(
        ref
            .read(apiClientProvider)
            .post<void>('/auth/logout', data: {'refreshToken': refresh}, auth: false)
            .catchError((_) {}),
      );
    }
    await _tokens.clear();
    state = const AsyncData(null);
  }

  /// Удаление аккаунта (отзыв согласия на обработку ПДн).
  Future<void> deleteAccount() async {
    await ref.read(apiClientProvider).delete<void>('/me');
    await _tokens.clear();
    state = const AsyncData(null);
  }

  void onSessionExpired() {
    unawaited(_tokens.clear());
    state = const AsyncData(null);
  }
}
