import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/auth/domain/models/user_role.dart';
import 'package:asli_app/features/user_management/data/user_management_repository.dart';
import 'package:asli_app/features/user_management/domain/models/managed_user.dart';
import 'package:asli_app/features/user_management/presentation/providers/user_management_providers.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(managedUsersProvider(_search));
    final mutation = ref.watch(userRoleMutationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı Yönetimi')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.readingContentWidth,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TextField(
                    key: const Key('user_search_field'),
                    controller: _searchController,
                    onChanged: _searchChanged,
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı ara',
                      hintText: 'Ad veya email',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                if (mutation.isLoading)
                  const LinearProgressIndicator(
                    key: Key('role_change_loading'),
                  ),
                Expanded(
                  child: users.when(
                    loading: () => const ContentLoadingView(),
                    error: (error, _) => ContentErrorView(
                      message: networkErrorMessage(error),
                      onRetry: () =>
                          ref.invalidate(managedUsersProvider(_search)),
                    ),
                    data: (items) => items.isEmpty
                        ? const Center(child: Text('Kullanıcı bulunamadı.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.lg,
                            ),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) => _UserCard(
                              user: items[index],
                              enabled: !mutation.isLoading,
                              onRoleChanged: (role) =>
                                  _changeRole(items[index], role),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeRole(ManagedUser user, UserRole role) async {
    final changed = await ref
        .read(userRoleMutationProvider.notifier)
        .changeRole(userId: user.id, role: role, search: _search);
    if (!mounted) return;
    final message = changed
        ? '${user.fullName} rolü ${role.displayName} olarak güncellendi.'
        : networkErrorMessage(ref.read(userRoleMutationProvider).error!);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.enabled,
    required this.onRoleChanged,
  });

  final ManagedUser user;
  final bool enabled;
  final ValueChanged<UserRole> onRoleChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.fullName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(user.email),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<UserRole>(
            key: Key('role_${user.id}'),
            initialValue: user.role,
            decoration: const InputDecoration(labelText: 'Rol'),
            items: UserRole.values
                .map(
                  (role) => DropdownMenuItem(
                    value: role,
                    child: Text(role.displayName),
                  ),
                )
                .toList(growable: false),
            onChanged: enabled
                ? (role) {
                    if (role != null && role != user.role) onRoleChanged(role);
                  }
                : null,
          ),
        ],
      ),
    ),
  );
}
