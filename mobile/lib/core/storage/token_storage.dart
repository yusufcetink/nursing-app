import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return const SecureTokenStorage();
});

abstract interface class TokenStorage {
  Future<void> write(String token);

  Future<String?> read();

  Future<void> delete();
}

final class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  @override
  Future<String?> read() {
    return _storage.read(key: _tokenKey);
  }

  @override
  Future<void> delete() {
    return _storage.delete(key: _tokenKey);
  }
}
