import 'package:asli_app/features/auth/domain/models/user_role.dart';

final class AuthenticatedUser {
  AuthenticatedUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required List<UserRole> roles,
  }) : roles = List.unmodifiable(roles);

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final List<UserRole> roles;

  UserRole get primaryRole => roles.first;

  bool get canManageContent => roles.any((role) => role.canManageContent);
}
