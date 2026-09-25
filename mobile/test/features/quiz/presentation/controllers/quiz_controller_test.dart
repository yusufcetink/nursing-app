import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';

import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  test(
    'save failure stays on question; successful acknowledgement advances once',
    () async {
      final repository = FakeQuizRepository();
      final container = ProviderContainer(
        overrides: [quizRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final quiz = quizForLessonProvider(testQuiz.lessonId);
      container.listen(quiz, (_, _) {});
      await container.read(quiz.future);
      final provider = quizControllerProvider((
        moduleId: testModule.id,
        lessonId: testQuiz.lessonId,
      ));
      container.listen(provider, (_, _) {});
      final controller = container.read(provider.notifier);
      controller.selectOption('care-0');
      repository.failSave = true;
      await controller.submitAndContinue();
      expect(container.read(provider).currentQuestionIndex, 0);
      expect(container.read(provider).answers, isEmpty);
      expect(container.read(provider).selectedOptionId, 'care-0');
      expect(container.read(provider).errorMessage, isNotNull);
      repository.failSave = false;
      final saving = controller.submitAndContinue();
      controller.selectOption('care-1');
      await controller.submitAndContinue();
      await saving;
      expect(repository.saveCalls, 2);
      expect(container.read(provider).currentQuestionIndex, 1);
      expect(
        container.read(provider).answers.single.selectedOptionId,
        'care-0',
      );
      controller.selectOption('advocacy-2');
      await controller.submitAndContinue();
      final result = container.read(provider);
      expect(result.isCompleted, isTrue);
      expect(result.correctCount, 1);
      expect(result.incorrectCount, 1);
      expect(result.successPercentage, 50);
      await controller.submitAndContinue();
      expect(repository.saveCalls, 3);
    },
  );

  test(
    'restart resumes persisted answers, including a lost acknowledgement',
    () async {
      final repository = FakeQuizRepository()..failAfterSave = true;
      Future<ProviderContainer> open() async {
        final container = ProviderContainer(
          overrides: [quizRepositoryProvider.overrideWithValue(repository)],
        );
        container.listen(quizForLessonProvider(testQuiz.lessonId), (_, _) {});
        await container.read(quizForLessonProvider(testQuiz.lessonId).future);
        return container;
      }

      final provider = quizControllerProvider((
        moduleId: testModule.id,
        lessonId: testQuiz.lessonId,
      ));
      final first = await open();
      first.listen(provider, (_, _) {});
      first.read(provider.notifier).selectOption('care-1');
      await first.read(provider.notifier).submitAndContinue();
      expect(first.read(provider).currentQuestionIndex, 0);
      first.dispose();
      repository.failAfterSave = false;
      final resumed = await open();
      addTearDown(resumed.dispose);
      resumed.listen(provider, (_, _) {});
      expect(resumed.read(provider).currentQuestionIndex, 1);
      expect(resumed.read(provider).answers.single.selectedOptionId, 'care-1');
      resumed.read(provider.notifier).selectOption('advocacy-2');
      await resumed.read(provider.notifier).submitAndContinue();
      resumed.dispose();
      final completed = await open();
      addTearDown(completed.dispose);
      completed.listen(provider, (_, _) {});
      expect(completed.read(provider).isCompleted, isTrue);
      expect(completed.read(provider).successPercentage, 100);
    },
  );
}
