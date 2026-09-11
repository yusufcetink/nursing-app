import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManageContent =
        ref.watch(authControllerProvider).value?.canManageContent ?? false;
    final destinations = [
      (branch: 0, label: 'Eğitim', icon: Icons.auto_stories_outlined),
      if (canManageContent)
        (branch: 1, label: 'İçerik', icon: Icons.edit_note_rounded),
      (branch: 2, label: 'Profil', icon: Icons.person_outline_rounded),
    ];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Row(
              children: [
                for (final destination in destinations)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Semantics(
                        selected:
                            navigationShell.currentIndex == destination.branch,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => navigationShell.goBranch(
                            destination.branch,
                            initialLocation:
                                destination.branch ==
                                navigationShell.currentIndex,
                          ),
                          child: AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color:
                                  navigationShell.currentIndex ==
                                      destination.branch
                                  ? scheme.primaryContainer
                                  : Colors.transparent,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  destination.icon,
                                  size: 26,
                                  color:
                                      navigationShell.currentIndex ==
                                          destination.branch
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  destination.label,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color:
                                            navigationShell.currentIndex ==
                                                destination.branch
                                            ? scheme.onPrimaryContainer
                                            : scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
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
}
