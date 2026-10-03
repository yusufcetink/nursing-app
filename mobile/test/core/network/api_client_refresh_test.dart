import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/storage/token_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/session_expiration.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_learning_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<SecureTokenStorage> storage({
    bool persist = true,
    String? refresh = 'old-refresh',
  }) async {
    final result = SecureTokenStorage();
    await result.writeTokens(
      accessToken: 'old-access',
      refreshToken: refresh,
      persist: persist,
    );
    return result;
  }

  ApiClient client(
    TokenStorage tokens,
    _Adapter adapter, {
    void Function()? expired,
  }) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;
    final result = ApiClient(
      dio: dio,
      tokenStorage: tokens,
      onSessionExpired: expired,
    );
    addTearDown(result.close);
    return result;
  }

  final rotated = {'accessToken': 'new-access', 'refreshToken': 'new-refresh'};

  test('normal 200 adds access token and does not refresh', () async {
    final tokens = await storage();
    final adapter = _Adapter((request) async {
      expect(request.headers['Authorization'], 'Bearer old-access');
      return _reply(200, {'ok': true});
    });
    expect((await client(tokens, adapter).dio.get('/data')).statusCode, 200);
    expect(adapter.requests, hasLength(1));
  });

  test(
    'non-remembered login removes previously persisted credentials',
    () async {
      final tokens = await storage();
      await tokens.writeTokens(
        accessToken: 'session-access',
        refreshToken: 'session-refresh',
        persist: false,
      );
      expect(await tokens.readRefreshToken(), 'session-refresh');
      expect(await SecureTokenStorage().readAccessToken(), isNull);
      expect(await SecureTokenStorage().readRefreshToken(), isNull);
    },
  );

  test(
    'refresh 401 updates auth state to logged out and clears progress',
    () async {
      final tokens = await storage();
      final adapter = _Adapter((_) async => _reply(401, {}));
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWith(
            (ref) => client(
              tokens,
              adapter,
              expired: () =>
                  ref.read(sessionExpirationProvider.notifier).notify(),
            ),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(restoredUser: FakeAuthRepository.user),
          ),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(completedLessons: [testCompletedLesson]),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(await container.read(authControllerProvider.future), isNotNull);
      await container.read(progressControllerProvider.future);
      await expectLater(
        container.read(apiClientProvider).dio.get('/data'),
        throwsA(isA<DioException>()),
      );
      expect(container.read(authControllerProvider).value, isNull);
      expect(
        container
            .read(progressControllerProvider)
            .requireValue
            .completedLessonIds,
        isEmpty,
      );
    },
  );

  test('missing refresh token logs out without attempting refresh', () async {
    final tokens = await storage(persist: false, refresh: null);
    var expired = 0;
    final adapter = _Adapter((_) async => _reply(401, {}));
    await expectLater(
      client(tokens, adapter, expired: () => expired++).dio.get('/data'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests, hasLength(1));
    expect(expired, 1);
    expect(await tokens.readAccessToken(), isNull);
  });

  test(
    'multipart upload can be retried after FormData was finalized',
    () async {
      final tokens = await storage();
      final adapter = _Adapter((request) async {
        if (request.path == '/api/auth/refresh') return _reply(200, rotated);
        expect((request.data as FormData).isFinalized, isTrue);
        return _reply(
          request.headers['Authorization'] == 'Bearer new-access' ? 200 : 401,
          {},
        );
      });
      final data = FormData.fromMap({
        'title': 'test',
        'file': MultipartFile.fromBytes([1, 2, 3], filename: 'test.png'),
      });
      expect(
        (await client(
          tokens,
          adapter,
        ).dio.post('/upload', data: data)).statusCode,
        200,
      );
      expect(adapter.requests, hasLength(3));
      expect(
        identical(adapter.requests.first.data, adapter.requests.last.data),
        isFalse,
      );
    },
  );

  for (final persist in [true, false]) {
    test(
      '401 refreshes and retries original POST preserving persist=$persist',
      () async {
        final tokens = await storage(persist: persist);
        final adapter = _Adapter((request) async {
          if (request.path == '/api/auth/refresh') {
            expect(request.data['refreshToken'], 'old-refresh');
            expect(request.data['deviceId'], isNotEmpty);
            expect(request.headers['Authorization'], isNull);
            return _reply(200, rotated);
          }
          expect(request.method, 'POST');
          expect(request.queryParameters, {'page': 2});
          expect(request.data, {'answer': 1});
          return _reply(
            request.headers['Authorization'] == 'Bearer new-access' ? 200 : 401,
            {},
          );
        });
        final result = await client(
          tokens,
          adapter,
        ).dio.post('/data', data: {'answer': 1}, queryParameters: {'page': 2});
        expect(result.statusCode, 200);
        expect(adapter.requests, hasLength(3));
        expect(await tokens.readAccessToken(), 'new-access');
        expect(await tokens.readRefreshToken(), 'new-refresh');
        final restarted = SecureTokenStorage();
        expect(
          await restarted.readAccessToken(),
          persist ? 'new-access' : null,
        );
        expect(
          await restarted.readRefreshToken(),
          persist ? 'new-refresh' : null,
        );
      },
    );
  }

  test('concurrent and late 401 responses share a single refresh', () async {
    final tokens = await storage();
    final firstRequests = Completer<void>();
    final lateResponse = Completer<void>();
    var oldRequests = 0;
    var refreshCalls = 0;
    final adapter = _Adapter((request) async {
      if (request.path == '/api/auth/refresh') {
        refreshCalls++;
        await firstRequests.future;
        return _reply(200, rotated);
      }
      if (request.headers['Authorization'] == 'Bearer new-access') {
        return _reply(200, {});
      }
      if (++oldRequests == 3) firstRequests.complete();
      await firstRequests.future;
      if (request.path == '/late') await lateResponse.future;
      return _reply(401, {});
    });
    final api = client(tokens, adapter);
    final first = api.dio.get('/first');
    final second = api.dio.get('/second');
    final late = api.dio.get('/late');
    await Future.wait([first, second]);
    lateResponse.complete();
    await late;
    expect(refreshCalls, 1);
    expect(adapter.requests, hasLength(7));
  });

  test('rejected refresh clears session once without recursion', () async {
    final tokens = await storage();
    var expired = 0;
    final adapter = _Adapter((request) async => _reply(401, {}));
    final api = client(tokens, adapter, expired: () => expired++);
    await expectLater(api.dio.get('/data'), throwsA(isA<DioException>()));
    expect(adapter.requests.map((r) => r.path), ['/data', '/api/auth/refresh']);
    expect(expired, 1);
    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.readRefreshToken(), isNull);
    expect(await SecureTokenStorage().readRefreshToken(), isNull);
  });

  for (final refreshStatus in [500, 200]) {
    test('failed or malformed refresh $refreshStatus keeps session', () async {
      final tokens = await storage();
      var expired = 0;
      final adapter = _Adapter(
        (request) async => _reply(
          request.path == '/api/auth/refresh' ? refreshStatus : 401,
          {},
        ),
      );
      await expectLater(
        client(tokens, adapter, expired: () => expired++).dio.get('/data'),
        throwsA(isA<DioException>()),
      );
      expect(expired, 0);
      expect(await tokens.readAccessToken(), 'old-access');
      expect(await tokens.readRefreshToken(), 'old-refresh');
      expect(await SecureTokenStorage().readRefreshToken(), 'old-refresh');
    });
  }

  test('connection failure during refresh keeps session', () async {
    final tokens = await storage();
    var expired = 0;
    final adapter = _Adapter((request) async {
      if (request.path == '/api/auth/refresh') {
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        );
      }
      return _reply(401, {});
    });
    await expectLater(
      client(tokens, adapter, expired: () => expired++).dio.get('/data'),
      throwsA(isA<DioException>()),
    );
    expect(expired, 0);
    expect(await tokens.readRefreshToken(), 'old-refresh');
  });

  test('retried 401 expires session without a second refresh', () async {
    final tokens = await storage();
    var expired = 0;
    final adapter = _Adapter(
      (request) async => request.path == '/api/auth/refresh'
          ? _reply(200, rotated)
          : _reply(401, {}),
    );
    await expectLater(
      client(tokens, adapter, expired: () => expired++).dio.get('/data'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests, hasLength(3));
    expect(
      adapter.requests.where((r) => r.path == '/api/auth/refresh'),
      hasLength(1),
    );
    expect(expired, 1);
    expect(await tokens.readAccessToken(), isNull);
  });

  test('logout during refresh cannot resurrect a session', () async {
    final tokens = await storage();
    final refreshing = Completer<void>();
    final release = Completer<void>();
    final adapter = _Adapter((request) async {
      if (request.path != '/api/auth/refresh') return _reply(401, {});
      refreshing.complete();
      await release.future;
      return _reply(200, rotated);
    });
    final api = client(tokens, adapter);
    final failure = expectLater(
      api.dio.get('/data'),
      throwsA(isA<DioException>()),
    );
    await refreshing.future;
    await tokens.deleteTokens();
    release.complete();
    await failure;
    expect(await tokens.readRefreshToken(), isNull);
    expect(adapter.requests, hasLength(2));
  });

  test('failed refresh from old login cannot clear a newer login', () async {
    final tokens = await storage();
    final refreshing = Completer<void>();
    final release = Completer<void>();
    var expired = 0;
    final adapter = _Adapter((request) async {
      if (request.path != '/api/auth/refresh') return _reply(401, {});
      refreshing.complete();
      await release.future;
      return _reply(401, {});
    });
    final failure = expectLater(
      client(tokens, adapter, expired: () => expired++).dio.get('/data'),
      throwsA(isA<DioException>()),
    );
    await refreshing.future;
    await tokens.writeTokens(
      accessToken: 'other-access',
      refreshToken: 'other-refresh',
      persist: false,
    );
    release.complete();
    await failure;
    expect(await tokens.readAccessToken(), 'other-access');
    expect(await tokens.readRefreshToken(), 'other-refresh');
    expect(expired, 0);
  });

  test('login and refresh 401 are never automatically refreshed', () async {
    final tokens = await storage();
    final adapter = _Adapter((_) async => _reply(401, {}));
    final api = client(tokens, adapter);
    await expectLater(
      api.dio.post('/api/auth/login'),
      throwsA(isA<DioException>()),
    );
    await expectLater(
      api.dio.post('/api/auth/refresh'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests, hasLength(2));
    expect(await tokens.readAccessToken(), 'old-access');
  });
}

ResponseBody _reply(int status, Object json) => ResponseBody.fromString(
  jsonEncode(json),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
