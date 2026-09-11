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
    final repository = DioAuthRepository(ApiClient(dio: dio), storage);

    await repository.register(
      const RegisterRequest(
        firstName: 'Ayşe',
        lastName: 'Yılmaz',
        email: 'ayse@example.com',
        password: 'SecurePass1!',
      ),
    );

    expect(adapter.requests.single.path, '/api/auth/register');
    expect(storage.token, isNull);
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
      final repository = DioAuthRepository(ApiClient(dio: dio), storage);

      final user = await repository.restoreSession();

      expect(user?.email, 'ayse@example.com');
      expect(adapter.requests.single.path, '/api/auth/me');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer stored-jwt-token',
      );
      expect(storage.token, 'stored-jwt-token');
    },
  );

  test('geçersiz saklanan tokenı siler ve session döndürmez', () async {
    final adapter = _SequenceAdapter([_JsonResponse(401, const {})]);
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
      ..httpClientAdapter = adapter;
    final storage = _MemoryTokenStorage('expired-jwt-token');
    final repository = DioAuthRepository(ApiClient(dio: dio), storage);

    final user = await repository.restoreSession();

    expect(user, isNull);
    expect(storage.token, isNull);
  });
}

final class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage([this.token]);

  String? token;

  @override
  Future<void> delete() async {
    token = null;
  }

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async {
    this.token = token;
  }
}

final class _JsonResponse {
  const _JsonResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, Object> body;
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
