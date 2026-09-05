import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/auth/data/models/auth_api_models.dart';
import 'package:asli_app/features/auth/domain/models/authenticated_user.dart';
import 'package:asli_app/features/auth/domain/models/user_role.dart';

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.error, this.restoreError, this.restoredUser});

  final AuthException? error;
  final AuthException? restoreError;
  final AuthenticatedUser? restoredUser;
  int restoreSessionCallCount = 0;
  int loginCallCount = 0;
  int registerCallCount = 0;
  int verifyEmailCallCount = 0;
  int resendVerificationCallCount = 0;
  int forgotPasswordCallCount = 0;
  int resetPasswordCallCount = 0;
  int logoutCallCount = 0;

  static final user = AuthenticatedUser(
    id: '7a73a68e-4ccd-43eb-b293-fbd419af96d0',
    firstName: 'Ayşe',
    lastName: 'Yılmaz',
    email: 'ayse@example.com',
    roles: const [UserRole.student],
  );

  @override
  Future<AuthenticatedUser?> restoreSession() async {
    restoreSessionCallCount++;
    if (restoreError case final restoreError?) {
      throw restoreError;
    }
    return restoredUser;
  }

  @override
  Future<AuthenticatedUser> login(LoginRequest request) async {
    loginCallCount++;
    if (error case final error?) {
      throw error;
    }
    return user;
  }

  @override
  Future<void> register(RegisterRequest request) async {
    registerCallCount++;
    if (error case final error?) {
      throw error;
    }
  }

  @override
  Future<void> verifyEmail(VerifyEmailRequest request) async {
    verifyEmailCallCount++;
    if (error case final error?) throw error;
  }

  @override
  Future<void> resendVerification(EmailRequest request) async {
    resendVerificationCallCount++;
    if (error case final error?) throw error;
  }

  @override
  Future<void> forgotPassword(EmailRequest request) async {
    forgotPasswordCallCount++;
    if (error case final error?) throw error;
  }

  @override
  Future<void> resetPassword(ResetPasswordRequest request) async {
    resetPasswordCallCount++;
    if (error case final error?) throw error;
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
    if (error case final error?) {
      throw error;
    }
  }
}
