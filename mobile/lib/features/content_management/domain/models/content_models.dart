final class ContentModuleSummary {
  const ContentModuleSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.isPublished,
    required this.lessonCount,
  });

  final String id;
  final String title;
  final String description;
  final int order;
  final bool isPublished;
  final int lessonCount;
}

final class ContentModule {
  const ContentModule({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.isPublished,
    required this.lessons,
  });

  final String id;
  final String title;
  final String description;
  final int order;
  final bool isPublished;
  final List<ContentLessonSummary> lessons;
}

final class ContentLessonSummary {
  const ContentLessonSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedDurationMinutes,
    required this.order,
    required this.isPublished,
  });

  final String id;
  final String title;
  final String description;
  final int estimatedDurationMinutes;
  final int order;
  final bool isPublished;
}

final class ContentLesson {
  const ContentLesson({
    required this.id,
    required this.educationModuleId,
    required this.title,
    required this.description,
    required this.content,
    required this.estimatedDurationMinutes,
    required this.order,
    required this.isPublished,
  });

  final String id;
  final String educationModuleId;
  final String title;
  final String description;
  final String content;
  final int estimatedDurationMinutes;
  final int order;
  final bool isPublished;
}

final class ModuleWriteInput {
  const ModuleWriteInput({
    required this.title,
    required this.description,
    required this.order,
    required this.isPublished,
  });

  final String title;
  final String description;
  final int order;
  final bool isPublished;
}

final class LessonWriteInput {
  const LessonWriteInput({
    required this.title,
    required this.description,
    required this.content,
    required this.estimatedDurationMinutes,
    required this.order,
    required this.isPublished,
  });

  final String title;
  final String description;
  final String content;
  final int estimatedDurationMinutes;
  final int order;
  final bool isPublished;
}
