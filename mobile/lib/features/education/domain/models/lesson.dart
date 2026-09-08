final class Lesson {
  const Lesson({
    required this.id,
    required this.educationModuleId,
    required this.title,
    required this.description,
    required this.estimatedDurationMinutes,
    required this.order,
    required this.blocks,
    this.quizId,
  });

  final String id;
  final String educationModuleId;
  final String title;
  final String description;
  final int estimatedDurationMinutes;
  final int order;
  final List<LessonContentBlock> blocks;
  final String? quizId;
}

final class LessonContentBlock {
  const LessonContentBlock({
    required this.id,
    required this.lessonId,
    required this.blockType,
    required this.sortOrder,
    this.textContent,
    this.media,
  });

  final String id;
  final String lessonId;
  final LessonContentBlockType blockType;
  final String? textContent;
  final LessonMedia? media;
  final int sortOrder;
}

enum LessonContentBlockType { heading, text, image, video }

final class LessonMedia {
  const LessonMedia({
    required this.id,
    required this.lessonId,
    required this.originalFileName,
    required this.contentType,
    required this.mediaType,
    required this.sizeBytes,
    required this.sortOrder,
  });

  final String id;
  final String lessonId;
  final String originalFileName;
  final String contentType;
  final LessonMediaType mediaType;
  final int sizeBytes;
  final int sortOrder;
}

enum LessonMediaType { image, video }
