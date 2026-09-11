import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';

final recommendedModuleProvider = Provider<EducationModule?>((ref) {
  final modules = ref.watch(educationModulesProvider).value ?? const [];
  final progress = ref.watch(progressControllerProvider).value;
  if (modules.isEmpty) return null;
  EducationModule? firstAvailable;
  for (final module in modules) {
    if (module.lessonCount == 0) continue;
    final completed =
        progress?.completedLessons
            .where((lesson) => lesson.educationModuleId == module.id)
            .length ??
        0;
    if (completed > 0 && completed < module.lessonCount) return module;
    if (completed < module.lessonCount) firstAvailable ??= module;
  }
  return firstAvailable ?? modules.first;
});
