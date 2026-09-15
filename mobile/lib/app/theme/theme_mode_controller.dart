import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModePreferenceKey = 'theme_mode';

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

final class ThemeModeController extends Notifier<ThemeMode> {
  Future<void> _pendingWrite = Future.value();

  @override
  ThemeMode build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return _decode(preferences?.getString(_themeModePreferenceKey));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    final previous = state;
    state = mode;
    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences == null) return;
    _pendingWrite = _pendingWrite.then((_) async {
      if (state != mode) return;
      try {
        await preferences.setString(_themeModePreferenceKey, mode.name);
      } catch (_) {
        if (state == mode) state = previous;
      }
    });
    await _pendingWrite;
  }

  ThemeMode _decode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
