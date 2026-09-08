import 'package:asli_app/features/auth/domain/models/user_role.dart';

final class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;

  String get fullName => '$firstName $lastName';

  ManagedUser copyWith({UserRole? role}) => ManagedUser(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    role: role ?? this.role,
  );
}
