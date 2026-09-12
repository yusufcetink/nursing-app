import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';

/// Follow the published module's lesson order, including when replaying a quiz.
/// Completion history must not send the learner back to an earlier lesson.
final quizNextLessonProvider =
    Provider.family<AsyncValue<Lesson?>, LessonSelection>((ref, selection) {
      return ref.watch(educationModuleProvider(selection.moduleId)).whenData((
        module,
      ) {
        final index = module.lessons.indexWhere(
          (lesson) => lesson.id == selection.lessonId,
        );
        if (index < 0 || index + 1 >= module.lessons.length) return null;
        return module.lessons[index + 1];
      });
    });
