import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/education/presentation/widgets/learning_path_step.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';
import 'package:asli_app/shared/widgets/module_cover.dart';
import 'package:asli_app/shared/widgets/learning_progress_display.dart';

class EducationModulePage extends ConsumerWidget {
  const EducationModulePage({required this.moduleId, super.key});
  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
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

class _ModuleContent extends ConsumerWidget {
  const _ModuleContent({required this.module});
  final EducationModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = ref.watch(moduleProgressProvider(module)).clamp(0.0, 1.0);
    final progressState = ref.watch(progressControllerProvider);
    final known = progressState.hasValue && !progressState.hasError;
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ModuleCover(title: module.title, aspectRatio: 1.85),
          ),
          const SizedBox(height: 20),
          Text(
            'MODÜL ${module.order.toString().padLeft(2, '0')}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(module.title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            module.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          LearningSegments(
            value: known ? progress : null,
            total: module.lessonCount,
            label: 'Modül ilerlemesi',
          ),
          const SizedBox(height: 10),
          Text(
            !known
                ? progressState.hasError
                      ? 'İlerleme yüklenemedi'
                      : 'İlerlemen yükleniyor…'
                : '${(progress * module.lessonCount).round()} / ${module.lessonCount} ders tamamlandı',
            style: theme.textTheme.bodyMedium,
          ),
          if (known && module.lessonCount > 0 && progress == 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LearningPill(
                'Rotayı tamamladın!',
                icon: Icons.verified_outlined,
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
              ),
            ),
          if (progressState.hasError)
            TextButton(
              onPressed: () => ref.invalidate(progressControllerProvider),
              child: const Text('Yeniden dene'),
            ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Text('Öğrenme yolculuğun', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),
          if (module.lessons.isEmpty)
            const EmptyContentView(message: 'Bu modüle henüz ders eklenmemiş.'),
          for (final (index, lesson) in module.lessons.indexed)
            LearningPathStep(
              lesson: lesson,
              index: index,
              last: index == module.lessons.length - 1,
              // Existing API has no locked state: every published lesson stays accessible.
              status: !known
                  ? LessonStepStatus.unknown
                  : ref.watch(lessonCompletedProvider(lesson.id))
                  ? LessonStepStatus.completed
                  : lesson.id == nextId
                  ? LessonStepStatus.current
                  : LessonStepStatus.next,
              onOpen: () => openLesson(lesson.id),
            ),
          if (module.lessons.isNotEmpty && nextId == null) ...[
            const SizedBox(height: 16),
            LearningAction(
              label: 'Dersleri yeniden keşfet',
              onPressed: () => openLesson(module.lessons.first.id),
            ),
          ],
        ],
      ),
    );
  }
}
