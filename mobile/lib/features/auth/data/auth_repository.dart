import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/storage/token_storage.dart';
import 'package:asli_app/features/auth/data/models/auth_api_models.dart';
import 'package:asli_app/features/auth/domain/models/authenticated_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return DioAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

abstract interface class AuthRepository {
  Future<AuthenticatedUser?> restoreSession();

  Future<AuthenticatedUser> login(LoginRequest request);

  Future<void> register(RegisterRequest request);

  Future<void> verifyEmail(VerifyEmailRequest request);

  Future<void> resendVerification(EmailRequest request);

  Future<void> forgotPassword(EmailRequest request);

  Future<void> resetPassword(ResetPasswordRequest request);

  Future<void> logout();
}

final class DioAuthRepository implements AuthRepository {
  const DioAuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  @override
  Future<AuthenticatedUser?> restoreSession() async {
    try {
      final token = await _tokenStorage.read();
      if (token == null || token.trim().isEmpty) {
        return null;
      }

      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty current user response.');
      }
      return UserResponse.fromJson(data).toDomain();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _tokenStorage.delete();
        return null;
      }
      throw AuthException(_messageFor(error));
    } on FormatException {
      throw const AuthException('Oturum doğrulanamadı. Lütfen tekrar deneyin.');
    } catch (_) {
      throw const AuthException('Oturum doğrulanamadı. Lütfen tekrar deneyin.');
    }
  }

  @override
  Future<AuthenticatedUser> login(LoginRequest request) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty login response.');
      }
      final loginResponse = LoginResponse.fromJson(data);
      await _tokenStorage.write(loginResponse.accessToken);
      return loginResponse.user.toDomain();
    } on DioException catch (error) {
      throw AuthException(_messageFor(error));
    } on FormatException {
      throw const AuthException(
        'Sunucudan beklenmeyen bir yanıt alındı. Lütfen tekrar deneyin.',
      );
    } catch (_) {
      throw const AuthException('Giriş tamamlanamadı. Lütfen tekrar deneyin.');
    }
  }

  @override
  Future<void> register(RegisterRequest request) async {
    try {
      await _apiClient.dio.post<void>(
        '/api/auth/register',
        data: request.toJson(),
      );
    } on DioException catch (error) {
      throw AuthException(_messageFor(error));
    } catch (_) {
      throw const AuthException('Kayıt tamamlanamadı. Lütfen tekrar deneyin.');
    }
  }

  @override
  Future<void> verifyEmail(VerifyEmailRequest request) {
    return _post('/api/auth/verify-email', request.toJson());
  }

  @override
  Future<void> resendVerification(EmailRequest request) {
    return _post('/api/auth/resend-verification', request.toJson());
  }

  @override
  Future<void> forgotPassword(EmailRequest request) {
    return _post('/api/auth/forgot-password', request.toJson());
  }

  @override
  Future<void> resetPassword(ResetPasswordRequest request) {
    return _post('/api/auth/reset-password', request.toJson());
  }

  @override
  Future<void> logout() async {
    try {
      await _tokenStorage.delete();
    } catch (_) {
      throw const AuthException(
        'Güvenli oturum bilgisi silinemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  Future<void> _post(String path, Map<String, Object> data) async {
    try {
      await _apiClient.dio.post<void>(path, data: data);
    } on DioException catch (error) {
      throw AuthException(_messageFor(error));
    } catch (_) {
      throw const AuthException('İşlem tamamlanamadı. Lütfen tekrar deneyin.');
    }
  }

  static String _messageFor(DioException error) {
    final serverErrors = _serverErrors(error.response?.data);
    if (serverErrors.isNotEmpty) {
      return serverErrors.join('\n');
    }

    if (error.response?.statusCode == 401) {
      return 'Email veya şifre hatalı.';
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'Sunucu yanıt vermedi. Lütfen bağlantınızı kontrol edip tekrar deneyin.',
      DioExceptionType.connectionError =>
        'Sunucuya ulaşılamadı. Lütfen bağlantınızı kontrol edin.',
      _ => 'İşlem tamamlanamadı. Lütfen tekrar deneyin.',
    };
  }

  static List<String> _serverErrors(Object? data) {
    if (data is! Map) {
      return const [];
    }

    final errors = data['errors'];
    if (errors is List) {
      return errors.whereType<String>().map(_friendlyServerError).toList();
    }
    if (errors is Map) {
      return errors.values
          .whereType<List>()
          .expand((messages) => messages.whereType<String>())
          .map(_friendlyServerError)
          .toList();
    }
    return const [];
  }

  static String _friendlyServerError(String message) {
    if (message.contains('Invalid email or password')) {
      return 'Email veya şifre hatalı.';
    }
    if (message.contains('already exists')) {
      return 'Bu email adresiyle kayıtlı bir hesap zaten var.';
    }
    if (message.contains('not verified')) {
      return 'Giriş yapmadan önce email adresinizi doğrulayın.';
    }
    if (message.contains('verification request')) {
      return 'Doğrulama kodu geçersiz veya süresi dolmuş.';
    }
    if (message.contains('reset request')) {
      return 'Şifre sıfırlama kodu geçersiz veya süresi dolmuş.';
    }
    if (message.contains('Verification email could not be sent')) {
      return 'Doğrulama emaili gönderilemedi. Lütfen tekrar deneyin.';
    }
    if (message.contains('non alphanumeric')) {
      return 'Şifre en az bir özel karakter içermelidir.';
    }
    if (message.contains('uppercase')) {
      return 'Şifre en az bir büyük harf içermelidir.';
    }
    if (message.contains('lowercase')) {
      return 'Şifre en az bir küçük harf içermelidir.';
    }
    if (message.contains('digit')) {
      return 'Şifre en az bir rakam içermelidir.';
    }
    if (message.contains('at least')) {
      return 'Şifre belirtilen minimum uzunluğu karşılamıyor.';
    }
    return message;
  }
}

final class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}
