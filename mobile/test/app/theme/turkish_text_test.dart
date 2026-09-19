import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/auth/presentation/pages/register_page.dart';
import 'package:asli_app/features/content_management/presentation/pages/module_form_page.dart';

import '../../helpers/fake_auth_repository.dart';

const turkishText = 'ÇĞİÖŞÜ çğıöşü Iı İi Çağrı Şükrü Öğrenci';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
  });

  test('bundled Manrope contains every Turkish letter', () async {
    final data = await rootBundle.load('assets/fonts/Manrope.ttf');
    for (final code in 'ÇĞİÖŞÜçğıöşü'.runes) {
      expect(
        _glyph(data, code),
        greaterThan(0),
        reason:
            'Missing ${String.fromCharCode(code)} (U+${code.toRadixString(16)})',
      );
    }
  });

  for (final dark in [false, true]) {
    for (final page in [const RegisterPage(), const ModuleFormPage()]) {
      testWidgets('Turkish letters stay in ${page.runtimeType} dark=$dark', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: page,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final fields = find.byType(EditableText);
        final fieldCount = fields.evaluate().length;
        for (var index = 0; index < fieldCount; index++) {
          final finder = fields.at(index);
          final field = tester.widget<EditableText>(finder);
          if (field.keyboardType == TextInputType.number) continue;
          await tester.ensureVisible(finder);
          await tester.enterText(finder, turkishText);
          await tester.pump();
          expect(
            tester.widget<EditableText>(finder).controller.text,
            turkishText,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets(
      'Turkish typing and IME composition survives theme rebuild dark=$dark',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        Widget app(bool isDark) => MaterialApp(
          theme: isDark ? AppTheme.dark : AppTheme.light,
          home: Scaffold(body: TextField(controller: controller)),
        );
        await tester.pumpWidget(app(dark));
        await tester.showKeyboard(find.byType(TextField));
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: turkishText,
            selection: TextSelection.collapsed(offset: turkishText.length),
            composing: TextRange(start: 0, end: turkishText.length),
          ),
        );
        await tester.pump();
        expect(controller.text, turkishText);
        await tester.pumpWidget(app(!dark));
        await tester.pumpAndSettle();
        expect(controller.text, turkishText);
        await tester.enterText(find.byType(TextField), turkishText);
        expect(controller.text, turkishText);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

int _glyph(ByteData data, int code) {
  int u16(int offset) => data.getUint16(offset);
  int u32(int offset) => data.getUint32(offset);
  var cmap = 0;
  for (var i = 0; i < u16(4); i++) {
    final offset = 12 + i * 16;
    final tag = ascii.decode(
      List.generate(4, (j) => data.getUint8(offset + j)),
    );
    if (tag == 'cmap') cmap = u32(offset + 8);
  }
  if (cmap == 0) return 0;
  for (var i = 0; i < u16(cmap + 2); i++) {
    final record = cmap + 4 + i * 8;
    final platform = u16(record);
    if (platform != 0 && platform != 3) continue;
    final table = cmap + u32(record + 4);
    if (u16(table) == 12) {
      for (var j = 0; j < u32(table + 12); j++) {
        final group = table + 16 + j * 12;
        if (code >= u32(group) && code <= u32(group + 4)) {
          return u32(group + 8) + code - u32(group);
        }
      }
    }
    if (u16(table) != 4) continue;
    final count = u16(table + 6) ~/ 2;
    final ends = table + 14;
    final starts = ends + count * 2 + 2;
    final deltas = starts + count * 2;
    final ranges = deltas + count * 2;
    for (var j = 0; j < count; j++) {
      if (code < u16(starts + j * 2) || code > u16(ends + j * 2)) continue;
      final delta = u16(deltas + j * 2);
      final range = u16(ranges + j * 2);
      if (range == 0) return (code + delta) & 0xffff;
      final glyph = u16(
        ranges + j * 2 + range + 2 * (code - u16(starts + j * 2)),
      );
      return glyph == 0 ? 0 : (glyph + delta) & 0xffff;
    }
  }
  return 0;
}
