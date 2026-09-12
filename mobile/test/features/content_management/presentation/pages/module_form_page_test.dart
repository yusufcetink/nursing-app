import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/features/content_management/data/content_management_repository.dart';
import 'package:asli_app/features/content_management/presentation/pages/module_form_page.dart';

import '../../../../helpers/fake_content_management_repository.dart';

void main() {
  for (final editing in [false, true]) {
    for (final published in [false, true]) {
      testWidgets(
        'modül editing=$editing published=$published kaydı doğru mesajı ve durumu korur',
        (tester) async {
          final repository = FakeContentManagementRepository();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('Modüller')),
              ),
              GoRoute(
                path: '/form',
                builder: (_, _) =>
                    ModuleFormPage(moduleId: editing ? 'draft-module' : null),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                contentManagementRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          router.push('/form');
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('module_title_field')),
            'Yeni modül',
          );
          await tester.enterText(
            find.byKey(const Key('module_description_field')),
            'Açıklama',
          );
          final toggle = find.byKey(const Key('module_published_switch'));
          expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
          if (published) {
            await tester.ensureVisible(toggle);
            await tester.tap(toggle);
            await tester.pump();
          }
          final save = find.byKey(const Key('save_module_button'));
          await tester.ensureVisible(save);
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(
            find.text(
              published
                  ? 'Modül yayınlandı, öğrencilere görünür.'
                  : 'Taslak olarak kaydedildi, öğrencilere görünmez',
            ),
            findsOneWidget,
          );
          expect(repository.modules.last.isPublished, published);
          expect(
            editing
                ? repository.updateModuleCallCount
                : repository.createModuleCallCount,
            1,
          );
          expect(router.canPop(), isFalse);
        },
      );
    }
  }
}
