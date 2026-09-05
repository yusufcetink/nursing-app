final class Lesson {
  const Lesson({
    required this.id,
    required this.educationModuleId,
    required this.title,
    required this.description,
    required this.estimatedDurationMinutes,
    required this.order,
    required this.sections,
    this.quizId,
  });

  final String id;
  final String educationModuleId;
  final String title;
  final String description;
  final int estimatedDurationMinutes;
  final int order;
  final List<LessonSection> sections;
  final String? quizId;
}

final class LessonSection {
  const LessonSection({required this.title, required this.content});

  final String title;
  final String content;
}
