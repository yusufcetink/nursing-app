import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_radius.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/profile/presentation/providers/profile_overview_provider.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class QuizHistoryPage extends ConsumerWidget {
  const QuizHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(quizHistoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Geçmişi')),
      body: results.when(
        loading: () => const ContentLoadingView(),
        error: (error, _) => ContentErrorView(
          message: networkErrorMessage(error),
          onRetry: () => ref.invalidate(quizHistoryProvider),
        ),
        data: (results) => SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.readingContentWidth,
              ),
              child: results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'Henüz tamamlanan quiz bulunmuyor.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: results.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return Card(
                          child: ListTile(
                            onTap: () => context.pushNamed(
                              AppRoutes.quizResultDetail,
                              pathParameters: {
                                AppRoutes.attemptIdParameter: result.attemptId,
                              },
                            ),
                            leading: Container(
                              width: AppSpacing.section,
                              height: AppSpacing.section,
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.medium,
                                ),
                              ),
                              child: Icon(
                                Icons.fact_check_outlined,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                            title: Text(result.quizTitle),
                            subtitle: Text(
                              '${result.lessonTitle}\n'
                              'Skor: %${result.successPercentage} · '
                              'Doğru: ${result.correctCount} · '
                              'Yanlış: ${result.incorrectCount}',
                            ),
                            isThreeLine: true,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
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
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
