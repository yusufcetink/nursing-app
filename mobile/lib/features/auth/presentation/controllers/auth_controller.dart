import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/auth/data/models/auth_api_models.dart';
import 'package:asli_app/features/auth/domain/models/authenticated_user.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthenticatedUser?>(
      AuthController.new,
    );

final class AuthController extends AsyncNotifier<AuthenticatedUser?> {
  Object? _lastActionError;

  Object? get lastActionError => _lastActionError;

  @override
  Future<AuthenticatedUser?> build() {
    return ref.read(authRepositoryProvider).restoreSession();
  }

  Future<void> restoreSession() async {
    _lastActionError = null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      ref.read(authRepositoryProvider).restoreSession,
    );
  }

  Future<bool> login({required String email, required String password}) {
    return _authenticate(
      () => ref
          .read(authRepositoryProvider)
          .login(LoginRequest(email: email.trim(), password: password)),
    );
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    return _runPublicAction(
      () => ref
          .read(authRepositoryProvider)
          .register(
            RegisterRequest(
              firstName: firstName.trim(),
              lastName: lastName.trim(),
              email: email.trim(),
              password: password,
            ),
          ),
    );
  }

  Future<bool> verifyEmail({required String email, required String code}) {
    return _runPublicAction(
      () => ref
          .read(authRepositoryProvider)
          .verifyEmail(
            VerifyEmailRequest(email: email.trim(), code: code.trim()),
          ),
    );
  }

  Future<bool> resendVerification({required String email}) {
    return _runPublicAction(
      () => ref
          .read(authRepositoryProvider)
          .resendVerification(EmailRequest(email: email.trim())),
    );
  }

  Future<bool> forgotPassword({required String email}) {
    return _runPublicAction(
      () => ref
          .read(authRepositoryProvider)
          .forgotPassword(EmailRequest(email: email.trim())),
    );
  }

  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) {
    return _runPublicAction(
      () => ref
          .read(authRepositoryProvider)
          .resetPassword(
            ResetPasswordRequest(
              email: email.trim(),
              token: token.trim(),
              newPassword: newPassword,
            ),
          ),
    );
  }

  Future<bool> logout() async {
    final previous = state;
    _lastActionError = null;
    try {
      await ref.read(authRepositoryProvider).logout();
      state = const AsyncData(null);
      return true;
    } catch (error) {
      _lastActionError = error;
      state = previous;
      return false;
    }
  }

  Future<bool> _authenticate(
    Future<AuthenticatedUser> Function() authenticate,
  ) async {
    _lastActionError = null;
    state = const AsyncLoading();
    try {
      state = AsyncData(await authenticate());
      return true;
    } catch (error, stackTrace) {
      _lastActionError = error;
      state = AsyncError<AuthenticatedUser?>(error, stackTrace);
      return false;
    }
  }

  Future<bool> _runPublicAction(Future<void> Function() action) async {
    _lastActionError = null;
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      _lastActionError = error;
      state = AsyncError<AuthenticatedUser?>(error, stackTrace);
      return false;
    }
  }
}

String authErrorMessage(Object? error) {
  return switch (error) {
    AuthException(:final message) => message,
    _ => 'İşlem tamamlanamadı. Lütfen tekrar deneyin.',
  };
}
