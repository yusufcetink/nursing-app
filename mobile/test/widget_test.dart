import 'helpers/fake_activity_repository.dart';
import 'helpers/ui_test_helpers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/features/education/presentation/pages/lesson_page.dart';
import 'package:asli_app/features/education/presentation/widgets/lesson_completion_sheet.dart';
import 'package:go_router/go_router.dart';
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
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository(),
          ),
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

    await tester.reveal(find.text('Eğitim modülleri'), 200);
    expect(find.text('Eğitim modülleri'), findsOneWidget);
    expect(find.text('Hemşireliğin Temelleri'), findsWidgets);
    await tester.reveal(find.text('0 / 3 ders'), 200);
    expect(find.text('0 / 3 ders'), findsOneWidget);
    expect(find.textContaining('Başla', findRichText: true), findsOneWidget);

    await tester.reveal(
      find.byKey(const Key('home_module_nursing-fundamentals')),
      200,
    );
    await tester.tap(find.byKey(const Key('home_module_nursing-fundamentals')));
    await tester.pumpAndSettle();

    await tester.reveal(find.text('Öğrenme yolculuğun'), 200);
    expect(find.text('Öğrenme yolculuğun'), findsOneWidget);
    expect(find.text('Hemşirenin Temel Rolleri'), findsOneWidget);
    await tester.reveal(find.text('Etik İlkeler'), 160);
    expect(find.text('Etik İlkeler'), findsOneWidget);
    await tester.reveal(find.text('Hemşirelik Bakım Süreci'), 200);
    expect(find.text('Hemşirelik Bakım Süreci'), findsOneWidget);

    await tester.reveal(find.text('Hemşirenin Temel Rolleri'), -160);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hemşirenin Temel Rolleri'));
    await tester.pumpAndSettle();

    expect(
      find.text('Hemşirelik uygulamasındaki temel rol ve sorumluluklar.'),
      findsOneWidget,
    );
    expect(find.text('8 dk'), findsOneWidget);
    expect(find.text('Bakım Verme Rolü'), findsOneWidget);
    await tester.reveal(find.text('Eğitim ve Savunuculuk'), 200);
    expect(find.text('Eğitim ve Savunuculuk'), findsOneWidget);

    await tester.reveal(find.text('Dersi Tamamla'), 200);
    await tester.tap(find.text('Dersi Tamamla'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonCompletionSheet), findsOneWidget);
    final completionAction = find.descendant(
      of: find.byType(LessonCompletionSheet),
      matching: find.text("Quizlere Geç"),
    );
    await tester.ensureVisible(completionAction);
    await tester.tap(completionAction);
    await tester.pumpAndSettle();

    await tester.reveal(find.text('Quiz’e Başla'), 200);
    await tester.tap(find.text('Quiz’e Başla'));
    await tester.pumpAndSettle();

    expect(find.text('Soru 1 / 2'), findsOneWidget);
    expect(
      find.text('Hemşirenin bakım verme rolünün temel amacı hangisidir?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Bakım kararlarını yalnızca ekip adına vermek'));
    await tester.pump();
    await tester.tap(find.text('Cevabı Onayla'));
    await tester.pumpAndSettle();

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
    await tester.tap(find.text('Cevabı Onayla ve Bitir'));
    await tester.pumpAndSettle();

    expect(find.text('Quiz Sonucu'), findsOneWidget);
    await tester.reveal(find.text('Doğru'), 200);
    expect(find.text('Doğru'), findsOneWidget);
    expect(find.text('Yanlış'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
    await tester.reveal(find.text('%50'), -160);
    expect(find.text('%50'), findsOneWidget);

    expect(find.text('Derse Dön'), findsNothing);
    await tester.tap(find.text('Sıradaki Derse Geç'));
    await tester.pumpAndSettle();
    expect(find.text('Etik İlkeler'), findsOneWidget);
    expect(find.text('Quiz Sonucu'), findsNothing);
    expect(
      GoRouter.of(tester.element(find.byType(LessonPage))).canPop(),
      isFalse,
    );
    await tester.tap(find.text('Eğitim'));
    await tester.pumpAndSettle();
    await tester.reveal(find.text('1 / 3 ders'), 200);
    expect(find.text('1 / 3 ders'), findsOneWidget);
  });
}
