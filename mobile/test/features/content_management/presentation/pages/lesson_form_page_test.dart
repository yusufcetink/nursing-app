import 'package:asli_app/features/content_management/data/content_management_repository.dart';
import 'package:asli_app/features/content_management/presentation/pages/lesson_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_content_management_repository.dart';

void main() {
  testWidgets('metin düzenleme dialogu vazgeç ve geri ile güvenle kapanır', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentManagementRepositoryProvider.overrideWithValue(
            FakeContentManagementRepository(),
          ),
        ],
        child: const MaterialApp(
          home: LessonFormPage(
            moduleId: 'draft-module',
            lessonId: 'draft-lesson',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Düzenle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Düzenle'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
