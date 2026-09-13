import 'package:flutter/material.dart';

abstract final class AppColors {
  static const lightPrimary = Color(0xFF294AC5);
  static const lightSecondary = Color(0xFF9C472F);
  static const lightTertiary = Color(0xFF17765A);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBackground = Color(0xFFF8F5EF);

  static const darkPrimary = Color(0xFFB8C6FF);
  static const darkSecondary = Color(0xFFF19A7E);
  static const darkTertiary = Color(0xFF9FE6C9);
  static const darkSurface = Color(0xFF20363D);
  static const darkBackground = Color(0xFF14262C);

  static final lightScheme =
      ColorScheme.fromSeed(
        seedColor: lightPrimary,
        brightness: Brightness.light,
      ).copyWith(
        primary: lightPrimary,
        onPrimary: Colors.white,
        secondary: lightSecondary,
        tertiary: lightTertiary,
        surface: lightSurface,
        onSurface: const Color(0xFF192B32),
        onSurfaceVariant: const Color(0xFF52636B),
        primaryContainer: const Color(0xFFE3EAFE),
        onPrimaryContainer: const Color(0xFF192B32),
        secondaryContainer: const Color(0xFFFFE6D6),
        onSecondaryContainer: const Color(0xFF703721),
        tertiaryContainer: const Color(0xFFDAF2E8),
        onTertiaryContainer: const Color(0xFF13523F),
        outlineVariant: const Color(0xFFD6DEDE),
        inverseSurface: lightPrimary,
        onInverseSurface: lightBackground,
        inversePrimary: const Color(0xFFB8C6FF),
        primaryFixedDim: const Color(0xFF294AC5),
        secondaryFixedDim: const Color(0xFFDF7355),
      );

  static final darkScheme =
      ColorScheme.fromSeed(
        seedColor: darkPrimary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: darkPrimary,
        onPrimary: darkBackground,
        secondary: darkSecondary,
        tertiary: darkTertiary,
        surface: darkSurface,
        onSurface: const Color(0xFFF8F5EF),
        onSurfaceVariant: const Color(0xFFBDCDD2),
        primaryContainer: const Color(0xFF2B4058),
        onPrimaryContainer: const Color(0xFFDEE5FF),
        secondaryContainer: const Color(0xFF49352D),
        onSecondaryContainer: const Color(0xFFFFDCC7),
        tertiaryContainer: const Color(0xFF204B40),
        onTertiaryContainer: const Color(0xFFBCEEDB),
        outlineVariant: const Color(0xFF486169),
        inverseSurface: const Color(0xFF294AC5),
        onInverseSurface: const Color(0xFFF8F5EF),
        inversePrimary: const Color(0xFFB8C6FF),
        primaryFixedDim: const Color(0xFFB8C6FF),
        secondaryFixedDim: const Color(0xFFF19A7E),
      );
}
