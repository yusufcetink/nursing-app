import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_learning_repositories.dart';

Future<ProviderContainer> showResult(
  WidgetTester tester, {
  required String lessonId,
  Future<EducationModule> Function()? loadModule,
}) async {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(restoredUser: FakeAuthRepository.user),
      ),
      educationRepositoryProvider.overrideWithValue(FakeEducationRepository()),
      if (loadModule != null)
        educationModuleProvider.overrideWith((ref, id) => loadModule()),
      progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      quizRepositoryProvider.overrideWithValue(FakeQuizRepository()),
      quizForLessonProvider.overrideWith(
        (ref, id) async => Quiz(
          id: testQuiz.id,
          lessonId: id,
          title: testQuiz.title,
          questions: testQuiz.questions,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await tester.pumpAndSettle();
  final router = container.read(appRouterProvider);
  final parameters = {
    AppRoutes.moduleIdParameter: testModule.id,
    AppRoutes.lessonIdParameter: lessonId,
  };
  unawaited(router.pushNamed(AppRoutes.lesson, pathParameters: parameters));
  await tester.pumpAndSettle();
  unawaited(router.pushNamed(AppRoutes.quiz, pathParameters: parameters));
  await tester.pumpAndSettle();
  final controller = container.read(
    quizControllerProvider((moduleId: testModule.id, lessonId: lessonId))
        .notifier,
  );
  controller.selectOption('care-1');
  await controller.submitAndContinue();
  controller.selectOption('advocacy-2');
  await controller.submitAndContinue();
  await tester.pump();
  return container;
}

void main() {
  testWidgets('son ders ana sayfaya gider ve geri quiz açılmaz', (
    tester,
  ) async {
    final container = await showResult(tester, lessonId: testLessons.last.id);
    await tester.pumpAndSettle();
    expect(find.text('Derse Dön'), findsNothing);
    expect(find.text('Sıradaki Derse Geç'), findsNothing);
    await tester.tap(find.text('Ana Sayfaya Dön'));
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.homePath);
    expect(router.canPop(), isFalse);
    expect(find.text('Quiz Sonucu'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Quiz Sonucu'), findsNothing);
  });

  testWidgets(
    'quiz geçmişinden geri ve eğitim sekmesine geçiş sonucu geri getirmez',
    (tester) async {
      final container = await showResult(
        tester,
        lessonId: testLessons.first.id,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quiz geçmişim'));
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);
      expect(router.state.uri.path, AppRoutes.quizHistoryPath);
      expect(find.text('Quiz Geçmişi'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.homePath,
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eğitim'));
      await tester.pumpAndSettle();
      expect(find.text('Quiz Sonucu'), findsNothing);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.homePath,
      );
    },
  );

  testWidgets('sonuç ekranında sistem geri tuşu ana sayfaya gider', (
    tester,
  ) async {
    final container = await showResult(tester, lessonId: testLessons.first.id);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      AppRoutes.homePath,
    );
    expect(find.text('Quiz Sonucu'), findsNothing);
  });

  testWidgets(
    'modül yüklenirken yanlış home CTA göstermez, hata tekrar denenir',
    (tester) async {
      final response = Completer<EducationModule>();
      var calls = 0;
      await showResult(
        tester,
        lessonId: testLessons.first.id,
        loadModule: () {
          calls++;
          return calls == 1 ? response.future : Future.value(testModule);
        },
      );
      expect(find.text('Sıradaki adım yükleniyor…'), findsOneWidget);
      expect(find.text('Ana Sayfaya Dön'), findsNothing);
      response.completeError(Exception('Bağlantı kesildi'));
      await tester.pumpAndSettle();
      expect(find.text('Sıradaki ders yüklenemedi.'), findsOneWidget);
      await tester.tap(find.text('Yeniden Dene'));
      await tester.pumpAndSettle();
      expect(find.text('Sıradaki Derse Geç'), findsOneWidget);
      expect(calls, 2);
    },
  );
}
