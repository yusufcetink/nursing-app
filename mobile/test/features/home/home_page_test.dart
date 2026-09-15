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
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';

import '../../helpers/fake_activity_repository.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_learning_repositories.dart';
import '../../helpers/ui_test_helpers.dart';

class _Modules implements EducationRepository {
  @override
  Future<Lesson> getLesson(String id) =>
      FakeEducationRepository().getLesson(id);
  @override
  Future<EducationModule> getModule(String id) =>
      FakeEducationRepository().getModule(id);
  @override
  Future<List<EducationModule>> getModules() async => [
    for (final (i, title) in [
      'Vital Bulgular',
      'Hasta Güvenliği',
      'Ağrı Yönetimi',
    ].indexed)
      EducationModule(
        id: i == 0 ? testModule.id : 'module-$i',
        title: title,
        description: 'Güvenli bakımın temel adımları.',
        order: i,
        lessonCount: 3,
        lessons: const [],
      ),
  ];
}

void main() {
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
    (name: 'small', width: 320.0, scale: 1.0, brightness: Brightness.light),
    (name: 'large-text', width: 320.0, scale: 2.0, brightness: Brightness.dark),
  ]) {
    testWidgets('Home layout and existing actions ${variant.name}', (
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
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository(),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(restoredUser: FakeAuthRepository.user),
          ),
          educationRepositoryProvider.overrideWithValue(_Modules()),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(completedLessons: [testCompletedLesson]),
          ),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RepaintBoundary(key: Key('home-capture'), child: App()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Merhaba, Ayşe'), findsOneWidget);
      expect(find.text('AY'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_HOME')) {
        final context = tester.element(find.byType(App));
        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        await tester.runAsync(() async {
          for (final image in images) {
            await precacheImage(image.image, context);
          }
        });
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('home-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/home-reference-preview/${variant.name}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      final more = find.text('Tümünü gör');
      await tester.reveal(more, 180);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home_module_shelf')), findsNothing);
      final tile = find.byKey(Key('home_module_${testModule.id}'));
      await tester.reveal(tile, 180);
      expect(find.text('1 / 3 ders'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);
      expect(router.state.uri.path, '/education/${testModule.id}');
      router.goNamed(AppRoutes.home);
      await tester.pumpAndSettle();
      await tester.reveal(find.byTooltip('Profilini aç'), -180);
      await tester.tap(find.byTooltip('Profilini aç'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.profilePath);
      expect(tester.takeException(), isNull);
    });
  }
}
