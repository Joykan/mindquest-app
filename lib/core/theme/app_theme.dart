import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Light and dark themes built from the MindQuest colour tokens.
/// Font: Nunito (assets/fonts, SIL Open Font License).
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: AppPalette.primary,
          onPrimary: AppPalette.onPrimary,
          secondary: AppPalette.mint,
          onSecondary: AppPalette.forest,
          tertiary: AppPalette.amber,
          onTertiary: AppPalette.onAmber,
          error: AppPalette.crisis,
          onError: Colors.white,
          surface: AppPalette.surface,
          onSurface: AppPalette.text,
          onSurfaceVariant: AppPalette.textMuted,
          surfaceContainerLow: AppPalette.background,
          surfaceContainer: AppPalette.surface,
          surfaceContainerHigh: AppPalette.surfaceSoft,
          surfaceContainerHighest: AppPalette.surfaceSoft,
          outline: AppPalette.border,
          outlineVariant: AppPalette.border,
        ),
        background: AppPalette.background,
        extension: MindQuestColors.light,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppPalette.darkPrimary,
          onPrimary: AppPalette.darkOnPrimary,
          secondary: AppPalette.mint,
          onSecondary: AppPalette.forest,
          tertiary: AppPalette.amber,
          onTertiary: AppPalette.onAmber,
          error: AppPalette.darkCrisis,
          onError: AppPalette.forest,
          surface: AppPalette.darkSurface,
          onSurface: AppPalette.darkText,
          onSurfaceVariant: AppPalette.darkTextMuted,
          surfaceContainerLow: AppPalette.darkBackground,
          surfaceContainer: AppPalette.darkSurface,
          surfaceContainerHigh: AppPalette.darkSurfaceSoft,
          surfaceContainerHighest: AppPalette.darkSurfaceSoft,
          outline: AppPalette.darkBorder,
          outlineVariant: AppPalette.darkBorder,
        ),
        background: AppPalette.darkBackground,
        extension: MindQuestColors.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color background,
    required MindQuestColors extension,
  }) {
    final RoundedRectangleBorder rounded =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    // fontFamily is set here too: button and chip styles don't inherit it,
    // and some phones (e.g. vivo) would otherwise use their own font.
    const TextStyle label = TextStyle(
        fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 15);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Nunito',
      scaffoldBackgroundColor: background,
      extensions: <ThemeExtension<dynamic>>[extension],
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
            fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w800),
        headlineSmall: TextStyle(
            fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(
            fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 15, height: 21 / 15),
        bodyMedium: TextStyle(fontSize: 15, height: 21 / 15),
        bodySmall: TextStyle(fontSize: 13, height: 18 / 13),
        labelLarge: label,
        labelSmall: TextStyle(
            fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: rounded,
          textStyle: label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: rounded,
          side: BorderSide(color: scheme.outline, width: 1.5),
          foregroundColor: scheme.onSurface,
          textStyle: label,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        side: BorderSide(color: scheme.outline),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w600,
            color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
