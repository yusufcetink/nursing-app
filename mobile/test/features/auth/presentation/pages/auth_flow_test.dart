import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/auth/domain/models/authenticated_user.dart';
import 'package:asli_app/features/auth/domain/models/user_role.dart';
import 'package:asli_app/features/content_management/data/content_management_repository.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_content_management_repository.dart';
import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  testWidgets('login, şifre sıfırlama ve kayıt akışları çalışır', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Giriş Yap'));
    await tester.pump();
    expect(find.text('Email alanı zorunludur.'), findsOneWidget);
    expect(find.text('Şifre alanı zorunludur.'), findsOneWidget);

    await tester.tap(find.text('Şifremi unuttum'));
    await tester.pumpAndSettle();
    expect(find.text('Şifrenizi sıfırlayın'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('forgot_password_email_field')),
      'student@example.com',
    );
    await tester.tap(find.text('Sıfırlama Emaili Gönder'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni şifre oluşturun'), findsOneWidget);
    expect(
      find.text('Hesap uygunsa şifre sıfırlama emaili gönderildi.'),
      findsOneWidget,
    );
    expect(repository.forgotPasswordCallCount, 1);

    final returnToLoginButton = find.text('Giriş ekranına dön');
    await tester.ensureVisible(returnToLoginButton);
    await tester.pumpAndSettle();
    await tester.tap(returnToLoginButton);
    await tester.pumpAndSettle();
    final openRegisterButton = find.text('Hesabınız yok mu? Kayıt Ol');
    await tester.ensureVisible(openRegisterButton);
    await tester.pumpAndSettle();
    await tester.tap(openRegisterButton);
    await tester.pumpAndSettle();
    expect(find.text('Hesap oluşturun'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register_first_name_field')),
      'Ayşe',
    );
    await tester.enterText(
      find.byKey(const Key('register_last_name_field')),
      'Yılmaz',
    );
    await tester.enterText(
      find.byKey(const Key('register_email_field')),
      'ayse@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_confirmation_field')),
      'password456',
    );
    final registerButton = find.widgetWithText(FilledButton, 'Kayıt Ol');
    await tester.ensureVisible(registerButton);
    await tester.pumpAndSettle();
    await tester.tap(registerButton);
    await tester.pump();
    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register_password_confirmation_field')),
      'password123',
    );
    await tester.ensureVisible(registerButton);
    await tester.pumpAndSettle();
    await tester.tap(registerButton);
    await tester.pumpAndSettle();
    expect(find.text('Email adresinizi doğrulayın'), findsOneWidget);
    expect(repository.registerCallCount, 1);

    expect(find.text('Yeniden gönder (60 sn)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 60));
    await tester.tap(find.text('Doğrulama Emailini Yeniden Gönder'));
    await tester.pumpAndSettle();
    expect(repository.resendVerificationCallCount, 1);

    await tester.enterText(
      find.byKey(const Key('verification_code_field')),
      '123456',
    );
    await tester.tap(find.text('Emaili Doğrula'));
    await tester.pumpAndSettle();
    expect(repository.verifyEmailCallCount, 1);
    expect(find.text('Tekrar hoş geldiniz'), findsOneWidget);
  });

  testWidgets('geçerli sessionı geri yükler ve auth route erişimini engeller', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(restoredUser: FakeAuthRepository.user),
        ),
        educationRepositoryProvider.overrideWithValue(
          FakeEducationRepository(),
        ),
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eğitim Modülleri'), findsOneWidget);
    expect(find.text('Tekrar hoş geldiniz'), findsNothing);
    expect(find.text('İçerik'), findsNothing);

    container.read(appRouterProvider).go(AppRoutes.loginPath);
    await tester.pumpAndSettle();

    expect(find.text('Eğitim Modülleri'), findsOneWidget);
    expect(find.text('Tekrar hoş geldiniz'), findsNothing);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('ayse@example.com'), findsOneWidget);
  });

  testWidgets('girişsiz kullanıcı protected route erişiminde login görür', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go(AppRoutes.profilePath);
    await tester.pumpAndSettle();

    expect(find.text('Tekrar hoş geldiniz'), findsOneWidget);
    expect(find.text('Profil'), findsNothing);
  });

  testWidgets('ContentEditor içerik sekmesini görür ve modül oluşturur', (
    tester,
  ) async {
    final editor = AuthenticatedUser(
      id: 'editor-id',
      firstName: 'İçerik',
      lastName: 'Editörü',
      email: 'editor@example.com',
      roles: const [UserRole.contentEditor],
    );
    final contentRepository = FakeContentManagementRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(restoredUser: editor),
          ),
          educationRepositoryProvider.overrideWithValue(
            FakeEducationRepository(),
          ),
          contentManagementRepositoryProvider.overrideWithValue(
            contentRepository,
          ),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(),
          ),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('İçerik'), findsOneWidget);
    await tester.tap(find.text('İçerik'));
    await tester.pumpAndSettle();
    expect(find.text('İçerik Yönetimi'), findsOneWidget);
    expect(find.text('Taslak Modül'), findsOneWidget);

    await tester.tap(find.byKey(const Key('create_module_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('module_title_field')),
      'Yeni Modül',
    );
    await tester.enterText(
      find.byKey(const Key('module_description_field')),
      'Yeni açıklama',
    );
    await tester.enterText(find.byKey(const Key('module_order_field')), '2');
    await tester.tap(find.byKey(const Key('save_module_button')));
    await tester.pumpAndSettle();

    expect(contentRepository.createModuleCallCount, 1);
    expect(find.text('Yeni Modül'), findsOneWidget);
    expect(find.text('Modül oluşturuldu.'), findsOneWidget);

    final deleteCreatedModule = find.byKey(
      const Key('delete_module_created-module'),
    );
    await tester.tap(deleteCreatedModule);
    await tester.pumpAndSettle();
    expect(find.text('Modül silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(contentRepository.deleteModuleCallCount, 0);

    await tester.tap(deleteCreatedModule);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(contentRepository.deleteModuleCallCount, 1);
    expect(find.text('Yeni Modül'), findsNothing);

    await tester.tap(find.text('Taslak Modül'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taslak Ders'));
    await tester.pumpAndSettle();
    final manageQuizButton = find.byKey(const Key('manage_quiz_button'));
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(manageQuizButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_question_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('option_0_text_field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('question_prompt_field')),
      'Yeni soru?',
    );
    for (var index = 0; index < 2; index++) {
      await tester.enterText(
        find.byKey(Key('option_${index}_text_field')),
        '${index + 1}. seçenek',
      );
    }
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    for (var index = 2; index < 4; index++) {
      await tester.enterText(
        find.byKey(Key('option_${index}_text_field')),
        '${index + 1}. seçenek',
      );
    }
    await tester.tap(find.byKey(const Key('correct_option_2')));
    final saveQuestionButton = find.byKey(const Key('save_question_button'));
    await tester.ensureVisible(saveQuestionButton);
    await tester.tap(saveQuestionButton);
    await tester.pumpAndSettle();

    expect(contentRepository.createQuestionCallCount, 1);
    expect(contentRepository.createOptionCallCount, 4);
    expect(contentRepository.correctOptionCount, 1);
  });
}
