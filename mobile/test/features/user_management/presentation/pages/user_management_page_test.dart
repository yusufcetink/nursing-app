import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/auth/domain/models/user_role.dart';
import 'package:asli_app/features/user_management/data/user_management_repository.dart';
import 'package:asli_app/features/user_management/domain/models/managed_user.dart';
import 'package:asli_app/features/user_management/presentation/pages/user_management_page.dart';

void main() {
  testWidgets('kullanıcı arar, rolü değiştirir ve başarı gösterir', (
    tester,
  ) async {
    final repository = FakeUserManagementRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userManagementRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: UserManagementPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('ayse@example.com'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('user_search_field')), 'Ayşe');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.lastSearch, 'Ayşe');

    await tester.tap(find.byKey(const Key('role_user-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ContentEditor').last);
    await tester.pumpAndSettle();

    expect(repository.changedRole, UserRole.contentEditor);
    expect(find.textContaining('olarak güncellendi'), findsOneWidget);
  });
}

final class FakeUserManagementRepository implements UserManagementRepository {
  String lastSearch = '';
  UserRole? changedRole;

  final _user = const ManagedUser(
    id: 'user-1',
    firstName: 'Ayşe',
    lastName: 'Yılmaz',
    email: 'ayse@example.com',
    role: UserRole.student,
  );

  @override
  Future<List<ManagedUser>> getUsers(String search) async {
    lastSearch = search;
    return [_user.copyWith(role: changedRole)];
  }

  @override
  Future<ManagedUser> changeRole(String userId, UserRole role) async {
    changedRole = role;
    return _user.copyWith(role: role);
  }
}
