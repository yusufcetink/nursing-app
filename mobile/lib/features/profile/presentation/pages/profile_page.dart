import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/profile/presentation/providers/profile_overview_provider.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/profile/domain/models/profile_overview.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(profileOverviewProvider)
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Profilim')),
            body: const ContentLoadingView(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: const Text('Profilim')),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activity = ref.watch(learningActivityProvider).value;
    return Scaffold(
      body: LearningBody(
        children: [
          const BrandWordmark(),
          const SizedBox(height: 12),
          Text('Profilim', style: theme.textTheme.displaySmall),
          const SizedBox(height: 20),
          LearningPanel(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  child: Text(
                    overview.user.initials,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overview.user.fullName,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        overview.user.email,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Her adımın değerli.', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Kendi yolunda, kendi ritminde.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LearningStat(
                  value: '${overview.completedLessonCount}',
                  label: 'Tamamlanan ders',
                ),
              ),
              Expanded(
                child: LearningStat(
                  value: '${overview.completedQuizCount}',
                  label: 'Tamamlanan quiz',
                ),
              ),
              Expanded(
                child: LearningStat(
                  value: overview.averageSuccessPercentage == null
                      ? '—'
                      : '%${overview.averageSuccessPercentage}',
                  label: 'Ortalama başarı',
                ),
              ),
            ],
          ),
          if (activity != null) ...[
            const SizedBox(height: 24),
            LearningPanel(
              color: scheme.surface,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bu haftaki ritmin', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${activity.activeDays} gün öğrendin',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (final (i, day) in const [
                        'Pzt',
                        'Sal',
                        'Çar',
                        'Per',
                        'Cum',
                        'Cmt',
                        'Paz',
                      ].indexed)
                        Expanded(
                          child: Semantics(
                            label:
                                '$day: ${activity.weekDays[i] ? 'Ders tamamlandı' : 'Tamamlanan ders yok'}',
                            excludeSemantics: true,
                            child: Column(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: activity.weekDays[i]
                                        ? scheme.tertiaryContainer
                                        : scheme.surface,
                                    border: Border.all(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                  child: activity.weekDays[i]
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: scheme.onTertiaryContainer,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(day, style: theme.textTheme.labelSmall),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          Text('Küçük başarıların', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final badge in LearningBadge.values)
                Expanded(
                  child: _Badge(
                    badge: badge,
                    earned: overview.earnedBadges.contains(badge),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quiz Sonuçları',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => context.pushNamed(AppRoutes.quizHistory),
                child: const Text('Tümünü Gör'),
              ),
            ],
          ),
          if (overview.quizResults.isEmpty)
            LearningPanel(
              color: scheme.surface,
              padding: const EdgeInsets.all(20),
              child: Text(
                'Henüz tamamlanan quiz bulunmuyor.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            for (final result in overview.quizResults.take(3))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                leading: Icon(Icons.history_rounded, color: scheme.primary),
                title: Text(result.quizTitle),
                subtitle: Text(
                  '${result.lessonTitle}\nDoğru: ${result.correctCount} · Yanlış: ${result.incorrectCount}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.pushNamed(
                  AppRoutes.quizResultDetail,
                  pathParameters: {
                    AppRoutes.attemptIdParameter: result.attemptId,
                  },
                ),
              ),
          const SizedBox(height: 20),
          const Divider(),
          if (overview.user.role.canAccessAdministration)
            ListTile(
              key: const Key('user_management_link'),
              onTap: () => context.pushNamed(AppRoutes.userManagement),
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Kullanıcı Yönetimi'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              final loggedOut = await ref
                  .read(authControllerProvider.notifier)
                  .logout();
              if (!context.mounted) return;
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
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.badge, required this.earned});
  final LearningBadge badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (title, requirement, icon, color) = switch (badge) {
      LearningBadge.firstLesson => (
        'İlk adım',
        '1 ders tamamla',
        Icons.auto_stories_outlined,
        scheme.primaryContainer,
      ),
      LearningBadge.fiveLessons => (
        'Meraklı zihin',
        '5 ders tamamla',
        Icons.auto_awesome_rounded,
        scheme.secondaryContainer,
      ),
      LearningBadge.firstQuiz => (
        'İlk keşif',
        '1 quiz tamamla',
        Icons.workspace_premium_outlined,
        scheme.tertiaryContainer,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        label: '$title. ${earned ? 'Kazanıldı' : requirement}',
        excludeSemantics: true,
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: earned ? color : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: earned && badge != LearningBadge.fiveLessons
                  ? LearningArt(
                      artwork: badge == LearningBadge.firstLesson
                          ? LearningArtwork.book
                          : LearningArtwork.medal,
                      size: 78,
                    )
                  : Icon(
                      icon,
                      size: 36,
                      color: earned
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
            ),
            const SizedBox(height: 9),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 3),
            Text(
              earned ? 'Kazanıldı' : requirement,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
