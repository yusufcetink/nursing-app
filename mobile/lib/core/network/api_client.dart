import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/config/app_config.dart';
import 'package:asli_app/core/storage/token_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final apiClient = ApiClient(tokenStorage: ref.watch(tokenStorageProvider));
  ref.onDispose(apiClient.close);
  return apiClient;
});

final class ApiClient {
  ApiClient({Dio? dio, TokenStorage? tokenStorage})
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
    if (tokenStorage != null) {
      this.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (!options.headers.containsKey('Authorization')) {
              final token = await tokenStorage.read();
              if (token != null && token.trim().isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            }
            handler.next(options);
          },
        ),
      );
    }
  }

  final Dio dio;

  void close() {
    dio.close(force: true);
  }
}
