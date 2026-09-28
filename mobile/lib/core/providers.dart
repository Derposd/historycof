import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'auth/auth_controller.dart';
import 'auth/token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokens: ref.watch(tokenStoreProvider),
    // Refresh-токен отозван/истёк — выходим из аккаунта локально.
    onSessionExpired: () => ref.read(authControllerProvider.notifier).onSessionExpired(),
  );
});
