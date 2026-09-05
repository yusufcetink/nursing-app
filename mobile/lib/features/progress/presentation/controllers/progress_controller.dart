import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/progress/domain/models/progress_state.dart';

final progressControllerProvider =
    AsyncNotifierProvider<ProgressController, ProgressState>(
      ProgressController.new,
    );

final lessonCompletedProvider = Provider.family<bool, String>((ref, lessonId) {
  return ref
          .watch(progressControllerProvider)
          .value
          ?.completedLessonIds
          .contains(lessonId) ??
      false;
});

final moduleProgressProvider = Provider.family<double, EducationModule>((
  ref,
  module,
) {
  if (module.lessonCount == 0) return 0;
  final completedCount =
      ref
          .watch(progressControllerProvider)
          .value
          ?.completedLessons
          .where((lesson) => lesson.educationModuleId == module.id)
          .length ??
      0;
  return completedCount / module.lessonCount;
});

final class ProgressController extends AsyncNotifier<ProgressState> {
  Object? _lastActionError;

  Object? get lastActionError => _lastActionError;

  @override
  Future<ProgressState> build() {
    return ref.watch(progressRepositoryProvider).getProgress();
  }

  Future<bool> completeLesson(String lessonId) async {
    _lastActionError = null;
    final previous = state.value ?? ProgressState.initial();
    try {
      final lesson = await ref
          .read(progressRepositoryProvider)
          .completeLesson(lessonId);
      state = AsyncData(previous.withCompletedLesson(lesson));
      return true;
    } catch (error, stackTrace) {
      _lastActionError = error;
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      ref.read(progressRepositoryProvider).getProgress,
    );
  }

  void reset() {
    _lastActionError = null;
    state = AsyncData(ProgressState.initial());
  }
}
