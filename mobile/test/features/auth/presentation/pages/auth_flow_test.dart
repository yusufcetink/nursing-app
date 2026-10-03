import 'package:asli_app/features/leaderboard/data/leaderboard_repository.dart';
import 'package:asli_app/features/leaderboard/presentation/leaderboard_providers.dart';

import '../../../../helpers/fake_activity_repository.dart';

import 'dart:async';

import '../../../../helpers/ui_test_helpers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/auth/domain/models/authenticated_user.dart';
import 'package:asli_app/features/auth/domain/models/user_role.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/content_management/data/content_management_repository.dart';
import 'package:asli_app/features/content_management/presentation/pages/lesson_form_page.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/home/presentation/pages/home_page.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/core/network/session_expiration.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_content_management_repository.dart';
import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  testWidgets('session expiration redirects the protected screen to login', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(restoredUser: FakeAuthRepository.user),
        ),
        educationRepositoryProvider.overrideWithValue(
          FakeEducationRepository(),
        ),
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        leaderboardCoursesProvider.overrideWith((ref) async => const []),
        leaderboardProvider.overrideWith(
          (ref, selection) async => const LeaderboardData(
            entries: [],
            totalUsers: 0,
            offset: 0,
            limit: 20,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).state.uri.path,
      AppRoutes.homePath,
    );
    container.read(sessionExpirationProvider.notifier).notify();
    await tester.pumpAndSettle();
    expect(container.read(authControllerProvider).value, isNull);
    expect(
      container.read(appRouterProvider).state.uri.path,
      AppRoutes.loginPath,
    );
    expect(find.byKey(const Key('login_remember_me')), findsOneWidget);
  });

  testWidgets('yeni ders ekranı blok oluşturma yönlendirmesini gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository(),
          ),
          contentManagementRepositoryProvider.overrideWithValue(
            FakeContentManagementRepository(),
          ),
        ],
        child: const MaterialApp(
          home: LessonFormPage(moduleId: 'draft-module'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('İçerik blokları, ders oluşturulduktan sonra eklenebilir.'),
      findsOneWidget,
    );
  });

  testWidgets('login, şifre sıfırlama ve kayıt akışları çalışır', (
    tester,
  ) async {
    final loginGate = Completer<void>();
    final repository = FakeAuthRepository(loginGate: loginGate.future);
    final container = ProviderContainer(
      overrides: [
        activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
        authRepositoryProvider.overrideWithValue(repository),
        educationRepositoryProvider.overrideWithValue(
          FakeEducationRepository(),
        ),
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        leaderboardCoursesProvider.overrideWith((ref) async => const []),
        leaderboardProvider.overrideWith(
          (ref, selection) async => const LeaderboardData(
            entries: [],
            totalUsers: 0,
            offset: 0,
            limit: 20,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    final rememberMe = tester.widget<CheckboxListTile>(
      find.byKey(const Key('login_remember_me')),
    );
    expect(rememberMe.value, isTrue);
    await tester.ensureVisible(find.byKey(const Key('login_remember_me')));
    await tester.tap(find.byKey(const Key('login_remember_me')));
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('login_remember_me')))
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('login_remember_me')));
    await tester.pump();

    await tester.ensureVisible(find.text('Giriş Yap'));
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
    await tester.tap(find.text('Sıfırlama Kodu Gönder'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni şifre oluşturun'), findsOneWidget);
    expect(
      find.text('Hesap uygunsa 6 haneli sıfırlama kodu gönderildi.'),
      findsOneWidget,
    );
    expect(repository.forgotPasswordCallCount, 1);

    await tester.enterText(
      find.byKey(const Key('reset_password_code_field')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const Key('reset_password_new_password_field')),
      'SecurePass1!',
    );
    await tester.enterText(
      find.byKey(const Key('reset_password_confirmation_field')),
      'SecurePass1!',
    );
    await tester.ensureVisible(find.text('Şifreyi Güncelle'));
    await tester.tap(find.text('Şifreyi Güncelle'));
    await tester.pump();
    expect(repository.resetPasswordCallCount, 1);
    expect(repository.loginCallCount, 1);
    expect(find.text('Şifreniz güncellendi. Giriş yapılıyor…'), findsOneWidget);
    expect(find.text('Giriş ekranına dön'), findsNothing);
    expect(repository.lastLoginRequest?.email, 'student@example.com');
    expect(repository.lastLoginRequest?.password, 'SecurePass1!');

    loginGate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(
      GoRouter.of(tester.element(find.byType(HomePage))).canPop(),
      isFalse,
    );

    await container.read(authControllerProvider.notifier).logout();
    container.read(appRouterProvider).go(AppRoutes.loginPath);
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
    expect(find.text('Bilgin büyüsün.\nGüvenin artsın.'), findsOneWidget);
  });

  testWidgets('geçerli sessionı geri yükler ve auth route erişimini engeller', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(restoredUser: FakeAuthRepository.user),
        ),
        educationRepositoryProvider.overrideWithValue(
          FakeEducationRepository(),
        ),
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        leaderboardCoursesProvider.overrideWith((ref) async => const []),
        leaderboardProvider.overrideWith(
          (ref, selection) async => const LeaderboardData(
            entries: [],
            totalUsers: 0,
            offset: 0,
            limit: 20,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    await tester.reveal(find.text('Eğitim modülleri'), 200);
    expect(find.text('Eğitim modülleri'), findsOneWidget);
    expect(find.text('Bilgin büyüsün.\nGüvenin artsın.'), findsNothing);
    expect(find.text('İçerik'), findsNothing);

    container.read(appRouterProvider).go(AppRoutes.loginPath);
    await tester.pumpAndSettle();

    await tester.reveal(find.text('Eğitim modülleri'), 200);
    expect(find.text('Eğitim modülleri'), findsOneWidget);
    expect(find.text('Bilgin büyüsün.\nGüvenin artsın.'), findsNothing);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('ayse@example.com'), findsOneWidget);
  });

  testWidgets(
    'reset sonrası otomatik login hatasında mesajla login ekranına döner',
    (tester) async {
      const loginError = AuthException('Otomatik giriş başarısız.');
      final repository = FakeAuthRepository(loginError: loginError);
      final container = ProviderContainer(
        overrides: [
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository(),
          ),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pumpAndSettle();

      container
          .read(appRouterProvider)
          .go('${AppRoutes.resetPasswordPath}?email=student%40example.com');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reset_password_code_field')),
        '123456',
      );
      await tester.enterText(
        find.byKey(const Key('reset_password_new_password_field')),
        'SecurePass1!',
      );
      await tester.enterText(
        find.byKey(const Key('reset_password_confirmation_field')),
        'SecurePass1!',
      );
      await tester.ensureVisible(find.text('Şifreyi Güncelle'));
      await tester.tap(find.text('Şifreyi Güncelle'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(repository.resetPasswordCallCount, 1);
      expect(repository.loginCallCount, 1);
      expect(repository.lastLoginRequest?.email, 'student@example.com');
      expect(repository.lastLoginRequest?.password, 'SecurePass1!');
      expect(find.text('Bilgin büyüsün.\nGüvenin artsın.'), findsOneWidget);
      expect(
        find.text(
          'Şifreniz güncellendi, yeni şifrenizle giriş yapabilirsiniz.',
        ),
        findsOneWidget,
      );
      expect(find.text(loginError.message), findsNothing);
      expect(
        GoRouter.of(tester.element(find.byKey(const Key('login_email_field'))))
            .canPop(),
        isFalse,
      );
    },
  );

  testWidgets('girişsiz kullanıcı protected route erişiminde login görür', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
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

    expect(find.text('Bilgin büyüsün.\nGüvenin artsın.'), findsOneWidget);
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
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository(),
          ),
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
          leaderboardCoursesProvider.overrideWith((ref) async => const []),
          leaderboardProvider.overrideWith(
            (ref, selection) async => const LeaderboardData(
              entries: [],
              totalUsers: 0,
              offset: 0,
              limit: 20,
            ),
          ),
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
    expect(
      find.text('Taslak olarak kaydedildi, öğrencilere görünmez'),
      findsOneWidget,
    );
    expect(contentRepository.modules.last.isPublished, isFalse);

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
    await tester.ensureVisible(manageQuizButton);
    await tester.pumpAndSettle();
    await tester.tap(manageQuizButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quiz-id')));
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
