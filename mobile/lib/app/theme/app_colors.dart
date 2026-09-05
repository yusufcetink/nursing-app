import 'package:flutter/material.dart';

abstract final class AppColors {
  static const lightPrimary = Color(0xFF006A67);
  static const lightSecondary = Color(0xFF476561);
  static const lightTertiary = Color(0xFF52617D);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBackground = Color(0xFFF5F8F7);

  static const darkPrimary = Color(0xFF76D7D1);
  static const darkSecondary = Color(0xFFAECDC8);
  static const darkTertiary = Color(0xFFBAC7EA);
  static const darkSurface = Color(0xFF151C1B);
  static const darkBackground = Color(0xFF0E1514);

  static final lightScheme =
      ColorScheme.fromSeed(
        seedColor: lightPrimary,
        brightness: Brightness.light,
      ).copyWith(
        primary: lightPrimary,
        secondary: lightSecondary,
        tertiary: lightTertiary,
        surface: lightSurface,
      );

  static final darkScheme =
      ColorScheme.fromSeed(
        seedColor: darkPrimary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: darkPrimary,
        secondary: darkSecondary,
        tertiary: darkTertiary,
        surface: darkSurface,
      );
}
