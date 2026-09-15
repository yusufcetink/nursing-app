import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/theme_mode_controller.dart';
import 'package:asli_app/app/theme/app_theme.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/storage/token_storage.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/presentation/pages/lesson_page.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/education/presentation/widgets/lesson_completion_sheet.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';

import '../../helpers/fake_activity_repository.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_learning_repositories.dart';
import '../../helpers/ui_test_helpers.dart';

class _UnavailableMediaToken implements TokenStorage {
  @override
  Future<String?> read() async => throw StateError('Media unavailable');
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> delete() async {}
}

class _MediaLessonRepository implements EducationRepository {
  @override
  Future<EducationModule> getModule(String id) async => testModule;
  @override
  Future<List<EducationModule>> getModules() async => [testModule];
  @override
  Future<Lesson> getLesson(String id) async => Lesson(
    id: id,
    educationModuleId: testModule.id,
    title: 'Medya dersi',
    description: 'İçerik sırası',
    estimatedDurationMinutes: 8,
    order: 1,
    blocks: [
      LessonContentBlock(
        id: 'heading',
        lessonId: id,
        blockType: LessonContentBlockType.heading,
        sortOrder: 0,
        textContent: 'İlk başlık',
      ),
      LessonContentBlock(
        id: 'text',
        lessonId: id,
        blockType: LessonContentBlockType.text,
        sortOrder: 1,
        textContent: 'İlk açıklama',
      ),
      for (final (i, type) in [
        LessonMediaType.image,
        LessonMediaType.video,
      ].indexed)
        LessonContentBlock(
          id: 'media-$i',
          lessonId: id,
          blockType: i == 0
              ? LessonContentBlockType.image
              : LessonContentBlockType.video,
          sortOrder: i + 2,
          media: LessonMedia(
            id: 'media-$i',
            lessonId: id,
            originalFileName: 'İçerik $i',
            contentType: i == 0 ? 'image/png' : 'video/mp4',
            mediaType: type,
            sizeBytes: 100,
            sortOrder: i,
          ),
        ),
      LessonContentBlock(
        id: 'last',
        lessonId: id,
        blockType: LessonContentBlockType.heading,
        sortOrder: 4,
        textContent: 'Son başlık',
      ),
    ],
  );
}

void main() {
  testWidgets(
    'media failure preserves image video block order and completion action',
    (tester) async {
      final client = ApiClient(tokenStorage: _UnavailableMediaToken());
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityRepositoryProvider.overrideWithValue(
              FakeActivityRepository(),
            ),
            educationRepositoryProvider.overrideWithValue(
              _MediaLessonRepository(),
            ),
            progressRepositoryProvider.overrideWithValue(
              FakeProgressRepository(),
            ),
            apiClientProvider.overrideWithValue(client),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: LessonPage(
              moduleId: testModule.id,
              lessonId: testLessons.first.id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.reveal(find.text('Görsel yüklenemedi.'), 140);
      expect(tester.takeException(), isNull);
      await tester.reveal(find.text('Video yüklenemedi.'), 140);
      expect(
        tester.getTopLeft(find.text('İçerik 0')).dy,
        lessThan(tester.getTopLeft(find.text('Video yüklenemedi.')).dy),
      );
      await tester.reveal(find.text('Son başlık'), 140);
      expect(
        tester.getTopLeft(find.text('İçerik 1')).dy,
        lessThan(tester.getTopLeft(find.text('Son başlık')).dy),
      );
      await tester.reveal(find.text('Dersi Tamamla'), 140);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Dersi Tamamla'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final variant in [
    (name: 'light', mode: ThemeMode.light, width: 390.0, scale: 1.0),
    (name: 'dark', mode: ThemeMode.dark, width: 390.0, scale: 1.0),
    (name: 'accessible', mode: ThemeMode.dark, width: 320.0, scale: 2.0),
  ]) {
    testWidgets('lesson V2 content order completion and quiz ${variant.name}', (
      tester,
    ) async {
      tester.view.physicalSize = Size(variant.width, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = variant.scale;
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
          quizRepositoryProvider.overrideWithValue(FakeQuizRepository()),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(themeModeControllerProvider.notifier)
          .setThemeMode(variant.mode);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RepaintBoundary(
            key: Key('lesson-capture'),
            child: App(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);
      router.pushNamed(
        AppRoutes.lesson,
        pathParameters: {
          AppRoutes.moduleIdParameter: testModule.id,
          AppRoutes.lessonIdParameter: testLessons.first.id,
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('0 / 3 ders tamamlandı'), findsOneWidget);
      expect(find.text('8 dk'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_LESSON')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('lesson-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/lesson-reference-preview/${variant.name}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.reveal(find.text('Bütüncül ve güvenli bakım.'), 140);
      expect(
        tester.getTopLeft(find.text('Bakım Verme Rolü')).dy,
        lessThan(tester.getTopLeft(find.text('Bütüncül ve güvenli bakım.')).dy),
      );
      await tester.reveal(find.text('Eğitim ve Savunuculuk'), 140);
      expect(tester.takeException(), isNull);
      await tester.reveal(find.text('Dersi Tamamla'), 140);
      await tester.tap(find.text('Dersi Tamamla'));
      await tester.pumpAndSettle();
      expect(
        container.read(lessonCompletedProvider(testLessons.first.id)),
        isTrue,
      );
      expect(find.byType(LessonCompletionSheet), findsOneWidget);
      final next = find.descendant(
        of: find.byType(LessonCompletionSheet),
        matching: find.text("Quiz'e Geç"),
      );
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, endsWith('/${testLessons.first.id}/quiz'));
      expect(tester.takeException(), isNull);
    });
  }
}
