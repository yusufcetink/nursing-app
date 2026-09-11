import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/home/presentation/providers/learning_home_provider.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/progress/domain/models/progress_state.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';

import '../../helpers/fake_learning_repositories.dart';

void main() {
  EducationModule module(String id, int count) => EducationModule(
    id: id,
    title: id,
    description: '',
    order: 1,
    lessonCount: count,
    lessons: const [],
  );
  test(
    'devam alanı boş modülü atlar ve yarım kalan modülü öne çıkarır',
    () async {
      final container = ProviderContainer(
        overrides: [
          educationModulesProvider.overrideWith(
            (ref) async => [
              module('empty', 0),
              module('new', 3),
              module('started', 3),
            ],
          ),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(
              completedLessons: [
                CompletedLesson(
                  lessonId: 'a',
                  educationModuleId: 'started',
                  completedAtUtc: DateTime.utc(2026),
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(educationModulesProvider.future);
      await container.read(progressControllerProvider.future);
      expect(container.read(recommendedModuleProvider)?.id, 'started');
    },
  );
  test(
    'tüm modüller tamamlandıysa yeniden keşfet için modül döndürür',
    () async {
      final container = ProviderContainer(
        overrides: [
          educationModulesProvider.overrideWith(
            (ref) async => [module('finished', 1)],
          ),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(
              completedLessons: [
                CompletedLesson(
                  lessonId: 'a',
                  educationModuleId: 'finished',
                  completedAtUtc: DateTime.utc(2026),
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(educationModulesProvider.future);
      await container.read(progressControllerProvider.future);
      expect(container.read(recommendedModuleProvider)?.id, 'finished');
    },
  );
  test('sıradaki ders tamamlanan ilk dersi atlar', () async {
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          FakeProgressRepository(completedLessons: [testCompletedLesson]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(progressControllerProvider.future);
    expect(
      container.read(nextLessonIdProvider(testModule)),
      'ethical-principles',
    );
  });
}
