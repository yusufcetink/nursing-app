import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';

/// A read-only snapshot for the completion UI; never writes progress or locks lessons.
final lessonCompletionProvider = Provider.family<LessonCompletion?, String>((
  ref,
  moduleId,
) {
  final module = ref.watch(educationModuleProvider(moduleId)).value;
  final progress = ref.watch(progressControllerProvider);
  if (module == null || !progress.hasValue || progress.hasError) return null;
  final completedIds = progress.requireValue.completedLessonIds;
  final completed = module.lessons
      .where((lesson) => completedIds.contains(lesson.id))
      .length;
  final nextId = ref.watch(nextLessonIdProvider(module));
  return LessonCompletion(
    module: module,
    completed: completed,
    nextLesson: module.lessons
        .where((lesson) => lesson.id == nextId)
        .firstOrNull,
  );
});

final class LessonCompletion {
  const LessonCompletion({
    required this.module,
    required this.completed,
    required this.nextLesson,
  });
  final EducationModule module;
  final int completed;
  final Lesson? nextLesson;
  bool get moduleCompleted =>
      module.lessonCount > 0 && completed >= module.lessonCount;
}
