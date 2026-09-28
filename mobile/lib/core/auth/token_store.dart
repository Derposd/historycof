import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Tokens {
  const Tokens({required this.access, required this.refresh});

  final String access;
  final String refresh;
}

/// Хранит токены в защищённом хранилище (Keychain / EncryptedSharedPreferences)
/// и держит копию в памяти для быстрых запросов.
abstract class TokenStore {
  Tokens? get current;
  Future<Tokens?> load();
  Future<void> save(Tokens tokens);
  Future<void> clear();

  /// Кэш профиля — чтобы при запуске без сети не «разлогинивать» гостя.
  Future<String?> readProfileCache();
  Future<void> writeProfileCache(String? json);
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  Tokens? _current;

  static const _kAccess = 'hc.access';
  static const _kRefresh = 'hc.refresh';
  static const _kProfile = 'hc.profile';

  @override
  Tokens? get current => _current;

  @override
  Future<Tokens?> load() async {
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    _current = access != null && refresh != null ? Tokens(access: access, refresh: refresh) : null;
    return _current;
  }

  @override
  Future<void> save(Tokens tokens) async {
    _current = tokens;
    await _storage.write(key: _kAccess, value: tokens.access);
    await _storage.write(key: _kRefresh, value: tokens.refresh);
  }

  @override
  Future<void> clear() async {
    _current = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kProfile);
  }

  @override
  Future<String?> readProfileCache() => _storage.read(key: _kProfile);

  @override
  Future<void> writeProfileCache(String? json) =>
      json == null ? _storage.delete(key: _kProfile) : _storage.write(key: _kProfile, value: json);
}

/// Для тестов.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._current]);

  Tokens? _current;
  String? _profile;

  @override
  Tokens? get current => _current;
  @override
  Future<Tokens?> load() async => _current;
  @override
  Future<void> save(Tokens tokens) async => _current = tokens;
  @override
  Future<void> clear() async {
    _current = null;
    _profile = null;
  }

  @override
  Future<String?> readProfileCache() async => _profile;
  @override
  Future<void> writeProfileCache(String? json) async => _profile = json;
}
