import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/app/theme/app_radius.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/profile/presentation/providers/profile_overview_provider.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/profile/domain/models/profile_overview.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class QuizResultDetailPage extends ConsumerWidget {
  const QuizResultDetailPage({required this.attemptId, super.key});

  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(profileQuizResultProvider(attemptId));
    return result.when(
      loading: () => const Scaffold(body: ContentLoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Quiz Sonuç Detayı')),
        body: ContentErrorView(
          message: networkErrorMessage(error),
          onRetry: () => ref.invalidate(profileQuizResultProvider(attemptId)),
        ),
      ),
      data: (result) => _QuizResultDetailContent(result: result),
    );
  }
}

class _QuizResultDetailContent extends StatelessWidget {
  const _QuizResultDetailContent({required this.result});

  final ProfileQuizResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Sonuç Detayı')),
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
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 112,
                              height: 112,
                              child: CircularProgressIndicator(
                                value: result.successPercentage / 100,
                                strokeWidth: AppSpacing.xs,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.18),
                              ),
                            ),
                            Text(
                              '%${result.successPercentage}',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          result.quizTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          result.lessonTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _ResultMetric(
                  label: 'Başarı Yüzdesi',
                  value: '%${result.successPercentage}',
                  icon: Icons.insights_rounded,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ResultMetric(
                  label: 'Toplam Soru',
                  value: '${result.totalQuestionCount}',
                  icon: Icons.quiz_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ResultMetric(
                  label: 'Doğru',
                  value: '${result.correctCount}',
                  icon: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ResultMetric(
                  label: 'Yanlış',
                  value: '${result.incorrectCount}',
                  icon: Icons.cancel_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: AppSpacing.section,
          height: AppSpacing.section,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}
