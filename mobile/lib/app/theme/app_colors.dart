import 'package:flutter/material.dart';

abstract final class AppColors {
  static const lightPrimary = Color(0xFF483158);
  static const lightSecondary = Color(0xFF92513C);
  static const lightTertiary = Color(0xFF48613A);
  static const lightSurface = Color(0xFFFFFCF8);
  static const lightBackground = Color(0xFFFAF7F2);

  static const darkPrimary = Color(0xFFD9C6F3);
  static const darkSecondary = Color(0xFFFFC5A7);
  static const darkTertiary = Color(0xFFDDEBB8);
  static const darkSurface = Color(0xFF291F30);
  static const darkBackground = Color(0xFF1C1622);

  static final lightScheme =
      ColorScheme.fromSeed(
        seedColor: lightPrimary,
        brightness: Brightness.light,
      ).copyWith(
        primary: lightPrimary,
        secondary: lightSecondary,
        tertiary: lightTertiary,
        surface: lightSurface,
        onSurface: const Color(0xFF302338),
        onSurfaceVariant: const Color(0xFF706477),
        primaryContainer: const Color(0xFFE8DFF5),
        onPrimaryContainer: const Color(0xFF302338),
        secondaryContainer: const Color(0xFFFFE4D3),
        onSecondaryContainer: const Color(0xFF613A2D),
        tertiaryContainer: const Color(0xFFDDEBB8),
        onTertiaryContainer: const Color(0xFF314724),
        outlineVariant: const Color(0xFFE5DDE5),
        inverseSurface: lightPrimary,
        onInverseSurface: lightBackground,
        inversePrimary: const Color(0xFFD9C6F3),
        primaryFixedDim: const Color(0xFFA68BCF),
        secondaryFixedDim: const Color(0xFFF28F76),
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
        onSurface: const Color(0xFFF7EFF8),
        onSurfaceVariant: const Color(0xFFC4B6CD),
        primaryContainer: const Color(0xFF453252),
        onPrimaryContainer: const Color(0xFFEDE0FF),
        secondaryContainer: const Color(0xFF51382F),
        onSecondaryContainer: const Color(0xFFFFDDC9),
        tertiaryContainer: const Color(0xFF34442A),
        onTertiaryContainer: const Color(0xFFE0EEC6),
        outlineVariant: const Color(0xFF4B3D55),
        inverseSurface: const Color(0xFF483158),
        onInverseSurface: const Color(0xFFFAF7F2),
        inversePrimary: const Color(0xFFDECEF3),
        primaryFixedDim: const Color(0xFFC4ACE9),
        secondaryFixedDim: const Color(0xFFF5A88F),
      );
}
