import 'helpers/ui_test_helpers.dart';

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

    expect(find.text('Bilgin büyüsün.\nGüvenin artsın.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'student@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'password123',
    );
    await tester.ensureVisible(find.text('Giriş Yap'));
    await tester.tap(find.text('Giriş Yap'));
    await tester.pumpAndSettle();

    await tester.reveal(find.text('Eğitim Modülleri'), 200);
    expect(find.text('Eğitim Modülleri'), findsOneWidget);
    expect(find.text('Hemşireliğin Temelleri'), findsWidgets);
    await tester.reveal(find.text('3 ders'), 200);
    expect(find.text('3 ders'), findsOneWidget);
    expect(find.text('%0 tamamlandı'), findsOneWidget);

    await tester.reveal(find.text('Eğitim Modülleri'), 200);
    await tester.reveal(
      find.byKey(const Key('home_module_nursing-fundamentals')),
      200,
    );
    await tester.tap(find.byKey(const Key('home_module_nursing-fundamentals')));
    await tester.pumpAndSettle();

    await tester.reveal(find.text('Dersler'), 200);
    expect(find.text('Dersler'), findsOneWidget);
    expect(find.text('Hemşirenin Temel Rolleri'), findsOneWidget);
    expect(find.text('Etik İlkeler'), findsOneWidget);
    await tester.reveal(find.text('Hemşirelik Bakım Süreci'), 200);
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
    await tester.reveal(find.text('Eğitim ve Savunuculuk'), 200);
    expect(find.text('Eğitim ve Savunuculuk'), findsOneWidget);

    await tester.reveal(find.text('Dersi Tamamla'), 200);
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
    await tester.reveal(correctAnswer, 150);
    await tester.tap(correctAnswer);
    await tester.pump();
    await tester.tap(find.text('Quizi Bitir'));
    await tester.pumpAndSettle();

    expect(find.text('Quiz Sonucu'), findsOneWidget);
    await tester.reveal(find.text('Doğru'), 200);
    expect(find.text('Doğru'), findsOneWidget);
    expect(find.text('Tekrar'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('%50'), findsOneWidget);

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
