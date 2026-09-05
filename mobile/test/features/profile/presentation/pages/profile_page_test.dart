import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  testWidgets('profil progress bilgisini gösterir ve logout state temizler', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          educationRepositoryProvider.overrideWithValue(
            FakeEducationRepository(),
          ),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(completedLessons: [testCompletedLesson]),
          ),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(results: [testProfileQuizResult]),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'student@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'password123',
    );
    await tester.tap(find.text('Giriş Yap'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.text('Eğitim Modülleri')),
    );
    await tester.tap(find.text('Hemşireliğin Temelleri'));
    await tester.pumpAndSettle();
    expect(find.text('Dersler'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('ayse@example.com'), findsOneWidget);
    expect(find.text('Hemşirenin Temel Rolleri Quizi'), findsOneWidget);
    expect(find.textContaining('Doğru: 2 · Yanlış: 0'), findsOneWidget);
    expect(find.text('%100'), findsOneWidget);

    await tester.tap(find.text('Tümünü Gör'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz Geçmişi'), findsOneWidget);
    expect(
      find.text('Hemşirenin Temel Rolleri\nSkor: %100 · Doğru: 2 · Yanlış: 0'),
      findsOneWidget,
    );
    expect(find.textContaining('Skor: %100'), findsOneWidget);

    await tester.tap(find.text('Hemşirenin Temel Rolleri Quizi'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz Sonuç Detayı'), findsOneWidget);
    expect(find.text('Başarı Yüzdesi'), findsOneWidget);
    expect(find.text('Toplam Soru'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Yanlış'), 200);
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('Doğru'), findsOneWidget);
    expect(find.text('Yanlış'), findsOneWidget);

    await tester.tap(find.text('Eğitim'));
    await tester.pumpAndSettle();
    expect(find.text('Dersler'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz Sonuç Detayı'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Çıkış Yap'), 200);
    await tester.tap(find.text('Çıkış Yap'));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar hoş geldiniz'), findsOneWidget);
    final clearedState = container
        .read(progressControllerProvider)
        .requireValue;
    expect(clearedState.completedLessonIds, isEmpty);
    expect(authRepository.logoutCallCount, 1);
  });
}
