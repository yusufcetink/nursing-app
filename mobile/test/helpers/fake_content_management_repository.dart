import 'package:asli_app/features/content_management/data/content_management_repository.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';

final class FakeContentManagementRepository
    implements ContentManagementRepository {
  int createModuleCallCount = 0;
  int updateModuleCallCount = 0;
  int createLessonCallCount = 0;
  int updateLessonCallCount = 0;

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
}
