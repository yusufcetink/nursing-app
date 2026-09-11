import 'helpers/ui_test_helpers.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_learning_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final variant in [
    (name: 'light', width: 390.0, scale: 1.0, brightness: Brightness.light),
    (name: 'dark', width: 390.0, scale: 1.0, brightness: Brightness.dark),
    (
      name: 'large-text',
      width: 320.0,
      scale: 1.6,
      brightness: Brightness.light,
    ),
  ]) {
    testWidgets('yedi ekran taşmaz ve eylemler erişilebilir: ${variant.name}', (
      tester,
    ) async {
      tester.view.physicalSize = Size(variant.width, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue =
          variant.brightness;
      tester.platformDispatcher.textScaleFactorTestValue = variant.scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          educationRepositoryProvider.overrideWithValue(
            FakeEducationRepository(),
          ),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(results: [testProfileQuizResult]),
          ),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(completedLessons: [testCompletedLesson]),
          ),
          quizRepositoryProvider.overrideWithValue(FakeQuizRepository()),
        ],
      );
      addTearDown(container.dispose);
      const captureKey = Key('design-capture');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RepaintBoundary(key: captureKey, child: App()),
        ),
      );
      await tester.pumpAndSettle();
      final imageContext = tester.element(find.byType(App));
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/illustrations/learning-book.png'),
          imageContext,
        );
        await precacheImage(
          const AssetImage('assets/illustrations/achievement-medal.png'),
          imageContext,
        );
      });
      await tester.pumpAndSettle();

      Future<void> inspect(String name) async {
        final visibleImages = tester
            .widgetList<Image>(find.byType(Image))
            .toList();
        await tester.runAsync(() async {
          for (final image in visibleImages) {
            await precacheImage(image.image, imageContext);
          }
        });
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$name: ${variant.name}',
        );
        if (const bool.fromEnvironment('CAPTURE_DESIGN')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(captureKey),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('build/design-preview/${variant.name}-$name.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      await inspect('01-login');
      await tester.ensureVisible(find.byKey(const Key('login_password_field')));
      await tester.tap(find.byTooltip('Şifreyi göster'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('login_password_field')),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isFalse,
      );
      expect(find.byTooltip('Şifreyi gizle'), findsOneWidget);
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'student@example.com', password: 'password123');
      await tester.pumpAndSettle();
      await inspect('02-home');
      await tester.reveal(
        find.byKey(const Key('home_module_nursing-fundamentals')),
        200,
      );
      await tester.tap(
        find.byKey(const Key('home_module_nursing-fundamentals')),
      );
      await tester.pumpAndSettle();
      await inspect('03-module');
      await tester.reveal(find.text('Hemşirenin Temel Rolleri'), 200);
      await tester.tap(find.text('Hemşirenin Temel Rolleri'));
      await tester.pumpAndSettle();
      await inspect('04-lesson');
      await tester.reveal(find.text("Quiz'e Geç"), 200);
      await tester.tap(find.text("Quiz'e Geç"));
      await tester.pumpAndSettle();
      final selection = (
        moduleId: testModule.id,
        lessonId: testLessons.first.id,
      );
      final controller = container.read(
        quizControllerProvider(selection).notifier,
      );
      controller.selectOption('care-1');
      await tester.pumpAndSettle();
      await inspect('05-quiz');
      await controller.submitAndContinue();
      controller.selectOption('advocacy-2');
      await controller.submitAndContinue();
      await tester.pumpAndSettle();
      await inspect('06-result');
      await tester.reveal(find.text('Derse Dön'), 200);
      expect(find.text('Derse Dön').hitTestable(), findsOneWidget);
      container.read(appRouterProvider).goNamed(AppRoutes.profile);
      await tester.pumpAndSettle();
      await inspect('07-profile');
      await tester.reveal(find.text('Çıkış Yap'), 200);
      expect(tester.takeException(), isNull);
      expect(find.text('Çıkış Yap').hitTestable(), findsOneWidget);
    });
  }
}
