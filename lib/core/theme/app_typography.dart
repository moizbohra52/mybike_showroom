import 'package:flutter/material.dart';

/// Centralised typography.
///
/// Inter is bundled (assets/fonts) so Android, iOS, Web and Windows all render
/// identically with no runtime font fetch. Text sizes are declared once here —
/// screens must not hardcode `TextStyle(fontSize: ...)`.
abstract final class AppTypography {
  /// Bundled family declared in `pubspec.yaml`.
  static const String fontFamily = 'Inter';

  /// Fallback chain used if the bundled font is unavailable on a device.
  static const List<String> fontFamilyFallback = <String>[
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  /// Tabular (monospaced) digits — keeps money columns aligned in tables.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static const TextTheme textTheme = TextTheme(
    // Display — hero numbers, splash headline
    displayLarge: TextStyle(
      fontSize: 32,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    displaySmall: TextStyle(
      fontSize: 24,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),

    // Headline — page titles
    headlineLarge: TextStyle(
      fontSize: 24,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),

    // Title — section headers, card titles, list primary text
    titleLarge: TextStyle(
      fontSize: 18,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),

    // Body — content
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w400,
    ),

    // Label — buttons, chips, table headers, form labels
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
  );

  /// Caption / helper text (smaller than the Material label scale).
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  /// Uppercase overline used above section titles and on KPI cards.
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  /// Money / figures style with tabular digits for perfect column alignment.
  static const TextStyle money = TextStyle(
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
    fontFeatures: tabularFigures,
  );

  /// Large KPI figure style (dashboard stat cards).
  static const TextStyle kpiValue = TextStyle(
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontFeatures: tabularFigures,
    letterSpacing: -0.3,
  );

  /// Convenience getters for commonly used text styles.
  static TextStyle get displayLarge => textTheme.displayLarge!;
  static TextStyle get displayMedium => textTheme.displayMedium!;
  static TextStyle get displaySmall => textTheme.displaySmall!;
  static TextStyle get headlineLarge => textTheme.headlineLarge!;
  static TextStyle get headlineMedium => textTheme.headlineMedium!;
  static TextStyle get headlineSmall => textTheme.headlineSmall!;
  static TextStyle get titleLarge => textTheme.titleLarge!;
  static TextStyle get titleMedium => textTheme.titleMedium!;
  static TextStyle get titleSmall => textTheme.titleSmall!;
  static TextStyle get bodyLarge => textTheme.bodyLarge!;
  static TextStyle get bodyMedium => textTheme.bodyMedium!;
  static TextStyle get bodySmall => textTheme.bodySmall!;
  static TextStyle get labelLarge => textTheme.labelLarge!;
  static TextStyle get labelMedium => textTheme.labelMedium!;
  static TextStyle get labelSmall => textTheme.labelSmall!;
  static TextStyle get button => textTheme.labelLarge!;

  /// Applies the Inter family chain to a [TextTheme].
  static TextTheme applyFamily(TextTheme base) {
    return base.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
  }

  /// Builds a text theme where every style carries the Inter family chain.
  static TextTheme get resolved => applyFamily(textTheme);
}
