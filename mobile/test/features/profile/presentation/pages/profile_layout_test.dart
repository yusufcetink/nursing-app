import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/app/theme/theme_mode_controller.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';

import '../../../../helpers/fake_activity_repository.dart';
import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_learning_repositories.dart';
import '../../../../helpers/ui_test_helpers.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('profil görünümü dark=$dark text=$scale', (tester) async {
        tester.view.physicalSize = scale == 1
            ? const Size(390, 844)
            : const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final container = ProviderContainer(
          overrides: [
            activityRepositoryProvider.overrideWithValue(
              FakeActivityRepository(),
            ),
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(restoredUser: FakeAuthRepository.user),
            ),
            educationRepositoryProvider.overrideWithValue(
              FakeEducationRepository(),
            ),
            progressRepositoryProvider.overrideWithValue(
              FakeProgressRepository(),
            ),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const RepaintBoundary(
              key: Key('profile-capture'),
              child: App(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          final label = tester.renderObject<RenderParagraph>(
            find.text('Sistem'),
          );
          expect(
            label.getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 6),
            ),
            hasLength(1),
          );
        }
        if (const bool.fromEnvironment('CAPTURE_PROFILE') && scale == 1) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('profile-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/profile-preview/${dark ? "dark" : "light"}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.reveal(find.text('Koyu'), 120);
        await tester.tap(find.text('Koyu'));
        await tester.pumpAndSettle();
        expect(container.read(themeModeControllerProvider), ThemeMode.dark);
        expect(tester.takeException(), isNull);
        for (final label in [
          'Ortalama başarı',
          'Küçük başarıların',
          'Quiz Sonuçları',
          'Çıkış Yap',
        ]) {
          await tester.reveal(find.text(label), 160);
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Çıkış Yap').hitTestable(), findsOneWidget);
      });
    }
  }
}
