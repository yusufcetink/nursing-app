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
import 'package:asli_app/features/education/presentation/widgets/learning_path_step.dart';
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
  Future<List<EducationModule>> getModules() async => [
    await getModule(testModule.id),
  ];
  @override
  Future<EducationModule> getModule(String id) async => EducationModule(
    id: testModule.id,
    title: 'Vital Bulgular',
    description: 'Gözlemle, değerlendir, güvenle ilerle.',
    order: 1,
    lessonCount: testLessons.length,
    lessons: testLessons,
  );
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
    (name: 'accessible', width: 320.0, scale: 2.0, brightness: Brightness.dark),
  ]) {
    testWidgets('module states and published lesson access ${variant.name}', (
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
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RepaintBoundary(
            key: Key('module-capture'),
            child: App(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);
      void openModule() => router.goNamed(
        AppRoutes.educationModule,
        pathParameters: {AppRoutes.moduleIdParameter: testModule.id},
      );
      router.pushNamed(
        AppRoutes.educationModule,
        pathParameters: {AppRoutes.moduleIdParameter: testModule.id},
      );
      await tester.pumpAndSettle();
      expect(find.text('Vital Bulgular'), findsOneWidget);
      expect(find.text('1 / 3 ders tamamlandı'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_MODULE')) {
        final context = tester.element(find.byType(App));
        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        await tester.runAsync(() async {
          for (final image in images) {
            await precacheImage(image.image, context);
          }
        });
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('module-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/module-reference-preview/${variant.name}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.reveal(find.text('Derse devam et'), 160);
      expect(tester.takeException(), isNull);
      final current = tester
          .widgetList<LearningPathStep>(find.byType(LearningPathStep))
          .where((step) => step.status == LessonStepStatus.current)
          .single;
      expect(current.lesson.id, testLessons[1].id);
      await tester.tap(find.text('Derse devam et'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, contains(testLessons[1].id));
      openModule();
      await tester.pumpAndSettle();
      await tester.reveal(find.text(testLessons.last.title), 160);
      final next = tester
          .widgetList<LearningPathStep>(find.byType(LearningPathStep))
          .where((step) => step.lesson.id == testLessons.last.id)
          .single;
      expect(next.status, LessonStepStatus.next);
      await tester.tap(find.text(testLessons.last.title));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, contains(testLessons.last.id));
      expect(tester.takeException(), isNull);
    });
  }
}
