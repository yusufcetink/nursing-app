import 'package:asli_app/features/content_management/domain/models/content_models.dart';

final class ContentModuleSummaryResponse {
  const ContentModuleSummaryResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.isPublished,
    required this.lessonCount,
  });

  factory ContentModuleSummaryResponse.fromJson(Map<String, dynamic> json) =>
      ContentModuleSummaryResponse(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        order: json['order'] as int,
        isPublished: json['isPublished'] as bool,
        lessonCount: json['lessonCount'] as int,
      );

  final String id;
  final String title;
  final String description;
  final int order;
  final bool isPublished;
  final int lessonCount;

  ContentModuleSummary toDomain() => ContentModuleSummary(
    id: id,
    title: title,
    description: description,
    order: order,
    isPublished: isPublished,
    lessonCount: lessonCount,
  );
}

final class ContentModuleResponse {
  const ContentModuleResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.isPublished,
    required this.lessons,
  });

  factory ContentModuleResponse.fromJson(Map<String, dynamic> json) =>
      ContentModuleResponse(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        order: json['order'] as int,
        isPublished: json['isPublished'] as bool,
        lessons: (json['lessons'] as List<dynamic>)
            .map(
              (item) => ContentLessonSummaryResponse.fromJson(
                item as Map<String, dynamic>,
              ).toDomain(),
            )
            .toList(growable: false),
      );

  final String id;
  final String title;
  final String description;
  final int order;
  final bool isPublished;
  final List<ContentLessonSummary> lessons;

  ContentModule toDomain() => ContentModule(
    id: id,
    title: title,
    description: description,
    order: order,
    isPublished: isPublished,
    lessons: lessons,
  );
}

final class ContentLessonSummaryResponse {
  const ContentLessonSummaryResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedDurationMinutes,
    required this.order,
    required this.isPublished,
  });

  factory ContentLessonSummaryResponse.fromJson(Map<String, dynamic> json) =>
      ContentLessonSummaryResponse(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        estimatedDurationMinutes: json['estimatedDurationMinutes'] as int,
        order: json['order'] as int,
        isPublished: json['isPublished'] as bool,
      );

  final String id;
  final String title;
  final String description;
  final int estimatedDurationMinutes;
  final int order;
  final bool isPublished;

  ContentLessonSummary toDomain() => ContentLessonSummary(
    id: id,
    title: title,
    description: description,
    estimatedDurationMinutes: estimatedDurationMinutes,
    order: order,
    isPublished: isPublished,
  );
}

final class ContentLessonResponse {
  const ContentLessonResponse({
    required this.id,
    required this.educationModuleId,
    required this.title,
    required this.description,
    required this.content,
    required this.estimatedDurationMinutes,
    required this.order,
    required this.isPublished,
  });

  factory ContentLessonResponse.fromJson(Map<String, dynamic> json) =>
      ContentLessonResponse(
        id: json['id'] as String,
        educationModuleId: json['educationModuleId'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        content: json['content'] as String,
        estimatedDurationMinutes: json['estimatedDurationMinutes'] as int,
        order: json['order'] as int,
        isPublished: json['isPublished'] as bool,
      );

  final String id;
  final String educationModuleId;
  final String title;
  final String description;
  final String content;
  final int estimatedDurationMinutes;
  final int order;
  final bool isPublished;

  ContentLesson toDomain() => ContentLesson(
    id: id,
    educationModuleId: educationModuleId,
    title: title,
    description: description,
    content: content,
    estimatedDurationMinutes: estimatedDurationMinutes,
    order: order,
    isPublished: isPublished,
  );
}
