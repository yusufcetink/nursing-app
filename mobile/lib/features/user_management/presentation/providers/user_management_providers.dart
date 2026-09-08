import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/auth/domain/models/user_role.dart';
import 'package:asli_app/features/user_management/data/user_management_repository.dart';
import 'package:asli_app/features/user_management/domain/models/managed_user.dart';

final managedUsersProvider = FutureProvider.family<List<ManagedUser>, String>(
  (ref, search) => ref.watch(userManagementRepositoryProvider).getUsers(search),
);

final userRoleMutationProvider =
    AsyncNotifierProvider<UserRoleMutationController, void>(
      UserRoleMutationController.new,
    );

final class UserRoleMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> changeRole({
    required String userId,
    required UserRole role,
    required String search,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(userManagementRepositoryProvider).changeRole(userId, role);
      ref.invalidate(managedUsersProvider(search));
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
