import 'package:asli_app/features/progress/domain/models/progress_state.dart';

final class ProgressResponse {
  const ProgressResponse(this.completedLessons);

  factory ProgressResponse.fromJson(Map<String, dynamic> json) {
    return ProgressResponse(
      (json['completedLessons'] as List<dynamic>)
          .map(
            (item) =>
                CompletedLessonResponse.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final List<CompletedLessonResponse> completedLessons;

  ProgressState toDomain() => ProgressState(
    completedLessons: completedLessons
        .map((lesson) => lesson.toDomain())
        .toList(growable: false),
  );
}

final class CompletedLessonResponse {
  const CompletedLessonResponse({
    required this.lessonId,
    required this.educationModuleId,
    required this.completedAtUtc,
  });

  factory CompletedLessonResponse.fromJson(Map<String, dynamic> json) {
    return CompletedLessonResponse(
      lessonId: json['lessonId'] as String,
      educationModuleId: json['educationModuleId'] as String,
      completedAtUtc: DateTime.parse(json['completedAtUtc'] as String),
    );
  }

  final String lessonId;
  final String educationModuleId;
  final DateTime completedAtUtc;

  CompletedLesson toDomain() => CompletedLesson(
    lessonId: lessonId,
    educationModuleId: educationModuleId,
    completedAtUtc: completedAtUtc,
  );
}
