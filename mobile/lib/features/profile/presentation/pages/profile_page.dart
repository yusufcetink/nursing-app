import 'package:asli_app/features/leaderboard/presentation/leaderboard_page.dart';
import 'package:asli_app/features/auth/domain/models/user_role.dart';
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
import 'package:asli_app/shared/widgets/learning_progress_display.dart';
import 'package:asli_app/app/theme/theme_mode_controller.dart';

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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(
            'Aslı App',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Profilim',
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 8),
          _ProfileHero(overview: overview),
          const SizedBox(height: 24),
          const SizedBox(height: 26),
          Text('Her adımın değerli.', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Kendi yolunda, kendi ritminde.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _ProfileProgress(overview: overview),
          if (activity != null) ...[
            const SizedBox(height: 24),
            _ProfileSurface(
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
                                        ? scheme.primary
                                        : scheme.surfaceContainerHighest,
                                    border: Border.all(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                  child: activity.weekDays[i]
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: scheme.onPrimary,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  day,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall,
                                ),
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
          if (overview.user.role == UserRole.student)
            const LeaderboardSection(embedded: true),
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
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: .45),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: MediaQuery.textScalerOf(context).scale(1) > 1.4
                        ? null
                        : CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            foregroundColor: scheme.onPrimaryContainer,
                            child: const Icon(Icons.history_rounded),
                          ),
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
                ),
              ),
          const SizedBox(height: 20),
          _ProfileSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Görünüm', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Sana en iyi gelen görünümü seç.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                _ThemeModeSelector(
                  mode: ref.watch(themeModeControllerProvider),
                  onChanged: (mode) => ref
                      .read(themeModeControllerProvider.notifier)
                      .setThemeMode(mode),
                ),
              ],
            ),
          ),
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.overview});
  final ProfileOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final avatar = Container(
      width: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 88 : 64,
      height: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 88 : 64,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          overview.user.initials,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overview.user.fullName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          overview.user.email,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return MediaQuery.textScalerOf(context).scale(1) > 1.4
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [avatar, const SizedBox(height: 16), identity],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: identity),
              const SizedBox(width: 16),
              avatar,
            ],
          );
  }
}

class _ProfileSurface extends StatelessWidget {
  const _ProfileSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
      ),
      child: child,
    );
  }
}

class _ProfileProgress extends StatelessWidget {
  const _ProfileProgress({required this.overview});
  final ProfileOverview overview;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    Widget statistic(String value, String label) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.displaySmall),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
    return _ProfileSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (largeText) ...[
            statistic('${overview.completedLessonCount}', 'Tamamlanan ders'),
            const SizedBox(height: 16),
            statistic('${overview.completedQuizCount}', 'Tamamlanan quiz'),
          ] else
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: statistic(
                      '${overview.completedLessonCount}',
                      'Tamamlanan ders',
                    ),
                  ),
                  const VerticalDivider(width: 28),
                  Expanded(
                    child: statistic(
                      '${overview.completedQuizCount}',
                      'Tamamlanan quiz',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text('Ortalama başarı', style: theme.textTheme.titleMedium),
              Text(
                overview.averageSuccessPercentage == null
                    ? '—'
                    : '%${overview.averageSuccessPercentage}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LearningSegments(
            value: overview.averageSuccessPercentage == null
                ? null
                : overview.averageSuccessPercentage! / 100,
            total: 10,
            label: 'Ortalama quiz başarısı',
          ),
        ],
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Görünüm tercihi',
      child: SegmentedButton<ThemeMode>(
        key: const Key('theme_mode_selector'),
        showSelectedIcon: false,
        expandedInsets: MediaQuery.textScalerOf(context).scale(1) > 1.4
            ? null
            : EdgeInsets.zero,
        direction: MediaQuery.textScalerOf(context).scale(1) > 1.4
            ? Axis.vertical
            : Axis.horizontal,
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
          ButtonSegment(value: ThemeMode.light, label: Text('Açık')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Koyu')),
        ],
        selected: {mode},
        onSelectionChanged: (selection) => onChanged(selection.single),
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          ),
          iconSize: const WidgetStatePropertyAll(18),
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
