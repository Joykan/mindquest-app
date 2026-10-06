import 'package:flutter/material.dart';

/// Placeholder theme. Visual styling is designed after the wireframe review.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6C63FF),
        brightness: Brightness.light,
      );
}
