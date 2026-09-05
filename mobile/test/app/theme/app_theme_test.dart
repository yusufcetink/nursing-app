import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/app/theme/app_theme.dart';

void main() {
  test('light ve dark Material 3 temaları doğru parlaklığı kullanır', () {
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.useMaterial3, isTrue);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(
      AppTheme.dark.colorScheme.onSurface,
      isNot(AppTheme.dark.colorScheme.surface),
    );
  });

  testWidgets('uygulama sistem tema modunu takip eder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);
  });
}
