import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';

import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  test('onay gerekir, çift kontrol ve erken ilerleme engellenir; hata yeniden denenebilir', () async {
    final repository = FakeQuizRepository();
    final container = ProviderContainer(
      overrides: [quizRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(quizForLessonProvider(testQuiz.lessonId).future);
    final provider = quizControllerProvider((
      moduleId: testModule.id,
      lessonId: testQuiz.lessonId,
    ));
    container.listen(provider, (_, _) {});
    final controller = container.read(provider.notifier);
    controller.selectOption('care-0');
    expect(repository.checkCalls, 0);
    await controller.submitAndContinue();
    expect(container.read(provider).currentQuestionIndex, 0);
    repository.failCheck = true;
    await controller.checkAnswer();
    expect(container.read(provider).errorMessage, isNotNull);
    expect(container.read(provider).isChecking, isFalse);
    expect(container.read(provider).selectedOptionId, 'care-0');
    expect(container.read(provider).answerCheck, isNull);
    repository.failCheck = false;
    final checking = controller.checkAnswer();
    expect(container.read(provider).isChecking, isTrue);
    controller.selectOption('care-1');
    await controller.checkAnswer();
    await Future<void>.delayed(Duration.zero);
    expect(repository.checkCalls, 2);
    expect(container.read(provider).answerCheck?.isCorrect, isFalse);
    expect(container.read(provider).answerCheck?.correctOptionId, 'care-1');
    expect(container.read(provider).feedbackComplete, isFalse);
    await controller.submitAndContinue();
    expect(container.read(provider).currentQuestionIndex, 0);
    await checking;
    controller.selectOption('care-1');
    expect(container.read(provider).selectedOptionId, 'care-0');
    await controller.submitAndContinue();
    expect(container.read(provider).currentQuestionIndex, 1);
    expect(container.read(provider).answerCheck, isNull);
    expect(container.read(provider).answers.single.selectedOptionId, 'care-0');

    controller.selectOption('advocacy-2');
    await controller.checkAnswer();
    repository.failSubmit = true;
    await controller.submitAndContinue();
    expect(container.read(provider).errorMessage, isNotNull);
    expect(container.read(provider).isCompleted, isFalse);
    expect(container.read(provider).answerCheck?.isCorrect, isTrue);
    expect(container.read(provider).answers, hasLength(1));
    repository.failSubmit = false;
    final submitting = controller.submitAndContinue();
    await controller.submitAndContinue();
    await submitting;
    expect(repository.submitCalls, 2);
    expect(repository.checkCalls, 3);
    expect(container.read(provider).answers, hasLength(2));
    expect(container.read(provider).successPercentage, 50);
  });

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
    container.listen(provider, (_, _) {});
    final controller = container.read(provider.notifier);

    controller.selectOption('care-1');
    controller.selectOption('care-0');

    expect(container.read(provider).selectedOptionId, 'care-0');

    await controller.checkAnswer();
    await controller.submitAndContinue();

    expect(container.read(provider).currentQuestionIndex, 1);
    expect(container.read(provider).answers, hasLength(1));
    expect(container.read(provider).incorrectCount, 0);

    controller.selectOption('advocacy-2');
    await controller.checkAnswer();
    await controller.submitAndContinue();

    final result = container.read(provider);
    expect(result.isCompleted, isTrue);
    expect(result.correctCount, 1);
    expect(result.incorrectCount, 1);
    expect(result.successPercentage, 50);

    expect(result.result?.attemptId, 'new-attempt-id');
  });
}
