import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_radius.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/education/presentation/widgets/learning_path_step.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';
import 'package:asli_app/shared/widgets/module_cover.dart';

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
      appBar: AppBar(title: const Text('Aslı App'), centerTitle: true),
      body: LearningBody(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          8,
          AppSpacing.page,
          24,
        ),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: ModuleCover(
              title: module.title,
              aspectRatio: 3.0,
              alignment: Alignment.topCenter,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            module.title,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -.7,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            module.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          if (known && module.lessonCount > 0)
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
              semanticsLabel: 'Modül ilerlemesi',
            ),
          const SizedBox(height: 8),
          Text(
            !known
                ? progressState.hasError
                      ? 'İlerleme yüklenemedi'
                      : 'İlerlemen yükleniyor…'
                : '${(progress * module.lessonCount).round()} / ${module.lessonCount} ders tamamlandı',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.start,
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
          const SizedBox(height: 28),
          Text('Öğrenme yolculuğun', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
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
