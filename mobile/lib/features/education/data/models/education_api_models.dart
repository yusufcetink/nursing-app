import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';

final class EducationModuleSummaryResponse {
  const EducationModuleSummaryResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.lessonCount,
  });

  factory EducationModuleSummaryResponse.fromJson(Map<String, dynamic> json) {
    return EducationModuleSummaryResponse(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      order: json['order'] as int,
      lessonCount: json['lessonCount'] as int,
    );
  }

  final String id;
  final String title;
  final String description;
  final int order;
  final int lessonCount;

  EducationModule toDomain() => EducationModule(
    id: id,
    title: title,
    description: description,
    order: order,
    lessonCount: lessonCount,
    lessons: const [],
  );
}

final class EducationModuleResponse {
  const EducationModuleResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.lessons,
  });

  factory EducationModuleResponse.fromJson(Map<String, dynamic> json) {
    return EducationModuleResponse(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      order: json['order'] as int,
      lessons: (json['lessons'] as List<dynamic>)
          .map(
            (item) =>
                LessonSummaryResponse.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String title;
  final String description;
  final int order;
  final List<LessonSummaryResponse> lessons;

  EducationModule toDomain() => EducationModule(
    id: id,
    title: title,
    description: description,
    order: order,
    lessonCount: lessons.length,
    lessons: lessons
        .map((lesson) => lesson.toDomain(id))
        .toList(growable: false),
  );
}

final class LessonSummaryResponse {
  const LessonSummaryResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedDurationMinutes,
    required this.order,
  });

  factory LessonSummaryResponse.fromJson(Map<String, dynamic> json) {
    return LessonSummaryResponse(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      estimatedDurationMinutes: json['estimatedDurationMinutes'] as int,
      order: json['order'] as int,
    );
  }

  final String id;
  final String title;
  final String description;
  final int estimatedDurationMinutes;
  final int order;

  Lesson toDomain(String moduleId) => Lesson(
    id: id,
    educationModuleId: moduleId,
    title: title,
    description: description,
    estimatedDurationMinutes: estimatedDurationMinutes,
    order: order,
    sections: const [],
  );
}

final class LessonResponse {
  const LessonResponse({
    required this.id,
    required this.educationModuleId,
    required this.title,
    required this.description,
    required this.content,
    required this.estimatedDurationMinutes,
    required this.order,
    required this.quizId,
  });

  factory LessonResponse.fromJson(Map<String, dynamic> json) {
    return LessonResponse(
      id: json['id'] as String,
      educationModuleId: json['educationModuleId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      content: json['content'] as String,
      estimatedDurationMinutes: json['estimatedDurationMinutes'] as int,
      order: json['order'] as int,
      quizId: json['quizId'] as String?,
    );
  }

  final String id;
  final String educationModuleId;
  final String title;
  final String description;
  final String content;
  final int estimatedDurationMinutes;
  final int order;
  final String? quizId;

  Lesson toDomain() => Lesson(
    id: id,
    educationModuleId: educationModuleId,
    title: title,
    description: description,
    estimatedDurationMinutes: estimatedDurationMinutes,
    order: order,
    sections: content.trim().isEmpty
        ? const []
        : [LessonSection(title: 'Ders İçeriği', content: content)],
    quizId: quizId,
  );
}
