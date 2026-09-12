import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/quiz/presentation/providers/quiz_next_lesson_provider.dart';

import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  for (final (current, next) in [
    ('nursing-roles', 'ethical-principles'),
    ('ethical-principles', 'care-process'),
    ('care-process', null),
    ('removed-lesson', null),
  ]) {
    test('$current quizinden sonra $next seçilir', () async {
      final container = ProviderContainer(
        overrides: [
          educationModuleProvider.overrideWith((ref, id) async => testModule),
        ],
      );
      addTearDown(container.dispose);
      await container.read(educationModuleProvider(testModule.id).future);
      final nextLesson = container.read(
        quizNextLessonProvider((moduleId: testModule.id, lessonId: current)),
      );
      expect(nextLesson.requireValue?.id, next);
    });
  }

  test('boş modülde önceki derse dönmez', () async {
    final container = ProviderContainer(
      overrides: [
        educationModuleProvider.overrideWith(
          (ref, id) async => EducationModule(
            id: id,
            title: 'Modül',
            description: '',
            order: 1,
            lessonCount: 0,
            lessons: const [],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(educationModuleProvider(testModule.id).future);
    expect(
      container
          .read(
            quizNextLessonProvider((
              moduleId: testModule.id,
              lessonId: 'removed',
            )),
          )
          .requireValue,
      isNull,
    );
  });
}
