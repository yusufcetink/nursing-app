import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/theme/app_theme.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_submission_result.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/features/quiz/presentation/pages/quiz_result_page.dart';
import 'package:asli_app/features/quiz/presentation/widgets/quiz_result_hero.dart';
import 'package:asli_app/shared/widgets/learning_motion.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('result layout dark=$dark text=$scale', (tester) async {
        tester.view.physicalSize = scale == 1
            ? const Size(390, 844)
            : const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(restoredUser: FakeAuthRepository.user),
            ),
            educationRepositoryProvider.overrideWithValue(
              FakeEducationRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);
        for (final percentage in [80, 0, 100]) {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: RepaintBoundary(
                    key: const Key('result-capture'),
                    child: QuizResultPage(
                      moduleId: testModule.id,
                      currentLessonId: testQuiz.lessonId,
                      quiz: testQuiz,
                      session: QuizSessionState(
                        currentQuestionIndex: 1,
                        selectedOptionId: null,
                        answers: const [],
                        isCompleted: true,
                        isSubmitting: false,
                        result: QuizSubmissionResult(
                          attemptId: 'result-$percentage',
                          quizId: testQuiz.id,
                          totalQuestionCount: 10,
                          correctCount: percentage ~/ 10,
                          incorrectCount: 10 - percentage ~/ 10,
                          successPercentage: percentage,
                          completedAtUtc: DateTime.utc(2026, 9, 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .widget<QuizResultHero>(find.byType(QuizResultHero))
                .percentage,
            percentage,
          );
          expect(find.text('Derse Dön'), findsNothing);
          expect(find.text('Sıradaki Derse Geç').hitTestable(), findsOneWidget);
          final animation = tester.widget<TweenAnimationBuilder<double>>(
            find.descendant(
              of: find.byType(QuizResultHero),
              matching: find.byType(TweenAnimationBuilder<double>),
            ),
          );
          expect(animation.duration, LearningMotion.progress);
          if (const bool.fromEnvironment('CAPTURE_RESULTS') &&
              scale == 1 &&
              percentage == 80) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('result-capture')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/quiz-result-preview/${dark ? "dark" : "light"}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.drag(find.byType(ListView), const Offset(0, -900));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  }
}
