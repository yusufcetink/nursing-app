import 'package:flutter/material.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/features/quiz/presentation/widgets/lesson_quiz_card.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';
import 'package:asli_app/features/content_management/presentation/pages/lesson_quizzes_page.dart';
import 'package:asli_app/features/content_management/presentation/providers/content_management_providers.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_summary.dart';

import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  testWidgets('same lesson cards load and open their own quiz IDs', (
    tester,
  ) async {
    final requested = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Column(
              children: [
                LessonQuizCard(moduleId: 'm', lessonId: 'l', quizId: 'first'),
                LessonQuizCard(moduleId: 'm', lessonId: 'l', quizId: 'second'),
              ],
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.quizPath,
          name: AppRoutes.quiz,
          builder: (_, state) => Scaffold(
            body: Text(
              'Opened ${state.pathParameters[AppRoutes.quizIdParameter]}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lessonCompletedProvider.overrideWith((ref, id) => true),
          quizStatusProvider.overrideWith((ref, id) async {
            requested.add(id);
            return Quiz(
              id: id,
              lessonId: 'l',
              title: id,
              questions: testQuiz.questions,
              status: id == 'second' ? 'InProgress' : 'NotStarted',
            );
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(requested, containsAll(['first', 'second']));
    expect(find.text('Quiz’e Başla'), findsOneWidget);
    expect(find.text('Quiz’e Devam Et'), findsOneWidget);
    await tester.tap(find.text('Quiz’e Devam Et'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/education/m/lessons/l/quizzes/second');
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiz’e Başla'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/education/m/lessons/l/quizzes/first');
  });

  testWidgets('admin lists all quizzes and can open each or create another', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const LessonQuizzesPage(moduleId: 'm', lessonId: 'l'),
        ),
        GoRoute(
          path: AppRoutes.contentQuizPath,
          name: AppRoutes.contentQuiz,
          builder: (_, state) => Scaffold(
            body: Text(
              'Editor ${state.pathParameters[AppRoutes.contentQuizIdParameter]}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentLessonProvider.overrideWith(
            (ref, id) async => const ContentLesson(
              id: 'l',
              educationModuleId: 'm',
              title: 'Lesson',
              description: '',
              estimatedDurationMinutes: 1,
              order: 0,
              isPublished: true,
              quizzes: [
                QuizSummary(id: 'first', title: 'First quiz', order: 0),
                QuizSummary(
                  id: 'second',
                  title: 'Second quiz',
                  order: 1,
                  isPublished: false,
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First quiz'), findsOneWidget);
    expect(find.text('Second quiz'), findsOneWidget);
    await tester.tap(find.text('Second quiz'));
    await tester.pumpAndSettle();
    expect(find.text('Editor second'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiz Oluştur'));
    await tester.pumpAndSettle();
    expect(find.text('Editor new'), findsOneWidget);
  });
}
