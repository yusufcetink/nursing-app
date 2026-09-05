import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_radius.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class LessonPage extends ConsumerWidget {
  const LessonPage({required this.moduleId, required this.lessonId, super.key});

  final String moduleId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync = ref.watch(
      lessonProvider((moduleId: moduleId, lessonId: lessonId)),
    );
    return lessonAsync.when(
      loading: () => const Scaffold(body: ContentLoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ContentErrorView(
          message: networkErrorMessage(error),
          onRetry: () => ref.invalidate(
            lessonProvider((moduleId: moduleId, lessonId: lessonId)),
          ),
        ),
      ),
      data: (lesson) => _LessonContent(moduleId: moduleId, lesson: lesson),
    );
  }
}

class _LessonContent extends ConsumerWidget {
  const _LessonContent({required this.moduleId, required this.lesson});

  final String moduleId;
  final Lesson lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonId = lesson.id;
    final isCompleted = ref.watch(lessonCompletedProvider(lessonId));

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
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
                  color: colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          lesson.description,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 20,
                              color: colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Tahmini süre: ${lesson.estimatedDurationMinutes} dakika',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colorScheme.onTertiaryContainer,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final (index, section) in lesson.sections.indexed) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            section.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            section.content,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isCompleted && lesson.quizId == null
                        ? null
                        : () async {
                            if (isCompleted) {
                              context.pushNamed(
                                AppRoutes.quiz,
                                pathParameters: {
                                  AppRoutes.moduleIdParameter: moduleId,
                                  AppRoutes.lessonIdParameter: lessonId,
                                },
                              );
                              return;
                            }
                            final completed = await ref
                                .read(progressControllerProvider.notifier)
                                .completeLesson(lessonId);
                            if (!completed && context.mounted) {
                              final error = ref
                                  .read(progressControllerProvider.notifier)
                                  .lastActionError;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(networkErrorMessage(error!)),
                                ),
                              );
                            }
                          },
                    icon: Icon(
                      isCompleted && lesson.quizId != null
                          ? Icons.quiz_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
                    label: Text(
                      !isCompleted
                          ? 'Dersi Tamamla'
                          : lesson.quizId == null
                          ? 'Bu ders için quiz bulunmuyor'
                          : "Quiz'e Geç",
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
