import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/config/app_config.dart';
import 'package:asli_app/core/storage/token_storage.dart';
import 'package:asli_app/core/network/session_expiration.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final apiClient = ApiClient(
    tokenStorage: ref.watch(tokenStorageProvider),
    onSessionExpired: () =>
        ref.read(sessionExpirationProvider.notifier).notify(),
  );
  ref.onDispose(apiClient.close);
  return apiClient;
});

final class ApiClient {
  ApiClient({Dio? dio, this.tokenStorage, this.onSessionExpired})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
            ),
          ) {
    final configuredTokenStorage = tokenStorage;
    if (configuredTokenStorage != null) {
      this.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            try {
              if (_isOwnRequest(options) &&
                  !_isPublicAuthRequest(options) &&
                  !options.headers.containsKey('Authorization')) {
                final token = await configuredTokenStorage.readAccessToken();
                if (token != null && token.trim().isNotEmpty) {
                  options.headers['Authorization'] = 'Bearer $token';
                }
              }
              handler.next(options);
            } on Object catch (error) {
              handler.reject(
                DioException(requestOptions: options, error: error),
              );
            }
          },
          onError: _handleUnauthorized,
        ),
      );
    }
  }

  final Dio dio;
  final TokenStorage? tokenStorage;
  final void Function()? onSessionExpired;
  Future<String?>? _refreshing;
  bool _closed = false;
  static const _retried = 'asli_auth_retried';

  bool _isOwnRequest(RequestOptions options) =>
      options.uri.origin == Uri.parse(dio.options.baseUrl).origin;

  bool _isPublicAuthRequest(RequestOptions options) =>
      options.uri.path.startsWith('/api/auth/') &&
      options.uri.path != '/api/auth/me';

  Future<void> _handleUnauthorized(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final storage = tokenStorage;
    if (error.response?.statusCode != 401 ||
        storage == null ||
        !_isOwnRequest(request) ||
        _isPublicAuthRequest(request)) {
      handler.next(error);
      return;
    }
    try {
      final authorization = request.headers['Authorization'];
      if (authorization is! String || !authorization.startsWith('Bearer ')) {
        handler.next(error);
        return;
      }
      final sentToken = authorization.substring(7);
      final current = await storage.readAccessToken();
      if (current == null ||
          _closed ||
          request.cancelToken?.isCancelled == true) {
        handler.next(error);
        return;
      }
      if (request.extra[_retried] == true) {
        if (sentToken == current) {
          await _expire(current, await storage.readRefreshToken());
        }
        handler.next(error);
        return;
      }
      // A late 401 may arrive after another request already rotated the token.
      final token = sentToken == current
          ? await refreshAccessToken(expectedAccessToken: sentToken)
          : current;
      if (token == null ||
          _closed ||
          request.cancelToken?.isCancelled == true ||
          await storage.readAccessToken() != token) {
        handler.next(error);
        return;
      }
      final data = request.data;
      // FormData is finalized by Dio; clone it for the one permitted replay.
      // Arbitrary streams cannot be replayed safely.
      if (data is Stream) {
        handler.next(error);
        return;
      }
      final retry = request.copyWith(
        headers: {...request.headers, 'Authorization': 'Bearer $token'},
        extra: {...request.extra, _retried: true},
        data: data is FormData ? data.clone() : data,
      );
      handler.resolve(await dio.fetch<dynamic>(retry));
    } on DioException catch (retryError) {
      handler.next(retryError);
    } on Object {
      handler.next(error);
    }
  }

  Future<String?> refreshAccessToken({String? expectedAccessToken}) {
    return _refreshing ??= _refreshAccessToken(expectedAccessToken)
        .whenComplete(() => _refreshing = null);
  }

  Future<String?> _refreshAccessToken(String? expectedAccessToken) async {
    final storage = tokenStorage;
    if (storage == null || _closed) return null;
    final accessToken = await storage.readAccessToken();
    if (expectedAccessToken != null && expectedAccessToken != accessToken) {
      return accessToken;
    }
    final refreshToken = await storage.readRefreshToken();
    try {
      if (refreshToken == null || refreshToken.trim().isEmpty) {
        await _expire(accessToken, refreshToken);
        return null;
      }
      final response = await dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {
          'refreshToken': refreshToken,
          'deviceId': await storage.getDeviceId(),
        },
      );
      final access = response.data?['accessToken'];
      final refresh = response.data?['refreshToken'];
      if (access is! String ||
          access.trim().isEmpty ||
          refresh is! String ||
          refresh.trim().isEmpty) {
        throw const FormatException('Invalid refresh response.');
      }
      if (_closed) return null;
      final saved = await storage.rotateTokens(
        expectedRefreshToken: refreshToken,
        accessToken: access,
        refreshToken: refresh,
      );
      // Logout or another login during refresh must never be overwritten.
      return saved ? access : null;
    } on DioException catch (error) {
      // Only an explicitly rejected refresh token ends the session. A network
      // failure or server error leaves stored credentials available for retry.
      if (error.response?.statusCode == 401) {
        await _expire(accessToken, refreshToken);
        return null;
      }
      rethrow;
    }
  }

  Future<void> _expire(String? accessToken, String? refreshToken) async {
    if (await tokenStorage!.clearTokensIfUnchanged(
          accessToken: accessToken,
          refreshToken: refreshToken,
        ) &&
        !_closed) {
      onSessionExpired?.call();
    }
  }

  Future<Map<String, String>> authorizationHeaders() async {
    final token = await tokenStorage?.readAccessToken();
    return token == null || token.trim().isEmpty
        ? const {}
        : {'Authorization': 'Bearer $token'};
  }

  void close() {
    _closed = true;
    dio.close(force: true);
  }
}
