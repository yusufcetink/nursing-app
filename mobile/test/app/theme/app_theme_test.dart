import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/app/theme/app_theme.dart';
import 'package:asli_app/app/theme/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    tester.binding.handlePlatformBrightnessChanged();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );
  });

  testWidgets('açık ve koyu seçimleri uygulamaya anında yansır', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.light);
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );

    await container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  test('tema seçimi yeni provider container ile geri yüklenir', () async {
    final preferences = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    await first
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    first.dispose();

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(restarted.dispose);
    expect(restarted.read(themeModeControllerProvider), ThemeMode.dark);
  });
}
