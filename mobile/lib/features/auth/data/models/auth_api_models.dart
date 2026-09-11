import 'package:asli_app/features/auth/domain/models/authenticated_user.dart';
import 'package:asli_app/features/auth/domain/models/user_role.dart';

final class RegisterRequest {
  const RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String password;

  Map<String, Object> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'password': password,
  };
}

final class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, Object> toJson() => {'email': email, 'password': password};
}

final class EmailRequest {
  const EmailRequest({required this.email});

  final String email;

  Map<String, Object> toJson() => {'email': email};
}

final class VerifyEmailRequest {
  const VerifyEmailRequest({required this.email, required this.code});

  final String email;
  final String code;

  Map<String, Object> toJson() => {'email': email, 'code': code};
}

final class ResetPasswordRequest {
  const ResetPasswordRequest({
    required this.email,
    required this.code,
    required this.newPassword,
  });

  final String email;
  final String code;
  final String newPassword;

  Map<String, Object> toJson() => {
    'email': email,
    'code': code,
    'newPassword': newPassword,
  };
}

final class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.expiresAtUtc,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['accessToken'] as String,
      expiresAtUtc: DateTime.parse(json['expiresAtUtc'] as String).toUtc(),
      user: UserResponse.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
    );
  }

  final String accessToken;
  final DateTime expiresAtUtc;
  final UserResponse user;
}

final class UserResponse {
  UserResponse({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required List<UserRole> roles,
  }) : roles = List.unmodifiable(roles);

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      roles: (json['roles'] as List<dynamic>)
          .cast<String>()
          .map(UserRole.fromApiValue)
          .toList(),
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final List<UserRole> roles;

  AuthenticatedUser toDomain() {
    return AuthenticatedUser(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      roles: roles,
    );
  }
}
