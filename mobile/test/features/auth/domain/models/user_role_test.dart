import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/auth/domain/models/user_role.dart';

void main() {
  test('typed roller yalnızca ilgili basit yetenekleri sağlar', () {
    expect(UserRole.student.canManageContent, isFalse);
    expect(UserRole.student.canAccessAdministration, isFalse);

    expect(UserRole.contentEditor.canManageContent, isTrue);
    expect(UserRole.contentEditor.canAccessAdministration, isFalse);

    expect(UserRole.admin.canManageContent, isTrue);
    expect(UserRole.admin.canAccessAdministration, isTrue);
  });
}
