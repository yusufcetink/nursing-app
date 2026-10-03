import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/storage/token_storage.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/auth/data/models/auth_api_models.dart';

void main() {
  test('reset password isteği yalnızca 6 haneli kodu gönderir', () {
    final json = const ResetPasswordRequest(
      email: 'student@example.com',
      code: '123456',
      newPassword: 'SecurePass1!',
    ).toJson();

    expect(json['code'], '123456');
    expect(json.containsKey('token'), isFalse);
  });

  test('register hesabı oluşturur ve doğrulama öncesi token yazmaz', () async {
    final adapter = _SequenceAdapter([
      _JsonResponse(201, {
        'id': '4fa2f657-d064-4565-9f7a-dd35454df1ab',
        'firstName': 'Ayşe',
        'lastName': 'Yılmaz',
        'email': 'ayse@example.com',
        'roles': ['Student'],
      }),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
      ..httpClientAdapter = adapter;
    final storage = _MemoryTokenStorage();
    final repository = DioAuthRepository(
      ApiClient(dio: dio, tokenStorage: storage),
      storage,
    );

    await repository.register(
      const RegisterRequest(
        firstName: 'Ayşe',
        lastName: 'Yılmaz',
        email: 'ayse@example.com',
        password: 'SecurePass1!',
      ),
    );

    expect(adapter.requests.single.path, '/api/auth/register');
    expect(storage.accessToken, isNull);
  });

  test('401 yanıtını anlaşılır login hatasına dönüştürür', () async {
    final adapter = _SequenceAdapter([
      _JsonResponse(401, {
        'errors': ['Invalid email or password.'],
      }),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
      ..httpClientAdapter = adapter;
    final repository = DioAuthRepository(
      ApiClient(dio: dio),
      _MemoryTokenStorage(),
    );

    expect(
      () => repository.login(
        const LoginRequest(
          email: 'student@example.com',
          password: 'WrongPass1!',
          rememberMe: true,
        ),
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Email veya şifre hatalı.',
        ),
      ),
    );
  });

  test('backend kayıt hatasını kullanıcıya anlaşılır hale getirir', () async {
    final adapter = _SequenceAdapter([
      _JsonResponse(400, {
        'errors': ['An account with this email already exists.'],
      }),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
      ..httpClientAdapter = adapter;
    final repository = DioAuthRepository(
      ApiClient(dio: dio),
      _MemoryTokenStorage(),
    );

    expect(
      () => repository.register(
        const RegisterRequest(
          firstName: 'Ayşe',
          lastName: 'Yılmaz',
          email: 'ayse@example.com',
          password: 'SecurePass1!',
        ),
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Bu email adresiyle kayıtlı bir hesap zaten var.',
        ),
      ),
    );
  });

  test(
    'saklanan tokenı me endpointi ile doğrulayıp kullanıcıyı döndürür',
    () async {
      final adapter = _SequenceAdapter([
        _JsonResponse(200, {
          'id': '4fa2f657-d064-4565-9f7a-dd35454df1ab',
          'firstName': 'Ayşe',
          'lastName': 'Yılmaz',
          'email': 'ayse@example.com',
          'roles': ['Student'],
        }),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
        ..httpClientAdapter = adapter;
      final storage = _MemoryTokenStorage('stored-jwt-token');
      final repository = DioAuthRepository(
        ApiClient(dio: dio, tokenStorage: storage),
        storage,
      );

      final user = await repository.restoreSession();

      expect(user?.email, 'ayse@example.com');
      expect(adapter.requests.single.path, '/api/auth/me');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer stored-jwt-token',
      );
      expect(storage.accessToken, 'stored-jwt-token');
    },
  );

  test('geçersiz saklanan tokenı siler ve session döndürmez', () async {
    final adapter = _SequenceAdapter([_JsonResponse(401, const {})]);
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
      ..httpClientAdapter = adapter;
    final storage = _MemoryTokenStorage('expired-jwt-token');
    final repository = DioAuthRepository(
      ApiClient(dio: dio, tokenStorage: storage),
      storage,
    );

    final user = await repository.restoreSession();

    expect(user, isNull);
    expect(storage.accessToken, isNull);
  });

  test('remember true tokenları kalıcı yazar ve parolayı saklamaz', () async {
    final adapter = _SequenceAdapter([_JsonResponse(200, _loginResponse())]);
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
      ..httpClientAdapter = adapter;
    final storage = _MemoryTokenStorage();
    final repository = DioAuthRepository(
      ApiClient(dio: dio, tokenStorage: storage),
      storage,
    );

    await repository.login(
      const LoginRequest(
        email: 'student@example.com',
        password: 'SecurePass1!',
        rememberMe: true,
      ),
    );

    expect(adapter.requests.single.data['rememberMe'], isTrue);
    expect(adapter.requests.single.data['deviceId'], 'test-device');
    expect(storage.accessToken, 'new-access-token');
    expect(storage.refreshToken, 'new-refresh-token');
    expect(storage.persisted, isTrue);
    expect(storage.storedValues, isNot(containsValue('SecurePass1!')));
  });

  test('remember false access tokenı yalnızca geçici tutar', () async {
    final adapter = _SequenceAdapter([_JsonResponse(200, _loginResponse())]);
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
      ..httpClientAdapter = adapter;
    final storage = _MemoryTokenStorage();
    final repository = DioAuthRepository(
      ApiClient(dio: dio, tokenStorage: storage),
      storage,
    );

    await repository.login(
      const LoginRequest(
        email: 'student@example.com',
        password: 'SecurePass1!',
        rememberMe: false,
      ),
    );

    expect(storage.accessToken, 'new-access-token');
    expect(storage.refreshToken, 'new-refresh-token');
    expect(storage.persisted, isFalse);
    expect(storage.storedValues, isEmpty);
  });

  test(
    'expired access token valid refresh ile döndürülür ve rotate edilir',
    () async {
      final adapter = _SequenceAdapter([
        _JsonResponse(401, const {}),
        _JsonResponse(200, _loginResponse()),
        _JsonResponse(200, _loginResponse()['user'] as Map<String, Object?>),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
        ..httpClientAdapter = adapter;
      final storage = _MemoryTokenStorage('expired-access', 'old-refresh');
      final repository = DioAuthRepository(
        ApiClient(dio: dio, tokenStorage: storage),
        storage,
      );

      final user = await repository.restoreSession();

      expect(user?.email, 'ayse@example.com');
      expect(adapter.requests.map((request) => request.path), [
        '/api/auth/me',
        '/api/auth/refresh',
        '/api/auth/me',
      ]);
      expect(adapter.requests[1].data['refreshToken'], 'old-refresh');
      expect(storage.accessToken, 'new-access-token');
      expect(storage.refreshToken, 'new-refresh-token');
    },
  );

  test('revoked refresh token storageı temizler ve login ister', () async {
    final adapter = _SequenceAdapter([
      _JsonResponse(401, const {}),
      _JsonResponse(401, const {}),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
      ..httpClientAdapter = adapter;
    final storage = _MemoryTokenStorage('expired-access', 'revoked-refresh');
    final repository = DioAuthRepository(
      ApiClient(dio: dio, tokenStorage: storage),
      storage,
    );

    expect(await repository.restoreSession(), isNull);
    expect(storage.accessToken, isNull);
    expect(storage.refreshToken, isNull);
  });

  test(
    'logout refresh tokenı revoke eder ve local tokenları temizler',
    () async {
      final adapter = _SequenceAdapter([_JsonResponse(204, const {})]);
      final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
        ..httpClientAdapter = adapter;
      final storage = _MemoryTokenStorage('access', 'refresh');
      final repository = DioAuthRepository(
        ApiClient(dio: dio, tokenStorage: storage),
        storage,
      );

      await repository.logout();

      expect(adapter.requests.single.path, '/api/auth/logout');
      expect(adapter.requests.single.data['refreshToken'], 'refresh');
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
    },
  );
}

final class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage([this.accessToken, this.refreshToken]);

  String? accessToken;
  String? refreshToken;
  bool? persisted;
  final Map<String, String> storedValues = {};

  @override
  Future<void> deleteTokens() async {
    accessToken = null;
    refreshToken = null;
    storedValues.clear();
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<bool> rotateTokens({
    required String expectedRefreshToken,
    required String accessToken,
    required String refreshToken,
  }) async {
    if (await readRefreshToken() != expectedRefreshToken) {
      return false;
    }
    await writeTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      persist: true,
    );
    return true;
  }

  @override
  Future<bool> clearTokensIfUnchanged({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    if (await readAccessToken() != accessToken ||
        await readRefreshToken() != refreshToken ||
        (accessToken == null && refreshToken == null)) {
      return false;
    }
    await deleteTokens();
    return true;
  }

  @override
  Future<String> getDeviceId() async => 'test-device';

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String? refreshToken,
    required bool persist,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    persisted = persist;
    storedValues.clear();
    if (persist) {
      storedValues['accessToken'] = accessToken;
      if (refreshToken != null) storedValues['refreshToken'] = refreshToken;
    }
  }
}

Map<String, Object?> _loginResponse({
  String? refreshToken = 'new-refresh-token',
}) => {
  'accessToken': 'new-access-token',
  'expiresAtUtc': '2026-09-19T12:00:00Z',
  'refreshToken': refreshToken,
  'refreshTokenExpiresAtUtc': refreshToken == null
      ? null
      : '2026-10-19T12:00:00Z',
  'user': {
    'id': '4fa2f657-d064-4565-9f7a-dd35454df1ab',
    'firstName': 'Ayşe',
    'lastName': 'Yılmaz',
    'email': 'ayse@example.com',
    'roles': ['Student'],
  },
};

final class _JsonResponse {
  const _JsonResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, Object?> body;
}

final class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this._responses);

  final List<_JsonResponse> _responses;
  final List<RequestOptions> requests = [];
  var _responseIndex = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = _responses[_responseIndex++];
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
