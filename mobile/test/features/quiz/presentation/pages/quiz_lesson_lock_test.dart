import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/progress/domain/models/progress_state.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/features/quiz/presentation/widgets/lesson_quiz_card.dart';

import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  for (final succeeds in [true, false]) {
    testWidgets(
      'all lesson quizzes stay locked until completion succeeds=$succeeds',
      (tester) async {
        final repository = _PendingProgressRepository();
        final container = ProviderContainer(
          overrides: [
            progressRepositoryProvider.overrideWithValue(repository),
            quizStatusProvider.overrideWith(
              (ref, id) async => Quiz(
                id: id,
                lessonId: 'lesson',
                title: id,
                questions: testQuiz.questions,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    LessonQuizCard(
                      moduleId: 'module',
                      lessonId: 'lesson',
                      quizId: 'first',
                    ),
                    LessonQuizCard(
                      moduleId: 'module',
                      lessonId: 'lesson',
                      quizId: 'second',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        void expectLocked() {
          expect(
            find.text('Quizi açmak için önce dersi tamamla.'),
            findsNWidgets(2),
          );
          expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
          expect(
            tester
                .widgetList<FilledButton>(find.byType(FilledButton))
                .every((b) => b.onPressed == null),
            isTrue,
          );
        }

        expectLocked();
        final completion = container
            .read(progressControllerProvider.notifier)
            .completeLesson('lesson');
        await tester.pump();
        expectLocked();
        if (succeeds) {
          repository.completion.complete(
            CompletedLesson(
              lessonId: 'lesson',
              educationModuleId: 'module',
              completedAtUtc: DateTime.utc(2026),
            ),
          );
        } else {
          repository.completion.completeError(Exception('Completion failed'));
        }
        expect(await completion, succeeds);
        await tester.pumpAndSettle();
        if (succeeds) {
          expect(find.byIcon(Icons.lock_outline), findsNothing);
          expect(find.text('Quiz’e Başla'), findsNWidgets(2));
          expect(
            tester
                .widgetList<FilledButton>(find.byType(FilledButton))
                .every((b) => b.onPressed != null),
            isTrue,
          );
        } else {
          expectLocked();
        }
      },
    );
  }
}

class _PendingProgressRepository implements ProgressRepository {
  final completion = Completer<CompletedLesson>();
  @override
  Future<CompletedLesson> completeLesson(String lessonId) => completion.future;
  @override
  Future<ProgressState> getProgress() async => ProgressState.initial();
}
