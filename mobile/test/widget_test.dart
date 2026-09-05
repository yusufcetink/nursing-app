import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_learning_repositories.dart';

void main() {
  testWidgets('dersi tamamlar ve quiz sonucuna kadar ilerler', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          educationRepositoryProvider.overrideWithValue(
            FakeEducationRepository(),
          ),
          quizRepositoryProvider.overrideWithValue(FakeQuizRepository()),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(),
          ),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tekrar hoş geldiniz'), findsOneWidget);
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

    expect(find.text('Eğitim Modülleri'), findsOneWidget);
    expect(find.text('Hemşireliğin Temelleri'), findsOneWidget);
    expect(find.text('3 ders'), findsOneWidget);
    expect(find.text('%0 tamamlandı'), findsOneWidget);

    await tester.tap(find.text('Hemşireliğin Temelleri'));
    await tester.pumpAndSettle();

    expect(find.text('Dersler'), findsOneWidget);
    expect(find.text('Hemşirenin Temel Rolleri'), findsOneWidget);
    expect(find.text('Etik İlkeler'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Hemşirelik Bakım Süreci'), 200);
    expect(find.text('Hemşirelik Bakım Süreci'), findsOneWidget);

    await tester.ensureVisible(find.text('Hemşirenin Temel Rolleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hemşirenin Temel Rolleri'));
    await tester.pumpAndSettle();

    expect(
      find.text('Hemşirelik uygulamasındaki temel rol ve sorumluluklar.'),
      findsOneWidget,
    );
    expect(find.text('Tahmini süre: 8 dakika'), findsOneWidget);
    expect(find.text('Bakım Verme Rolü'), findsOneWidget);
    expect(find.text('Eğitim ve Savunuculuk'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Dersi Tamamla'), 200);
    await tester.tap(find.text('Dersi Tamamla'));
    await tester.pump();

    expect(find.text("Quiz'e Geç"), findsOneWidget);

    await tester.tap(find.text("Quiz'e Geç"));
    await tester.pumpAndSettle();

    expect(find.text('Soru 1 / 2'), findsOneWidget);
    expect(
      find.text('Hemşirenin bakım verme rolünün temel amacı hangisidir?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Bakım kararlarını yalnızca ekip adına vermek'));
    await tester.pump();
    await tester.tap(find.text('Sonraki Soru'));
    await tester.pump();

    expect(find.text('Soru 2 / 2'), findsOneWidget);
    expect(
      find.text('Hasta savunuculuğu öncelikle neyi destekler?'),
      findsOneWidget,
    );

    final correctAnswer = find.text(
      'Bireyin haklarını ve kararlara katılımını',
    );
    await tester.scrollUntilVisible(correctAnswer, 150);
    await tester.tap(correctAnswer);
    await tester.pump();
    await tester.tap(find.text('Quizi Bitir'));
    await tester.pumpAndSettle();

    expect(find.text('Quiz Sonucu'), findsOneWidget);
    expect(find.text('Doğru: 1'), findsOneWidget);
    expect(find.text('Yanlış: 1'), findsOneWidget);
    expect(find.text('Başarı: %50'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text("Quiz'e Geç"), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Tamamlandı'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('%33 tamamlandı'), findsOneWidget);
  });
}
