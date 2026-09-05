final class CompletedLesson {
  const CompletedLesson({
    required this.lessonId,
    required this.educationModuleId,
    required this.completedAtUtc,
  });

  final String lessonId;
  final String educationModuleId;
  final DateTime completedAtUtc;
}

final class ProgressState {
  ProgressState({required List<CompletedLesson> completedLessons})
    : completedLessons = List.unmodifiable(completedLessons),
      completedLessonIds = Set.unmodifiable(
        completedLessons.map((lesson) => lesson.lessonId),
      );

  factory ProgressState.initial() => ProgressState(completedLessons: const []);

  final List<CompletedLesson> completedLessons;
  final Set<String> completedLessonIds;

  ProgressState withCompletedLesson(CompletedLesson lesson) {
    final existingIndex = completedLessons.indexWhere(
      (candidate) => candidate.lessonId == lesson.lessonId,
    );
    if (existingIndex == -1) {
      return ProgressState(completedLessons: [...completedLessons, lesson]);
    }
    final updated = [...completedLessons]..[existingIndex] = lesson;
    return ProgressState(completedLessons: updated);
  }
}
