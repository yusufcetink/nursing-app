import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return SecureTokenStorage();
});

abstract interface class TokenStorage {
  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  Future<String> getDeviceId();

  Future<void> writeTokens({
    required String accessToken,
    required String? refreshToken,
    required bool persist,
  });

  Future<void> deleteTokens();

  Future<bool> rotateTokens({
    required String expectedRefreshToken,
    required String accessToken,
    required String refreshToken,
  });

  Future<bool> clearTokensIfUnchanged({
    required String? accessToken,
    required String? refreshToken,
  });
}

final class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _deviceIdKey = 'auth_device_id';

  final FlutterSecureStorage _storage;
  String? _volatileAccessToken;
  String? _volatileRefreshToken;
  bool _loaded = false;
  bool _persist = false;
  Future<void>? _loading;
  Future<void> _operations = Future.value();

  Future<void> _load() {
    if (_loaded) return Future.value();
    return _loading ??= _readStoredTokens().whenComplete(() => _loading = null);
  }

  Future<void> _readStoredTokens() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    _volatileAccessToken = accessToken;
    _volatileRefreshToken = refreshToken;
    _persist = _volatileRefreshToken != null;
    _loaded = true;
  }

  Future<T> _mutate<T>(Future<T> Function() action) {
    final operation = _operations.then((_) async {
      await _load();
      return action();
    });
    _operations = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<String?> readAccessToken() async {
    await _operations;
    await _load();
    return _volatileAccessToken;
  }

  @override
  Future<String?> readRefreshToken() async {
    await _operations;
    await _load();
    return _volatileRefreshToken;
  }

  @override
  Future<String> getDeviceId() async {
    final stored = await _storage.read(key: _deviceIdKey);
    if (stored != null && stored.trim().isNotEmpty) return stored;

    final random = Random.secure();
    final id = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String? refreshToken,
    required bool persist,
  }) => _mutate(() => _writeTokens(accessToken, refreshToken, persist));

  Future<void> _writeTokens(
    String accessToken,
    String? refreshToken,
    bool persist,
  ) async {
    if (persist && (refreshToken == null || refreshToken.trim().isEmpty)) {
      throw ArgumentError('A refresh token is required for persistent login.');
    }

    if (!persist) {
      await _deletePersistedTokens();
      _volatileAccessToken = accessToken;
      _volatileRefreshToken = refreshToken;
      _persist = false;
      return;
    }

    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    _volatileAccessToken = accessToken;
    _volatileRefreshToken = refreshToken;
    _persist = true;
  }

  @override
  Future<void> deleteTokens() => _mutate(_clearTokens);

  Future<void> _clearTokens() async {
    _volatileAccessToken = null;
    _volatileRefreshToken = null;
    _persist = false;
    await _deletePersistedTokens();
  }

  @override
  Future<bool> rotateTokens({
    required String expectedRefreshToken,
    required String accessToken,
    required String refreshToken,
  }) => _mutate(() async {
    if (_volatileRefreshToken != expectedRefreshToken) {
      return false;
    }
    await _writeTokens(accessToken, refreshToken, _persist);
    return true;
  });

  @override
  Future<bool> clearTokensIfUnchanged({
    required String? accessToken,
    required String? refreshToken,
  }) => _mutate(() async {
    if (_volatileAccessToken != accessToken ||
        _volatileRefreshToken != refreshToken ||
        (_volatileAccessToken == null && _volatileRefreshToken == null)) {
      return false;
    }
    await _clearTokens();
    return true;
  });

  Future<void> _deletePersistedTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
