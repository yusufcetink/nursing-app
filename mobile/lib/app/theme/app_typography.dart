import 'package:flutter/material.dart';

abstract final class AppTypography {
  static TextTheme from(TextTheme base) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.7,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.4,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      bodySmall: base.bodySmall?.copyWith(height: 1.4),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
