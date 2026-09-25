import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_answer.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_submission_result.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/features/quiz/presentation/widgets/lesson_quiz_card.dart';

import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  for (final status in ['NotStarted', 'InProgress', 'Completed']) {
    for (final dark in [false, true]) {
      testWidgets(
        '$status card, dark=$dark, shows backend status and no completed retry',
        (tester) async {
          tester.view.physicalSize = const Size(320, 850);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.5;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final quiz = Quiz(
            id: testQuiz.id,
            lessonId: testQuiz.lessonId,
            title: 'Ağrı değerlendirmesi',
            questions: List.generate(18, (_) => testQuiz.questions.first),
            status: status,
            savedAnswers: status == 'InProgress'
                ? List.generate(
                    7,
                    (i) =>
                        QuizAnswer(questionId: 'q$i', selectedOptionId: 'o$i'),
                  )
                : [],
            result: status == 'Completed'
                ? QuizSubmissionResult(
                    attemptId: 'a',
                    quizId: testQuiz.id,
                    totalQuestionCount: 18,
                    correctCount: 12,
                    incorrectCount: 6,
                    successPercentage: 67,
                    completedAtUtc: DateTime.utc(2026, 9, 21),
                  )
                : null,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                lessonQuizStatusProvider.overrideWith((ref, id) async => quiz),
              ],
              child: MaterialApp(
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: const Scaffold(
                  body: SingleChildScrollView(
                    child: LessonQuizCard(moduleId: 'm', lessonId: 'l'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (status == 'NotStarted') {
            expect(find.text('Quiz’e Başla'), findsOneWidget);
          } else if (status == 'InProgress') {
            expect(find.text('Quiz’e Devam Et'), findsOneWidget);
            expect(find.text('7 / 18 soru tamamlandı'), findsOneWidget);
            expect(
              tester
                  .widget<LinearProgressIndicator>(
                    find.byType(LinearProgressIndicator),
                  )
                  .value,
              7 / 18,
            );
          } else {
            expect(find.text('Quiz Tamamlandı'), findsOneWidget);
            expect(find.text('12 doğru • 6 yanlış • %67'), findsOneWidget);
            expect(find.byType(FilledButton), findsNothing);
            expect(find.textContaining('Tekrar'), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
