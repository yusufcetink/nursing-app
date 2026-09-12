import 'package:asli_app/features/content_management/data/content_management_repository.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';

final class FakeContentManagementRepository
    implements ContentManagementRepository {
  int createModuleCallCount = 0;
  int updateModuleCallCount = 0;
  int createLessonCallCount = 0;
  int updateLessonCallCount = 0;
  int createQuestionCallCount = 0;
  int createOptionCallCount = 0;
  int correctOptionCount = 0;
  int deleteModuleCallCount = 0;
  int deleteLessonCallCount = 0;
  int deleteQuizCallCount = 0;
  int deleteQuestionCallCount = 0;
  int uploadLessonMediaCallCount = 0;
  int deleteLessonMediaCallCount = 0;
  int createContentBlockCallCount = 0;
  Object? mutationError;

  final modules = <ContentModuleSummary>[
    const ContentModuleSummary(
      id: 'draft-module',
      title: 'Taslak Modül',
      description: 'Yönetim açıklaması',
      order: 1,
      isPublished: false,
      lessonCount: 1,
    ),
  ];

  @override
  Future<String> createModule(ModuleWriteInput input) async {
    if (mutationError case final error?) throw error;
    createModuleCallCount++;
    modules.add(
      ContentModuleSummary(
        id: 'created-module',
        title: input.title,
        description: input.description,
        order: input.order,
        isPublished: input.isPublished,
        lessonCount: 0,
      ),
    );
    return 'created-module';
  }

  @override
  Future<String> createLesson(String moduleId, LessonWriteInput input) async {
    createLessonCallCount++;
    return 'created-lesson';
  }

  @override
  Future<void> deleteModule(String id) async {
    deleteModuleCallCount++;
    modules.removeWhere((module) => module.id == id);
  }

  @override
  Future<void> deleteLesson(String id) async {
    deleteLessonCallCount++;
  }

  @override
  Future<void> deleteQuiz(String id) async {
    deleteQuizCallCount++;
  }

  @override
  Future<void> deleteQuestion(String id) async {
    deleteQuestionCallCount++;
  }

  @override
  Future<ContentLessonMedia> uploadLessonMedia({
    required String lessonId,
    required String filePath,
    required String fileName,
    required int sortOrder,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    uploadLessonMediaCallCount++;
    onSendProgress?.call(1, 1);
    return ContentLessonMedia(
      id: 'video-id',
      lessonId: lessonId,
      originalFileName: fileName,
      contentType: 'video/mp4',
      mediaType: ContentLessonMediaType.video,
      sizeBytes: 1,
      sortOrder: sortOrder,
    );
  }

  @override
  Future<void> deleteLessonMedia(String lessonId, String mediaId) async {
    deleteLessonMediaCallCount++;
  }

  @override
  Future<String> createContentBlock(
    String lessonId,
    ContentBlockWriteInput input,
  ) async {
    createContentBlockCallCount++;
    return 'block-id';
  }

  @override
  Future<void> updateContentBlock(
    String id,
    ContentBlockWriteInput input,
  ) async {}

  @override
  Future<void> deleteContentBlock(String id) async {}

  @override
  Future<void> reorderContentBlocks(
    String lessonId,
    List<({String blockId, int sortOrder})> blocks,
  ) async {}

  @override
  Future<ContentLesson> getLesson(String id) async => const ContentLesson(
    id: 'draft-lesson',
    educationModuleId: 'draft-module',
    title: 'Taslak Ders',
    description: 'Ders açıklaması',
    estimatedDurationMinutes: 5,
    order: 1,
    isPublished: false,
    quizId: 'quiz-id',
    blocks: [
      ContentLessonContentBlock(
        id: 'text-block-id',
        lessonId: 'draft-lesson',
        blockType: ContentBlockType.text,
        textContent: 'Düzenlenecek metin',
        sortOrder: 0,
      ),
    ],
  );

  @override
  Future<ContentQuiz?> getQuizForLesson(String lessonId) async =>
      const ContentQuiz(
        id: 'quiz-id',
        lessonId: 'draft-lesson',
        title: 'Taslak Quiz',
        isPublished: false,
        questions: [],
      );

  @override
  Future<ContentModule> getModule(String id) async => const ContentModule(
    id: 'draft-module',
    title: 'Taslak Modül',
    description: 'Yönetim açıklaması',
    order: 1,
    isPublished: false,
    lessons: [
      ContentLessonSummary(
        id: 'draft-lesson',
        title: 'Taslak Ders',
        description: 'Ders açıklaması',
        estimatedDurationMinutes: 5,
        order: 1,
        isPublished: false,
      ),
    ],
  );

  @override
  Future<List<ContentModuleSummary>> getModules() async => List.of(modules);

  @override
  Future<void> updateLesson(String id, LessonWriteInput input) async {
    updateLessonCallCount++;
  }

  @override
  Future<void> updateModule(String id, ModuleWriteInput input) async {
    if (mutationError case final error?) throw error;
    updateModuleCallCount++;
    final index = modules.indexWhere((module) => module.id == id);
    if (index < 0) return;
    modules[index] = ContentModuleSummary(
      id: id,
      title: input.title,
      description: input.description,
      order: input.order,
      isPublished: input.isPublished,
      lessonCount: modules[index].lessonCount,
    );
  }

  @override
  Future<String> createQuiz(String lessonId, QuizWriteInput input) async =>
      'quiz-id';

  @override
  Future<void> updateQuiz(String id, QuizWriteInput input) async {}

  @override
  Future<String> createQuestion(
    String quizId,
    QuizQuestionWriteInput input,
  ) async {
    createQuestionCallCount++;
    return 'question-id';
  }

  @override
  Future<void> updateQuestion(String id, QuizQuestionWriteInput input) async {}

  @override
  Future<String> createOption(
    String questionId,
    QuizOptionWriteInput input,
  ) async {
    createOptionCallCount++;
    if (input.isCorrect) correctOptionCount++;
    return 'option-$createOptionCallCount';
  }

  @override
  Future<void> updateOption(String id, QuizOptionWriteInput input) async {}
}
