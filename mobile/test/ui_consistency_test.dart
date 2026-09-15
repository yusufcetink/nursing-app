import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/theme/app_theme.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';
import 'package:asli_app/features/content_management/data/content_management_repository.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';
import 'package:asli_app/features/content_management/presentation/pages/content_modules_page.dart';
import 'package:asli_app/features/content_management/presentation/widgets/publication_status.dart';
import 'package:asli_app/features/user_management/domain/models/user_activity_analytics.dart';
import 'package:asli_app/features/user_management/presentation/pages/user_activity_page.dart';

import 'helpers/fake_content_management_repository.dart';
import 'helpers/ui_test_helpers.dart';

void main() {
  for (final dark in [false, true]) {
    Widget host(Widget child) => MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: child,
      ),
    );
    void size(WidgetTester tester) {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('shared states scroll and retry dark=$dark', (tester) async {
      size(tester);
      var retries = 0;
      final message = List.filled(
        8,
        'Bağlantı kurulamadı. Lütfen yeniden deneyin.',
      ).join(' ');
      await tester.pumpWidget(
        host(
          Scaffold(
            body: ContentErrorView(message: message, onRetry: () => retries++),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Tekrar Dene'));
      await tester.tap(find.text('Tekrar Dene'));
      expect(retries, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        host(Scaffold(body: EmptyContentView(message: message))),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
    testWidgets('management cards preserve delete confirmation dark=$dark', (
      tester,
    ) async {
      size(tester);
      final repository = FakeContentManagementRepository();
      repository.modules[0] = const ContentModuleSummary(
        id: 'draft-module',
        title: 'Uzun modül başlığı: Hemşirelikte Hasta Güvenliği ve Klinik Uygulamalar',
        description: 'Modül açıklaması',
        order: 3,
        isPublished: false,
        lessonCount: 6,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentManagementRepositoryProvider.overrideWithValue(repository),
          ],
          child: host(const ContentModulesPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final delete = find.byKey(const Key('delete_module_draft-module'));
      await tester.reveal(delete, 140);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(repository.deleteModuleCallCount, 0);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(repository.deleteModuleCallCount, 0);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(repository.deleteModuleCallCount, 1);
      expect(find.byType(EmptyContentView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        host(
          const Scaffold(
            body: Column(
              children: [
                PublicationStatus(isPublished: true),
                PublicationStatus(isPublished: false),
              ],
            ),
          ),
        ),
      );
      final chips = tester.widgetList<Chip>(find.byType(Chip)).toList();
      expect(chips[0].backgroundColor, isNot(chips[1].backgroundColor));
    });
    testWidgets('analytics long content remains readable dark=$dark', (
      tester,
    ) async {
      size(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userActivityProvider.overrideWith(
              (ref, range) async => UserActivityAnalytics(
                userId: 'student',
                displayName: 'Uzun Adlı Hemşirelik Öğrencisi',
                lastActiveAtUtc: DateTime.utc(2026, 9, 15),
                activeDurationSeconds: 456789,
                sessionCount: 35,
                eventCount: 500,
                screens: const [
                  ActivityDuration(
                    key: 'lesson',
                    name: 'Uzun ders başlığı ile klinik uygulamalar',
                    durationSeconds: 500,
                  ),
                ],
                modules: const [],
                lessons: const [],
                quizzes: const [
                  QuizActivity(
                    title: 'Uzun başlıklı değerlendirme soruları',
                    attemptCount: 10,
                    durationSeconds: 12345,
                    averageScore: 80,
                  ),
                ],
                timeline: [
                  ActivityTimelineItem(
                    eventType: 'quiz_complete',
                    occurredAtUtc: DateTime.utc(2026, 9, 15, 10, 15),
                    screenName: 'quiz',
                    target: 'Sıradaki Derse Geç',
                  ),
                ],
              ),
            ),
          ],
          child: host(const UserActivityPage(userId: 'student')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.reveal(find.text('Quiz süreleri ve sonuçları'), 160);
      expect(tester.takeException(), isNull);
      await tester.reveal(find.text('Quiz Complete'), 160);
      expect(tester.takeException(), isNull);
    });
  }
}
