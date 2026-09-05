enum UserRole {
  student,
  contentEditor,
  admin;

  static UserRole fromApiValue(String value) {
    return switch (value) {
      'Student' => UserRole.student,
      'ContentEditor' => UserRole.contentEditor,
      'Admin' => UserRole.admin,
      _ => throw FormatException('Unsupported user role.'),
    };
  }

  bool get canManageContent =>
      this == UserRole.contentEditor || this == UserRole.admin;

  bool get canAccessAdministration => this == UserRole.admin;
}
