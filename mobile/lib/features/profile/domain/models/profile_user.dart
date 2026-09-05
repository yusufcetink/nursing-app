import 'package:asli_app/features/auth/domain/models/user_role.dart';

final class ProfileUser {
  const ProfileUser({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });

  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;

  String get fullName => '$firstName $lastName';
}
