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

  @override
  Future<String?> readAccessToken() async {
    return _volatileAccessToken ?? _storage.read(key: _accessTokenKey);
  }

  @override
  Future<String?> readRefreshToken() async {
    return _volatileRefreshToken ?? _storage.read(key: _refreshTokenKey);
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
  }) async {
    if (persist && (refreshToken == null || refreshToken.trim().isEmpty)) {
      throw ArgumentError('A refresh token is required for persistent login.');
    }

    if (!persist) {
      await _deletePersistedTokens();
      _volatileAccessToken = accessToken;
      _volatileRefreshToken = null;
      return;
    }

    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    _volatileAccessToken = accessToken;
    _volatileRefreshToken = refreshToken;
  }

  @override
  Future<void> deleteTokens() async {
    _volatileAccessToken = null;
    _volatileRefreshToken = null;
    await _deletePersistedTokens();
  }

  Future<void> _deletePersistedTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
