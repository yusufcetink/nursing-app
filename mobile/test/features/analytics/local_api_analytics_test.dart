import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';

// Opt-in: uses real local API accounts supplied in an ignored fixture file.
// ANALYTICS_LOCAL_FIXTURE must contain student/admin {id,email,password}.
import 'dart:convert';
import 'dart:io';

import 'package:asli_app/app/app.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/storage/token_storage.dart';
import 'package:asli_app/features/analytics/application/activity_tracker.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/home/presentation/pages/home_page.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/features/user_management/presentation/pages/user_activity_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixturePath = Platform.environment['ANALYTICS_LOCAL_FIXTURE'];
  testWidgets('real API student journey appears in Flutter admin analytics', (
    tester,
  ) async {
    final fixture = jsonDecode(
      File(fixturePath!).readAsStringSync(),
    ) as Map<String, dynamic>;
    final student = fixture['student'] as Map<String, dynamic>;
    final admin = fixture['admin'] as Map<String, dynamic>;
    final previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousHttpOverrides);
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    final storage = _MemoryTokenStorage();
    final api = ApiClient(
      tokenStorage: storage,
      dio: Dio(
        BaseOptions(
          baseUrl:
              Platform.environment['ANALYTICS_LOCAL_API'] ??
              'http://localhost:5218',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ),
    );
    var authenticatedBatches = 0;
    var allBatchesAuthenticated = true;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/activity/events/batch') {
            allBatchesAuthenticated &= options.headers['Authorization'] != null;
            authenticatedBatches++;
          }
          handler.next(options);
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );

    Future<void> waitFor(bool Function() ready) async {
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        if (ready()) return;
      }
      expect(ready(), isTrue, reason: 'Local API/UI did not finish loading');
    }

    Future<void> login(Map<String, dynamic> account) async {
      await waitFor(
        () => find.byKey(const Key('login_email_field')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        account['email'] as String,
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        account['password'] as String,
      );
      await tester.ensureVisible(find.text('Giriş Yap'));
      await tester.tap(find.text('Giriş Yap'));
      await waitFor(
        () =>
            container.read(authControllerProvider).value?.id == account['id'] &&
            find.byType(HomePage).evaluate().isNotEmpty,
      );
      debugPrint('[local-check] logged in');
      await tester.pump(const Duration(milliseconds: 400));
    }

    await login(student);
    final tracker = container.read(activityTrackerProvider);
    expect(tracker.hasSession, isTrue);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 3)),
    );
    await waitFor(() => container.read(educationModulesProvider).hasValue);
    final modules = container.read(educationModulesProvider).requireValue;
    final moduleProvider = educationModuleProvider(
      modules
          .firstWhere(
            (module) => module.id == '0f16d833-4719-4a80-a0df-46cb1bbd9c31',
          )
          .id,
    );
    container.read(moduleProvider);
    await waitFor(() => container.read(moduleProvider).hasValue);
    final module = container.read(moduleProvider).requireValue;
    final lesson = module.lessons.first;
    final router = container.read(appRouterProvider);
    router.pushNamed(
      AppRoutes.educationModule,
      pathParameters: {'moduleId': module.id},
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    router.pushNamed(
      AppRoutes.lesson,
      pathParameters: {'moduleId': module.id, 'lessonId': lesson.id},
    );
    final selectedLesson = lessonProvider((
      moduleId: module.id,
      lessonId: lesson.id,
    ));
    container.read(selectedLesson);
    await waitFor(() => container.read(selectedLesson).hasValue);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 3)),
    );
    await tester.runAsync(
      () => container
          .read(progressControllerProvider.notifier)
          .completeLesson(lesson.id),
    );
    final selectedQuiz = quizProvider(
      container.read(selectedLesson).requireValue.quizzes.first.id,
    );
    container.read(selectedQuiz);
    await waitFor(() => container.read(selectedQuiz).hasValue);
    final quiz = container.read(selectedQuiz).requireValue;
    router.pushNamed(
      AppRoutes.quiz,
      pathParameters: {
        'moduleId': module.id,
        'lessonId': lesson.id,
        'quizId': quiz.id,
      },
    );
    await tester.pump(const Duration(milliseconds: 400));
    final selection = (
      moduleId: module.id,
      lessonId: lesson.id,
      quizId: quiz.id,
    );
    for (var index = 0; index < quiz.questions.length; index++) {
      final option = find.text(quiz.questions[index].options.first.text);
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await tester.tap(
        find.text(
          index == quiz.questions.length - 1
              ? 'Cevabı Onayla ve Bitir'
              : 'Cevabı Onayla',
        ),
      );
      await waitFor(() {
        final state = container.read(quizControllerProvider(selection));
        return state.isCompleted || state.currentQuestionIndex == index + 1;
      });
    }
    expect(
      container.read(quizControllerProvider(selection)).isCompleted,
      isTrue,
    );
    debugPrint('[local-check] student flow complete');
    await tester.tap(find.text('Profil'));
    await tester.pump(const Duration(milliseconds: 400));
    var flushed = false;
    tracker.flush().then((_) => flushed = true);
    await waitFor(() => flushed);
    expect(authenticatedBatches, greaterThan(0));
    expect(allBatchesAuthenticated, isTrue);
    bool? loggedOut;
    container
        .read(authControllerProvider.notifier)
        .logout()
        .then((value) => loggedOut = value);
    await waitFor(() => loggedOut != null);
    expect(loggedOut, isTrue);
    debugPrint('[local-check] student logout complete');
    await tester.pump(const Duration(milliseconds: 400));
    await login(admin);
    final range = (
      userId: student['id'] as String,
      fromUtc: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      toUtc: DateTime.now().toUtc().add(const Duration(seconds: 1)),
    );
    final analyticsProvider = userActivityProvider(range);
    container.read(analyticsProvider);
    await waitFor(() => container.read(analyticsProvider).hasValue);
    final analytics = container.read(analyticsProvider).requireValue;
    debugPrint('[local-check] admin API data loaded');
    expect(analytics.sessionCount, greaterThanOrEqualTo(1));
    expect(
      analytics.screens.firstWhere((s) => s.key == 'home').durationSeconds,
      greaterThan(0),
    );
    expect(
      analytics.modules.firstWhere((m) => m.key == module.id).durationSeconds,
      greaterThan(0),
    );
    expect(
      analytics.lessons.firstWhere((l) => l.key == lesson.id).durationSeconds,
      greaterThan(0),
    );
    expect(analytics.quizzes, isNotEmpty);
    for (final event in [
      'session_start',
      'session_end',
      'screen_view',
      'screen_leave',
      'module_open',
      'lesson_open',
      'quiz_start',
      'quiz_answer',
      'quiz_complete',
    ]) {
      expect(
        analytics.timeline.any((e) => e.eventType == event),
        isTrue,
        reason: event,
      );
    }
    router.goNamed(
      AppRoutes.userActivity,
      pathParameters: {'userId': student['id'] as String},
    );
    await waitFor(() => find.text('Toplam aktif süre').evaluate().isNotEmpty);
    debugPrint('[local-check] admin screen rendered');
    expect(find.text('Kullanım Analizi'), findsOneWidget);
    expect(find.text('Analytics Local Student'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      final output = Directory('build/analytics-validation')
        ..createSync(recursive: true);
      await File('${output.path}/result.json').writeAsString(
        jsonEncode({
          'studentId': student['id'],
          'moduleId': module.id,
          'lessonId': lesson.id,
          'quizId': quiz.id,
          'sessionCount': analytics.sessionCount,
          'eventCount': analytics.eventCount,
          'activeDurationSeconds': analytics.activeDurationSeconds,
          'authenticatedBatches': authenticatedBatches,
          'adminScreenVerified': true,
        }),
      );
    });
    await tester.pumpWidget(const SizedBox.shrink());
    api.dio.close(force: true);
    await tester.pump(const Duration(seconds: 4));
  }, skip: fixturePath == null);
}

class _MemoryTokenStorage implements TokenStorage {
  String? _token;
  @override
  Future<String?> readAccessToken() async => _token;
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<bool> rotateTokens({
    required String expectedRefreshToken,
    required String accessToken,
    required String refreshToken,
  }) async {
    if (await readRefreshToken() != expectedRefreshToken) {
      return false;
    }
    await writeTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      persist: true,
    );
    return true;
  }

  @override
  Future<bool> clearTokensIfUnchanged({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    if (await readAccessToken() != accessToken ||
        await readRefreshToken() != refreshToken ||
        (accessToken == null && refreshToken == null)) {
      return false;
    }
    await deleteTokens();
    return true;
  }

  @override
  Future<String> getDeviceId() async => 'test-device';
  @override
  Future<void> writeTokens({
    required String accessToken,
    required String? refreshToken,
    required bool persist,
  }) async => _token = accessToken;
  @override
  Future<void> deleteTokens() async {
    _token = null;
  }
}
