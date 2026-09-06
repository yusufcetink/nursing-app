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
  Future<ContentLesson> getLesson(String id) async => const ContentLesson(
    id: 'draft-lesson',
    educationModuleId: 'draft-module',
    title: 'Taslak Ders',
    description: 'Ders açıklaması',
    content: 'Ders içeriği',
    estimatedDurationMinutes: 5,
    order: 1,
    isPublished: false,
    quizId: 'quiz-id',
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
    updateModuleCallCount++;
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
