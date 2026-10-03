import 'package:asli_app/app/theme/app_theme.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/features/education/presentation/widgets/lesson_content_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Long learning blocks remain readable dark=$dark scale=$scale',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 700));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          const types = [
            LessonContentBlockType.callout,
            LessonContentBlockType.comparison,
            LessonContentBlockType.caseStudy,
            LessonContentBlockType.summary,
            LessonContentBlockType.recall,
          ];
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    for (final type in types)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: LessonContentCard(
                          block: LessonContentBlock(
                            id: type.name,
                            lessonId: 'lesson',
                            blockType: type,
                            sortOrder: 0,
                            textContent:
                                '${type.name} başlığı\nHastanın durumunu dikkatle değerlendir ve gözlem bulgularını ekip arkadaşlarınla paylaş.\n${type.name} son satır',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
          for (final type in types) {
            await tester.scrollUntilVisible(
              find.text('${type.name} son satır'),
              160,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(find.text('${type.name} son satır'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
