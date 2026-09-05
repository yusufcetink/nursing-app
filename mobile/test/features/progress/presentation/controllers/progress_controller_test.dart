import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';

import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  test('DB ilerlemesini yükler ve modül oranını hesaplar', () async {
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          FakeProgressRepository(completedLessons: [testCompletedLesson]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(progressControllerProvider.future);
    const module = EducationModule(
      id: 'nursing-fundamentals',
      title: 'Module',
      description: 'Description',
      order: 1,
      lessonCount: 3,
      lessons: [],
    );

    expect(container.read(lessonCompletedProvider('nursing-roles')), isTrue);
    expect(
      container.read(moduleProgressProvider(module)),
      closeTo(1 / 3, 0.001),
    );
  });

  test(
    'ders tamamlamayı repository üzerinden kalıcı state’e yansıtır',
    () async {
      final container = ProviderContainer(
        overrides: [
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(progressControllerProvider.future);

      final completed = await container
          .read(progressControllerProvider.notifier)
          .completeLesson('nursing-roles');

      expect(completed, isTrue);
      expect(
        container
            .read(progressControllerProvider)
            .requireValue
            .completedLessonIds,
        contains('nursing-roles'),
      );
    },
  );

  test('oturum kapanırken yerel görünüm state’i temizlenebilir', () async {
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          FakeProgressRepository(completedLessons: [testCompletedLesson]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(progressControllerProvider.future);

    container.read(progressControllerProvider.notifier).reset();

    expect(
      container
          .read(progressControllerProvider)
          .requireValue
          .completedLessonIds,
      isEmpty,
    );
  });
}
