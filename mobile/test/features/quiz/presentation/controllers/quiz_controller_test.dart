import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';

import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  test('seçimleri ilerletir ve sonucu backend yanıtından kaydeder', () async {
    final container = ProviderContainer(
      overrides: [
        educationRepositoryProvider.overrideWithValue(
          FakeEducationRepository(),
        ),
        quizRepositoryProvider.overrideWithValue(FakeQuizRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(quizForLessonProvider('nursing-roles').future);
    await container.read(
      lessonProvider((
        moduleId: 'nursing-fundamentals',
        lessonId: 'nursing-roles',
      )).future,
    );
    final provider = quizControllerProvider((
      moduleId: 'nursing-fundamentals',
      lessonId: 'nursing-roles',
    ));
    final controller = container.read(provider.notifier);

    controller.selectOption('care-1');
    controller.selectOption('care-0');

    expect(container.read(provider).selectedOptionId, 'care-0');

    await controller.submitAndContinue();

    expect(container.read(provider).currentQuestionIndex, 1);
    expect(container.read(provider).answers, hasLength(1));
    expect(container.read(provider).incorrectCount, 0);

    controller.selectOption('advocacy-2');
    await controller.submitAndContinue();

    final result = container.read(provider);
    expect(result.isCompleted, isTrue);
    expect(result.correctCount, 1);
    expect(result.incorrectCount, 1);
    expect(result.successPercentage, 50);

    expect(result.result?.attemptId, 'new-attempt-id');
  });
}
