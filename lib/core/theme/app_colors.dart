import 'package:flutter/material.dart';

/// MindQuest colour tokens (docs/design/visual-design.md).
///
/// The greens come from the earlier prototype. Primary was darkened slightly
/// so white text on buttons meets WCAG AA contrast (5.2:1).
class AppPalette {
  const AppPalette._();

  // Light
  static const Color primary = Color(0xFF2F7A5D);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color forest = Color(0xFF1C2B25);
  static const Color mint = Color(0xFF6FCFB0);
  static const Color amber = Color(0xFFF5B544);
  static const Color onAmber = Color(0xFF3A2A00);
  static const Color crisis = Color(0xFFD93F44);
  static const Color crisisSurface = Color(0xFFFDECEC);
  static const Color background = Color(0xFFF6F8F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFE8F1ED);
  static const Color text = Color(0xFF16231E);
  static const Color textMuted = Color(0xFF5B6B64);
  static const Color border = Color(0xFFDCE5E1);

  // Dark
  static const Color darkPrimary = Color(0xFF6FCFB0);
  static const Color darkOnPrimary = Color(0xFF10201A);
  static const Color darkCrisis = Color(0xFFFF7A7E);
  static const Color darkCrisisSurface = Color(0xFF3A1F21);
  static const Color darkBackground = Color(0xFF121B17);
  static const Color darkSurface = Color(0xFF1C2B25);
  static const Color darkSurfaceSoft = Color(0xFF24362F);
  static const Color darkText = Color(0xFFEAF2EE);
  static const Color darkTextMuted = Color(0xFF9DB1A8);
  static const Color darkBorder = Color(0xFF2E4139);
}

/// Colours that Material's ColorScheme has no slot for.
/// Use: `Theme.of(context).extension<MindQuestColors>()!`.
@immutable
class MindQuestColors extends ThemeExtension<MindQuestColors> {
  const MindQuestColors({
    required this.reward,
    required this.onReward,
    required this.crisis,
    required this.crisisSurface,
    required this.surfaceSoft,
    required this.textMuted,
    required this.brand,
  });

  final Color reward;
  final Color onReward;
  final Color crisis;
  final Color crisisSurface;
  final Color surfaceSoft;
  final Color textMuted;
  final Color brand;

  static const MindQuestColors light = MindQuestColors(
    reward: AppPalette.amber,
    onReward: AppPalette.onAmber,
    crisis: AppPalette.crisis,
    crisisSurface: AppPalette.crisisSurface,
    surfaceSoft: AppPalette.surfaceSoft,
    textMuted: AppPalette.textMuted,
    brand: AppPalette.forest,
  );

  static const MindQuestColors dark = MindQuestColors(
    reward: AppPalette.amber,
    onReward: AppPalette.onAmber,
    crisis: AppPalette.darkCrisis,
    crisisSurface: AppPalette.darkCrisisSurface,
    surfaceSoft: AppPalette.darkSurfaceSoft,
    textMuted: AppPalette.darkTextMuted,
    brand: Color(0xFF0C1411),
  );

  @override
  MindQuestColors copyWith({
    Color? reward,
    Color? onReward,
    Color? crisis,
    Color? crisisSurface,
    Color? surfaceSoft,
    Color? textMuted,
    Color? brand,
  }) =>
      MindQuestColors(
        reward: reward ?? this.reward,
        onReward: onReward ?? this.onReward,
        crisis: crisis ?? this.crisis,
        crisisSurface: crisisSurface ?? this.crisisSurface,
        surfaceSoft: surfaceSoft ?? this.surfaceSoft,
        textMuted: textMuted ?? this.textMuted,
        brand: brand ?? this.brand,
      );

  @override
  MindQuestColors lerp(ThemeExtension<MindQuestColors>? other, double t) {
    if (other is! MindQuestColors) return this;
    return MindQuestColors(
      reward: Color.lerp(reward, other.reward, t)!,
      onReward: Color.lerp(onReward, other.onReward, t)!,
      crisis: Color.lerp(crisis, other.crisis, t)!,
      crisisSurface: Color.lerp(crisisSurface, other.crisisSurface, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
    );
  }
}
