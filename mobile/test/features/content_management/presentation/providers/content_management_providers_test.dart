import 'package:asli_app/features/content_management/data/content_management_repository.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';
import 'package:asli_app/features/content_management/presentation/providers/content_management_providers.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_content_management_repository.dart';
import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  for (final operation in [
    'create module',
    'update module',
    'publish module',
    'unpublish module',
    'delete module',
    'create lesson',
    'update lesson',
    'publish lesson',
    'unpublish lesson',
    'delete lesson',
  ]) {
    test(
      '$operation öğrenci cachelerini aynı container içinde yeniler',
      () async {
        final repository = FakeEducationRepository();
        final content = FakeContentManagementRepository();
        final isModule = operation.endsWith('module');
        final isCreate = operation.startsWith('create');
        final moduleId = isModule && isCreate
            ? 'created-module'
            : testModule.id;
        final lessonId = !isModule && isCreate
            ? 'created-lesson'
            : testLessons.first.id;
        final selection = (moduleId: moduleId, lessonId: lessonId);
        var lessonReads = 0;
        var quizReads = 0;
        final container = ProviderContainer(
          overrides: [
            contentManagementRepositoryProvider.overrideWithValue(content),
            educationRepositoryProvider.overrideWithValue(repository),
            lessonProvider.overrideWith((ref, selection) async {
              lessonReads++;
              return testLessons.first;
            }),
            quizForLessonProvider.overrideWith((ref, lessonId) async {
              quizReads++;
              return testQuiz;
            }),
          ],
        );
        addTearDown(container.dispose);
        container.listen(educationModulesProvider, (_, _) {});
        container.listen(educationModuleProvider(moduleId), (_, _) {});
        container.listen(lessonProvider(selection), (_, _) {});
        container.listen(quizForLessonProvider(lessonId), (_, _) {});
        await container.read(educationModulesProvider.future);
        await container.read(educationModuleProvider(moduleId).future);
        await container.read(lessonProvider(selection).future);
        await container.read(quizForLessonProvider(lessonId).future);
        final controller = container.read(
          contentMutationControllerProvider.notifier,
        );
        final published = !operation.startsWith('unpublish');
        final moduleInput = ModuleWriteInput(
          title: 'Yeni başlık',
          description: 'Açıklama',
          order: 1,
          isPublished: published,
        );
        final lessonInput = LessonWriteInput(
          title: 'Yeni ders',
          description: 'Açıklama',
          estimatedDurationMinutes: 5,
          order: 1,
          isPublished: published,
        );
        if (operation == 'create module') {
          expect(await controller.createModule(moduleInput), moduleId);
        } else if (operation == 'delete module') {
          expect(await controller.deleteModule(moduleId), isTrue);
        } else if (isModule) {
          expect(await controller.updateModule(moduleId, moduleInput), isTrue);
        } else if (operation == 'create lesson') {
          expect(
            await controller.createLesson(moduleId, lessonInput),
            lessonId,
          );
        } else if (operation == 'delete lesson') {
          expect(await controller.deleteLesson(moduleId, lessonId), isTrue);
        } else {
          expect(
            await controller.updateLesson(moduleId, lessonId, lessonInput),
            isTrue,
          );
        }
        await container.read(educationModulesProvider.future);
        await container.read(educationModuleProvider(moduleId).future);
        await container.read(lessonProvider(selection).future);
        await container.read(quizForLessonProvider(lessonId).future);
        expect(repository.getModulesCallCount, 2);
        expect(repository.getModuleCallCount, 2);
        expect(lessonReads, isModule && isCreate ? 1 : 2);
        expect(quizReads, isModule && isCreate ? 1 : 2);
      },
    );
  }

  test('taslak görünmez; yayınlama, düzenleme, yayından kaldırma ve silme restart gerektirmez', () async {
    final content = FakeContentManagementRepository();
    final container = ProviderContainer(
      overrides: [
        contentManagementRepositoryProvider.overrideWithValue(content),
        educationRepositoryProvider.overrideWithValue(
          _PublishedModulesRepository(content),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(educationModulesProvider, (_, _) {});
    final controller = container.read(
      contentMutationControllerProvider.notifier,
    );
    expect(await container.read(educationModulesProvider.future), isEmpty);
    ModuleWriteInput input(bool published, [String title = 'Yeni modül']) =>
        ModuleWriteInput(
          title: title,
          description: 'Açıklama',
          order: 1,
          isPublished: published,
        );
    final id = (await controller.createModule(input(false)))!;
    expect(await container.read(educationModulesProvider.future), isEmpty);
    await controller.updateModule(id, input(true));
    expect(
      (await container.read(educationModulesProvider.future)).single.id,
      id,
    );
    await controller.updateModule(id, input(true, 'Güncel başlık'));
    expect(
      (await container.read(educationModulesProvider.future)).single.title,
      'Güncel başlık',
    );
    await controller.updateModule(id, input(false));
    expect(await container.read(educationModulesProvider.future), isEmpty);
    await controller.updateModule(id, input(true));
    expect(await container.read(educationModulesProvider.future), hasLength(1));
    await controller.deleteModule(id);
    expect(await container.read(educationModulesProvider.future), isEmpty);
  });

  for (final operation in [
    'create quiz',
    'publish quiz',
    'unpublish quiz',
    'delete quiz',
    'save question',
    'delete question',
  ]) {
    test('$operation öğrenci ders ve quiz verisini yeniler', () async {
      final repository = FakeEducationRepository();
      var quizReads = 0;
      final container = ProviderContainer(
        overrides: [
          contentManagementRepositoryProvider.overrideWithValue(
            FakeContentManagementRepository(),
          ),
          educationRepositoryProvider.overrideWithValue(repository),
          quizForLessonProvider.overrideWith((ref, id) async {
            quizReads++;
            return testQuiz;
          }),
        ],
      );
      addTearDown(container.dispose);
      final selection = (
        moduleId: testModule.id,
        lessonId: testLessons.first.id,
      );
      container.listen(lessonProvider(selection), (_, _) {});
      container.listen(quizForLessonProvider(selection.lessonId), (_, _) {});
      await container.read(lessonProvider(selection).future);
      await container.read(quizForLessonProvider(selection.lessonId).future);
      final controller = container.read(
        contentMutationControllerProvider.notifier,
      );
      if (operation == 'delete quiz') {
        await controller.deleteQuiz(selection.lessonId, testQuiz.id);
      } else if (operation == 'delete question') {
        await controller.deleteQuestion(selection.lessonId, 'question');
      } else if (operation == 'save question') {
        await controller.saveQuestion(
          lessonId: selection.lessonId,
          quizId: testQuiz.id,
          question: null,
          input: const QuizQuestionWriteInput(prompt: 'Soru?', order: 1),
          options: const [
            QuizOptionWriteInput(text: 'Cevap', isCorrect: true, order: 1),
          ],
        );
      } else {
        await controller.saveQuiz(
          selection.lessonId,
          operation == 'create quiz'
              ? null
              : ContentQuiz(
                  id: testQuiz.id,
                  lessonId: selection.lessonId,
                  title: 'Quiz',
                  isPublished: false,
                  questions: const [],
                ),
          QuizWriteInput(
            title: 'Quiz',
            isPublished: operation == 'publish quiz',
          ),
        );
      }
      await container.read(lessonProvider(selection).future);
      await container.read(quizForLessonProvider(selection.lessonId).future);
      expect(repository.getLessonCallCount, 2);
      expect(quizReads, 2);
    });
  }

  test('başarısız kayıt öğrenci cacheini değiştirmez', () async {
    final repository = FakeEducationRepository();
    final container = ProviderContainer(
      overrides: [
        contentManagementRepositoryProvider.overrideWithValue(
          FakeContentManagementRepository()
            ..mutationError = Exception('Kayıt başarısız'),
        ),
        educationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(educationModulesProvider, (_, _) {});
    await container.read(educationModulesProvider.future);
    expect(
      await container
          .read(contentMutationControllerProvider.notifier)
          .createModule(
            const ModuleWriteInput(
              title: 'Modül',
              description: 'Açıklama',
              order: 1,
              isPublished: true,
            ),
          ),
      isNull,
    );
    await container.read(educationModulesProvider.future);
    expect(repository.getModulesCallCount, 1);
    expect(container.read(contentMutationControllerProvider).hasError, isTrue);
  });

  test('içerik bloğu kaydedilince öğrenci ders cacheini yeniler', () async {
    final educationRepository = FakeEducationRepository();
    final container = ProviderContainer(
      overrides: [
        contentManagementRepositoryProvider.overrideWithValue(
          FakeContentManagementRepository(),
        ),
        educationRepositoryProvider.overrideWithValue(educationRepository),
      ],
    );
    addTearDown(container.dispose);

    const selection = (
      moduleId: 'nursing-fundamentals',
      lessonId: 'nursing-roles',
    );
    final subscription = container.listen(
      lessonProvider(selection),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(lessonProvider(selection).future);
    expect(educationRepository.getLessonCallCount, 1);

    await container
        .read(contentMutationControllerProvider.notifier)
        .createContentBlock(
          selection.lessonId,
          const ContentBlockWriteInput(
            blockType: ContentBlockType.text,
            textContent: 'Yeni içerik',
            sortOrder: 0,
          ),
        );
    await container.read(lessonProvider(selection).future);

    expect(educationRepository.getLessonCallCount, 2);
  });
}

final class _PublishedModulesRepository implements EducationRepository {
  _PublishedModulesRepository(this.content);
  final FakeContentManagementRepository content;

  @override
  Future<List<EducationModule>> getModules() async => content.modules
      .where((module) => module.isPublished)
      .map(
        (module) => EducationModule(
          id: module.id,
          title: module.title,
          description: module.description,
          order: module.order,
          lessonCount: module.lessonCount,
          lessons: const [],
        ),
      )
      .toList();

  @override
  Future<EducationModule> getModule(String id) async =>
      (await getModules()).firstWhere((module) => module.id == id);

  @override
  Future<Lesson> getLesson(String id) async => throw UnimplementedError();
}
