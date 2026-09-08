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

final class ContentQuiz {
  const ContentQuiz({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.isPublished,
    required this.questions,
  });

  final String id;
  final String lessonId;
  final String title;
  final bool isPublished;
  final List<ContentQuizQuestion> questions;
}

final class ContentQuizQuestion {
  const ContentQuizQuestion({
    required this.id,
    required this.prompt,
    required this.order,
    required this.options,
  });

  final String id;
  final String prompt;
  final int order;
  final List<ContentQuizOption> options;
}

final class ContentQuizOption {
  const ContentQuizOption({
    required this.id,
    required this.text,
    required this.isCorrect,
    required this.order,
  });

  final String id;
  final String text;
  final bool isCorrect;
  final int order;
}

final class QuizWriteInput {
  const QuizWriteInput({required this.title, required this.isPublished});

  final String title;
  final bool isPublished;
}

final class QuizQuestionWriteInput {
  const QuizQuestionWriteInput({required this.prompt, required this.order});

  final String prompt;
  final int order;
}

final class QuizOptionWriteInput {
  const QuizOptionWriteInput({
    required this.text,
    required this.isCorrect,
    required this.order,
  });

  final String text;
  final bool isCorrect;
  final int order;
}

final class ContentLesson {
  const ContentLesson({
    required this.id,
    required this.educationModuleId,
    required this.title,
    required this.description,
    required this.estimatedDurationMinutes,
    required this.order,
    required this.isPublished,
    required this.quizId,
    this.blocks = const [],
  });

  final String id;
  final String educationModuleId;
  final String title;
  final String description;
  final int estimatedDurationMinutes;
  final int order;
  final bool isPublished;
  final String? quizId;
  final List<ContentLessonContentBlock> blocks;
}

final class ContentLessonContentBlock {
  const ContentLessonContentBlock({
    required this.id,
    required this.lessonId,
    required this.blockType,
    required this.sortOrder,
    this.textContent,
    this.media,
  });

  final String id;
  final String lessonId;
  final ContentBlockType blockType;
  final String? textContent;
  final ContentLessonMedia? media;
  final int sortOrder;
}

enum ContentBlockType { heading, text, image, video }

final class ContentBlockWriteInput {
  const ContentBlockWriteInput({
    required this.blockType,
    required this.sortOrder,
    this.textContent,
    this.mediaId,
  });

  final ContentBlockType blockType;
  final String? textContent;
  final String? mediaId;
  final int sortOrder;
}

final class ContentLessonMedia {
  const ContentLessonMedia({
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
  final ContentLessonMediaType mediaType;
  final int sizeBytes;
  final int sortOrder;
}

enum ContentLessonMediaType { image, video }

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
    required this.estimatedDurationMinutes,
    required this.order,
    required this.isPublished,
  });

  final String title;
  final String description;
  final int estimatedDurationMinutes;
  final int order;
  final bool isPublished;
}
