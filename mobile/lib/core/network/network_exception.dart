import 'package:dio/dio.dart';

final class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;
}

NetworkException mapNetworkException(DioException error) {
  if (error.response?.statusCode == 401) {
    return const NetworkException(
      'Oturumunuz sona ermiş olabilir. Lütfen yeniden giriş yapın.',
    );
  }
  if (error.response?.statusCode == 404) {
    return const NetworkException('İstenen içerik bulunamadı.');
  }
  if (error.response?.statusCode == 403) {
    return const NetworkException('Bu işlem için yetkiniz bulunmuyor.');
  }
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(
      'Sunucu yanıt vermedi. Lütfen tekrar deneyin.',
    ),
    DioExceptionType.connectionError => const NetworkException(
      'Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.',
    ),
    _ => const NetworkException('İçerik yüklenemedi. Lütfen tekrar deneyin.'),
  };
}

String networkErrorMessage(Object error) {
  return switch (error) {
    NetworkException(:final message) => message,
    _ => 'İçerik yüklenemedi. Lütfen tekrar deneyin.',
  };
}
