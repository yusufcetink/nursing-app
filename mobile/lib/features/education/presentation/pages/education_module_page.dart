import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';

class EducationModulePage extends ConsumerWidget {
  const EducationModulePage({required this.moduleId, super.key});
  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(educationModuleProvider(moduleId))
        .when(
          loading: () =>
              Scaffold(appBar: AppBar(), body: const ContentLoadingView()),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = ref.watch(moduleProgressProvider(module));
    final progressState = ref.watch(progressControllerProvider);
    final nextId = ref.watch(nextLessonIdProvider(module));
    void openLesson(String id) => context.pushNamed(
      AppRoutes.lesson,
      pathParameters: {
        AppRoutes.moduleIdParameter: module.id,
        AppRoutes.lessonIdParameter: id,
      },
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Öğrenme rotası')),
      body: LearningBody(
        children: [
          LearningPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: LearningPill(
                    'MODÜL ${module.order.toString().padLeft(2, '0')}',
                    color: scheme.primary.withValues(alpha: .09),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        module.title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: MediaQuery.sizeOf(context).width < 360
                              ? 22
                              : null,
                        ),
                      ),
                    ),
                    if (MediaQuery.sizeOf(context).width >= 380 &&
                        MediaQuery.textScalerOf(context).scale(1) <= 1.2)
                      const LearningArt(size: 100),
                  ],
                ),
                const SizedBox(height: 10),
                Text(module.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Text(
                  '${module.lessonCount} ders',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 22),
                Text(
                  progressState.hasError
                      ? 'İlerleme yüklenemedi'
                      : progressState.isLoading
                      ? 'İlerlemen yükleniyor…'
                      : '${(progress * module.lessonCount).round()} / ${module.lessonCount} ders tamamlandı',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progressState.hasValue ? progress.clamp(0, 1) : null,
                  semanticsLabel: 'Modül ilerlemesi',
                ),
                if (progressState.hasError)
                  TextButton(
                    onPressed: () => ref.invalidate(progressControllerProvider),
                    child: const Text('Yeniden dene'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Adım adım ilerle', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Dersler',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          if (module.lessons.isEmpty)
            const EmptyContentView(message: 'Bu modüle henüz ders eklenmemiş.'),
          for (final (index, lesson) in module.lessons.indexed)
            _LessonStep(
              lesson: lesson,
              index: index,
              current: progressState.hasValue && lesson.id == nextId,
              completed: ref.watch(lessonCompletedProvider(lesson.id)),
              last: index == module.lessons.length - 1,
              onTap: () => openLesson(lesson.id),
            ),
          if (module.lessons.isNotEmpty) ...[
            const SizedBox(height: 18),
            LearningAction(
              label: nextId == null
                  ? 'Dersleri yeniden keşfet'
                  : 'Sıradaki derse başla',
              onPressed: () => openLesson(nextId ?? module.lessons.first.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _LessonStep extends StatelessWidget {
  const _LessonStep({
    required this.lesson,
    required this.index,
    required this.current,
    required this.completed,
    required this.last,
    required this.onTap,
  });
  final Lesson lesson;
  final int index;
  final bool current;
  final bool completed;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = current ? scheme.onInverseSurface : scheme.onSurface;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed
                        ? scheme.tertiaryContainer
                        : current
                        ? scheme.inverseSurface
                        : scheme.primaryContainer,
                  ),
                  child: completed
                      ? Icon(
                          Icons.check_rounded,
                          color: scheme.onTertiaryContainer,
                        )
                      : Text(
                          '${index + 1}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: current
                                ? scheme.onInverseSurface
                                : scheme.onPrimaryContainer,
                          ),
                        ),
                ),
                if (!last)
                  Expanded(
                    child: Center(
                      child: Container(width: 2, color: scheme.outlineVariant),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: current ? scheme.inverseSurface : scheme.surface,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (current) ...[
                          LearningPill(
                            'SIRADAKİ DERS',
                            color: scheme.inversePrimary,
                            foreground: scheme.inverseSurface,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          lesson.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lesson.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: current
                                ? scheme.onInverseSurface.withValues(alpha: .85)
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${lesson.estimatedDurationMinutes} dk',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: foreground,
                                ),
                              ),
                            ),
                            if (completed)
                              Text(
                                'Tamamlandı',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.tertiary,
                                ),
                              ),
                            Icon(
                              current
                                  ? Icons.play_circle_fill_rounded
                                  : Icons.chevron_right_rounded,
                              color: foreground,
                              size: 22,
                            ),
                          ],
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
    );
  }
}
