import 'helpers/fake_activity_repository.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_theme.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/features/education/presentation/providers/lesson_completion_provider.dart';
import 'package:asli_app/features/education/presentation/widgets/learning_path_step.dart';
import 'package:asli_app/features/education/presentation/widgets/lesson_completion_sheet.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/progress/domain/models/progress_state.dart';
import 'package:asli_app/features/quiz/presentation/widgets/quiz_feedback_panel.dart';
import 'package:asli_app/shared/widgets/learning_motion.dart';
import 'package:asli_app/shared/widgets/learning_progress_display.dart';
import 'package:asli_app/shared/widgets/module_cover.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_learning_repositories.dart';
import 'helpers/ui_test_helpers.dart';

const _titles = [
  'Vital Bulgular',
  'Ağrı Yönetimi',
  'Hasta Güvenliği',
  'Enfeksiyon Kontrolü',
  'İlaç Uygulamaları',
  'Yara Bakımı',
];

class _CoverRepository implements EducationRepository {
  final _base = FakeEducationRepository();
  @override
  Future<Lesson> getLesson(String id) => _base.getLesson(id);
  @override
  Future<EducationModule> getModule(String id) async => EducationModule(
    id: testModule.id,
    title: _titles.first,
    description: 'Gözlemle, değerlendir, güvenle ilerle.',
    order: 1,
    lessonCount: testLessons.length,
    lessons: testLessons,
  );
  @override
  Future<List<EducationModule>> getModules() async => [
    for (final (index, title) in _titles.indexed)
      EducationModule(
        id: index == 0 ? testModule.id : 'module-$index',
        title: title,
        description: 'Güvenli bakım için bilgini adım adım geliştir.',
        order: index + 1,
        lessonCount: 3,
        lessons: const [],
      ),
  ];
}

class _FailingProgress implements ProgressRepository {
  @override
  Future<ProgressState> getProgress() async => ProgressState.initial();
  @override
  Future<CompletedLesson> completeLesson(String lessonId) async =>
      throw Exception('offline');
}

