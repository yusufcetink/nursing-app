import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/theme_mode_controller.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_question.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/features/quiz/presentation/widgets/quiz_feedback_panel.dart';
import 'package:asli_app/shared/widgets/learning_motion.dart';

import '../../../../helpers/fake_activity_repository.dart';
import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_learning_repositories.dart';
import '../../../../helpers/ui_test_helpers.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final variant in [
    (name: 'light', mode: ThemeMode.light, width: 390.0, scale: 1.0),
    (name: 'dark', mode: ThemeMode.dark, width: 390.0, scale: 1.0),
    (name: 'accessible', mode: ThemeMode.dark, width: 320.0, scale: 2.0),
  ]) {
    testWidgets('quiz selection scroll and server result ${variant.name}', (
      tester,
    ) async {
      tester.view.physicalSize = Size(variant.width, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = variant.scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final quiz = Quiz(
        id: testQuiz.id,
        attemptId: 'new-attempt-id',
        status: 'InProgress',
        lessonId: testQuiz.lessonId,
        title: testQuiz.title,
        questions: [
          for (final question in testQuiz.questions)
            QuizQuestion(
              id: question.id,
              prompt: question.prompt,
              options: [
                for (final option in question.options)
                  QuizOption(
                    id: option.id,
                    text: variant.scale > 1
                        ? '${option.text}. ${option.text}.'
                        : option.text,
                  ),
              ],
            ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository(),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(restoredUser: FakeAuthRepository.user),
          ),
          educationRepositoryProvider.overrideWithValue(
            FakeEducationRepository(),
          ),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(),
          ),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          quizRepositoryProvider.overrideWithValue(FakeQuizRepository()),
          quizForLessonProvider.overrideWith((ref, id) async => quiz),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(themeModeControllerProvider.notifier)
          .setThemeMode(variant.mode);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RepaintBoundary(key: Key('quiz-capture'), child: App()),
        ),
      );
      await tester.pumpAndSettle();
      container
          .read(appRouterProvider)
          .pushNamed(
            AppRoutes.quiz,
            pathParameters: {
              AppRoutes.moduleIdParameter: testModule.id,
              AppRoutes.lessonIdParameter: testQuiz.lessonId,
            },
          );
      await tester.pumpAndSettle();
      final provider = quizControllerProvider((
        moduleId: testModule.id,
        lessonId: testQuiz.lessonId,
      ));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Cevabı Onayla'),
            )
            .onPressed,
        isNull,
      );
      final first = find.byKey(const ValueKey('quiz_option_care-1'));
      await tester.reveal(first, 140);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(container.read(provider).selectedOptionId, 'care-1');
      expect(find.byType(QuizFeedbackPanel), findsNothing);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_QUIZ')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('quiz-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/quiz-reference-preview/${variant.name}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Cevabı Onayla'));
      await tester.pumpAndSettle();
      expect(container.read(provider).currentQuestionIndex, 1);
      expect(container.read(provider).selectedOptionId, isNull);
      expect(find.text('Doğru yanıt!'), findsNothing);
      expect(find.text('Soru 2 / 2'), findsOneWidget);
      final second = find.byKey(const ValueKey('quiz_option_advocacy-0'));
      await tester.reveal(second, 140);
      await tester.tap(second);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cevabı Onayla ve Bitir'));
      await tester.pumpAndSettle();
      expect(container.read(provider).successPercentage, 50);
      expect(container.read(provider).correctCount, 1);
      expect(container.read(provider).incorrectCount, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('confirmed feedback keeps 320 and 180 ms and reduced motion', (
    tester,
  ) async {
    for (final reduced in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const Scaffold(
              body: Column(
                children: [
                  QuizFeedbackPanel(
                    correct: true,
                    title: '1 doğru yanıt',
                    message: 'Güzel yakaladın.',
                  ),
                  QuizFeedbackPanel(
                    correct: false,
                    title: '1 yanlış yanıt',
                    message: 'Birlikte bakalım.',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final reveals = tester
          .widgetList<LearningReveal>(find.byType(LearningReveal))
          .toList();
      expect(reveals.map((r) => r.duration.inMilliseconds), [320, 180]);
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 1),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    }
  });
}
