import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_radius.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class EducationModulePage extends ConsumerWidget {
  const EducationModulePage({required this.moduleId, super.key});

  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moduleAsync = ref.watch(educationModuleProvider(moduleId));

    return moduleAsync.when(
      loading: () => const Scaffold(body: ContentLoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ContentErrorView(
          message: networkErrorMessage(error),
          onRetry: () => ref.invalidate(educationModuleProvider(moduleId)),
        ),
      ),
      data: (module) => _ModuleContent(module: module),
    );
  }
}

class _ModuleContent extends ConsumerWidget {
  const _ModuleContent({required this.module});

  final EducationModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(moduleProgressProvider(module));
    final completedLessonCount = (progress * module.lessonCount).round();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(module.title)),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_stories_rounded,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          module.description,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colorScheme.onPrimaryContainer),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$completedLessonCount / ${module.lessonCount} ders tamamlandı',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                              ),
                            ),
                            Text(
                              '%${(progress * 100).round()}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        LinearProgressIndicator(
                          value: progress,
                          color: colorScheme.onPrimaryContainer,
                          backgroundColor: colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Dersler',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final (index, lesson) in module.lessons.indexed) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _LessonCard(
                      moduleId: module.id,
                      lesson: lesson,
                      index: index,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends ConsumerWidget {
  const _LessonCard({
    required this.moduleId,
    required this.lesson,
    required this.index,
  });

  final String moduleId;
  final Lesson lesson;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = ref.watch(lessonCompletedProvider(lesson.id));
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: isCompleted ? colorScheme.secondaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.large),
        onTap: () => context.pushNamed(
          AppRoutes.lesson,
          pathParameters: {
            AppRoutes.moduleIdParameter: moduleId,
            AppRoutes.lessonIdParameter: lesson.id,
          },
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isCompleted
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                foregroundColor: isCompleted
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                child: isCompleted
                    ? const Icon(Icons.check_rounded)
                    : Text('${index + 1}'),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      lesson.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isCompleted
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Tamamlandı',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colorScheme.primary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