class _MissingCoverBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.startsWith('assets/illustrations/modules/')) {
      throw StateError('Missing cover');
    }
    return rootBundle.load(key);
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_DESIGN')) return;
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  final context = tester.element(find.byType(App));
  await tester.runAsync(() async {
    for (final image in images) {
      await precacheImage(image.image, context);
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('engagement-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/design-preview/engagement-$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<ProviderContainer> _app(
  WidgetTester tester, {
  ProgressRepository? progress,
}) async {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(restoredUser: FakeAuthRepository.user),
      ),
      educationRepositoryProvider.overrideWithValue(_CoverRepository()),
      progressRepositoryProvider.overrideWithValue(
        progress ??
            FakeProgressRepository(completedLessons: [testCompletedLesson]),
      ),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const RepaintBoundary(
        key: Key('engagement-capture'),
        child: App(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
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

  test(
    'altı konu Türkçe harf ve büyük/küçük harften bağımsız ayrışır',
    () async {
      final covers = _titles.map(NursingCover.forTitle).toSet();
      expect(covers.length, 6);
      expect(covers, isNot(contains(NursingCover.general)));
      expect(
        NursingCover.forTitle('İLAÇ UYGULAMALARI'),
        NursingCover.medication,
      );
      expect(NursingCover.forTitle('AGRI YONETIMI'), NursingCover.pain);
      expect(
        NursingCover.forTitle('Bilinmeyen yeni modül'),
        NursingCover.general,
      );
      for (final cover in covers) {
        expect(
          (await rootBundle.load(cover.assetPath!)).lengthInBytes,
          greaterThan(0),
        );
      }
    },
  );

  test('iki temanın metin ve buton çiftleri okunabilir kontrastta', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final s = theme.colorScheme;
      for (final pair in [
        (s.onSurface, s.surface),
        (s.onSurfaceVariant, s.surface),
        (s.onPrimary, s.primary),
        (s.onTertiaryContainer, s.tertiaryContainer),
        (s.onSecondaryContainer, s.secondaryContainer),
      ]) {
        final a = pair.$1.computeLuminance();
        final b = pair.$2.computeLuminance();
        expect(
          ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });

  testWidgets('kapak dosyası yoksa kitap fallback ve başlık çalışır', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DefaultAssetBundle(
          bundle: _MissingCoverBundle(),
          child: const Scaffold(
            body: Column(
              children: [
                ModuleCover(title: 'Vital Bulgular'),
                Text('Vital Bulgular'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => precacheImage(
        tester.widget<Image>(find.byType(Image).first).image,
        tester.element(find.byType(ModuleCover)),
        onError: (_, _) {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vital Bulgular'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Image) return false;
        final provider = widget.image is ResizeImage
            ? (widget.image as ResizeImage).imageProvider
            : widget.image;
        return provider is AssetImage &&
            provider.assetName == 'assets/illustrations/learning-book.png';
      }),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bilinmeyen ve sıfır progress, büyük metin ve azaltılmış hareket',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 844),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: ListView(
                children: const [
                  LearningProgressRing(value: .8, label: 'Quiz başarısı'),
                  LearningSegments(
                    value: null,
                    total: 0,
                    label: 'Bilinmeyen ilerleme',
                  ),
                  QuizFeedbackPanel(
                    correct: true,
                    title: '8 doğru yanıt',
                    message: 'Güzel yakaladın.',
                  ),
                  QuizFeedbackPanel(
                    correct: false,
                    title: 'Birlikte bakalım',
                    message: '2 yanlış yanıtın var.',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('%80'), findsOneWidget);
      expect(find.byType(LearningReveal), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  for (final variant in [
    (name: 'light', width: 390.0, scale: 1.0, brightness: Brightness.light),
    (name: 'dark', width: 390.0, scale: 1.0, brightness: Brightness.dark),
    (name: 'accessible', width: 320.0, scale: 2.0, brightness: Brightness.dark),
  ]) {
    testWidgets(
      'home, açık ders erişimi ve tamamlanma akışı: ${variant.name}',
      (tester) async {
        tester.view.physicalSize = Size(variant.width, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue =
            variant.brightness;
        tester.platformDispatcher.textScaleFactorTestValue = variant.scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final container = await _app(tester);
        final router = container.read(appRouterProvider);
        await _capture(tester, '${variant.name}-home');
        expect(tester.takeException(), isNull);
        router.goNamed(
          AppRoutes.educationModule,
          pathParameters: {AppRoutes.moduleIdParameter: testModule.id},
        );
        await tester.pumpAndSettle();
        await _capture(tester, '${variant.name}-module');
        await tester.reveal(find.text(testLessons.last.title), 180);
        expect(
          tester
              .widgetList<LearningPathStep>(find.byType(LearningPathStep))
              .any((step) => step.status == LessonStepStatus.locked),
          isFalse,
        );
        // A later lesson remains accessible even while an earlier lesson is current.
        await tester.tap(find.text(testLessons.last.title));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, contains(testLessons.last.id));
        router.goNamed(
          AppRoutes.lesson,
          pathParameters: {
            AppRoutes.moduleIdParameter: testModule.id,
            AppRoutes.lessonIdParameter: testLessons[1].id,
          },
        );
        await tester.pumpAndSettle();
        await tester.reveal(find.text('Dersi Tamamla'), 180);
        await tester.tap(find.text('Dersi Tamamla'));
        await tester.pumpAndSettle();
        expect(find.byType(LessonCompletionSheet), findsOneWidget);
        expect(
          container
              .read(lessonCompletionProvider(testModule.id))!
              .moduleCompleted,
          isFalse,
        );
        await _capture(tester, '${variant.name}-lesson-completed');
        expect(tester.takeException(), isNull);
        final next = find.descendant(
          of: find.byType(LessonCompletionSheet),
          matching: find.text('Sıradaki derse geç'),
        );
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, contains(testLessons.last.id));
        await tester.reveal(find.text('Dersi Tamamla'), 180);
        await tester.tap(find.text('Dersi Tamamla'));
        await tester.pumpAndSettle();
        expect(
          container
              .read(lessonCompletionProvider(testModule.id))!
              .moduleCompleted,
          isTrue,
        );
        expect(find.text('Modül tamamlandı'), findsOneWidget);
        await _capture(tester, '${variant.name}-module-completed');
        expect(tester.takeException(), isNull);
        final close = find.byTooltip('Derse dön');
        await tester.ensureVisible(close);
        await tester.tap(close);
        await tester.pumpAndSettle();
        router.goNamed(
          AppRoutes.lesson,
          pathParameters: {
            AppRoutes.moduleIdParameter: testModule.id,
            AppRoutes.lessonIdParameter: testLessons[1].id,
          },
        );
        await tester.pumpAndSettle();
        expect(find.byType(LessonCompletionSheet), findsNothing);
      },
    );
  }

  testWidgets(
    'kayıt hatasında completion göstermez ve tekrar deneme kullanılabilir',
    (tester) async {
      final container = await _app(tester, progress: _FailingProgress());
      container
          .read(appRouterProvider)
          .goNamed(
            AppRoutes.lesson,
            pathParameters: {
              AppRoutes.moduleIdParameter: testModule.id,
              AppRoutes.lessonIdParameter: testLessons[1].id,
            },
          );
      await tester.pumpAndSettle();
      await tester.reveal(find.text('Dersi Tamamla'), 180);
      await tester.tap(find.text('Dersi Tamamla'));
      await tester.pumpAndSettle();
      expect(find.byType(LessonCompletionSheet), findsNothing);
      await tester.reveal(find.text('Dersi Tamamla'), 120);
      final retryButton = find.ancestor(
        of: find.text('Dersi Tamamla'),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(retryButton).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
