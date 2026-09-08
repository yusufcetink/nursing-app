import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_radius.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/profile/presentation/providers/profile_overview_provider.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/profile/domain/models/profile_overview.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(profileOverviewProvider);
    return overview.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const ContentLoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: ContentErrorView(
          message: networkErrorMessage(error),
          onRetry: () {
            ref
              ..invalidate(progressControllerProvider)
              ..invalidate(quizHistoryProvider)
              ..invalidate(profileOverviewProvider);
          },
        ),
      ),
      data: (overview) => _ProfileContent(overview: overview),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.overview});

  final ProfileOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.readingContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.section,
              ),
              children: [
                Card(
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: AppSpacing.xl,
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          child: Text(
                            '${overview.user.firstName[0]}${overview.user.lastName[0]}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: colorScheme.onPrimary),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                overview.user.fullName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                overview.user.email,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _ProgressStatCard(
                        icon: Icons.menu_book_outlined,
                        value: overview.completedLessonCount,
                        label: 'Tamamlanan Ders',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _ProgressStatCard(
                        icon: Icons.fact_check_outlined,
                        value: overview.completedQuizCount,
                        label: 'Tamamlanan Quiz',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quiz Sonuçları',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.pushNamed(AppRoutes.quizHistory),
                      child: const Text('Tümünü Gör'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (overview.quizResults.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            size: AppSpacing.xl,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Henüz tamamlanan quiz bulunmuyor.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  for (final result in overview.quizResults.take(3)) ...[
                    Card(
                      child: ListTile(
                        onTap: () => context.pushNamed(
                          AppRoutes.quizResultDetail,
                          pathParameters: {
                            AppRoutes.attemptIdParameter: result.attemptId,
                          },
                        ),
                        leading: const Icon(Icons.fact_check_outlined),
                        title: Text(result.quizTitle),
                        subtitle: Text(
                          '${result.lessonTitle}\n'
                          'Doğru: ${result.correctCount} · Yanlış: ${result.incorrectCount}',
                        ),
                        isThreeLine: true,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '%${result.successPercentage}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                const SizedBox(height: AppSpacing.xl),
                if (overview.user.role.canAccessAdministration) ...[
                  Card(
                    child: ListTile(
                      key: const Key('user_management_link'),
                      onTap: () => context.pushNamed(AppRoutes.userManagement),
                      leading: const Icon(Icons.manage_accounts_outlined),
                      title: const Text('Kullanıcı Yönetimi'),
                      subtitle: const Text(
                        'Kullanıcıları arayın ve uygulama rollerini yönetin.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                OutlinedButton.icon(
                  onPressed: () async {
                    final loggedOut = await ref
                        .read(authControllerProvider.notifier)
                        .logout();
                    if (!context.mounted) {
                      return;
                    }
                    if (!loggedOut) {
                      final error = ref
                          .read(authControllerProvider.notifier)
                          .lastActionError;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(authErrorMessage(error))),
                      );
                      return;
                    }
                    ref.read(progressControllerProvider.notifier).reset();
                    context.goNamed(AppRoutes.login);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Çıkış Yap'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressStatCard extends StatelessWidget {
  const _ProgressStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Container(
              width: AppSpacing.section,
              height: AppSpacing.section,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(icon, color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('$value', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
