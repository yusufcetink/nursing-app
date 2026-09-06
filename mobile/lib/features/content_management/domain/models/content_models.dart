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
    required this.content,
    required this.estimatedDurationMinutes,
    required this.order,
    required this.isPublished,
    required this.quizId,
  });

  final String id;
  final String educationModuleId;
  final String title;
  final String description;
  final String content;
  final int estimatedDurationMinutes;
  final int order;
  final bool isPublished;
  final String? quizId;
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
