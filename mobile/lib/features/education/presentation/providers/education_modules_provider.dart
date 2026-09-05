import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';

typedef LessonSelection = ({String moduleId, String lessonId});

final educationModulesProvider = FutureProvider<List<EducationModule>>(
  (ref) => ref.watch(educationRepositoryProvider).getModules(),
);

final educationModuleProvider = FutureProvider.family<EducationModule, String>(
  (ref, moduleId) => ref.watch(educationRepositoryProvider).getModule(moduleId),
);

final lessonProvider = FutureProvider.family<Lesson, LessonSelection>(
  (ref, selection) =>
      ref.watch(educationRepositoryProvider).getLesson(selection.lessonId),
);
