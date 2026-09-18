import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_colors.dart';

/// Semantic colour contract for the whole app.
///
/// Registered as a [ThemeExtension] on both themes, so widgets read
/// `AppPalette.of(context).card` instead of guessing which `ColorScheme` slot
/// fits. This keeps light/dark parity enforceable and testable
/// (see `test/widget/app_theme_test.dart`).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brandPrimary,
    required this.onBrandPrimary,
    required this.brandSoft,
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.divider,
    required this.hover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textInverse,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.sidebarBackground,
    required this.headerBackground,
    required this.navItemForeground,
    required this.navItemSelectedBackground,
    required this.navItemSelectedForeground,
    required this.navItemHover,
    required this.shadow,
  });

  /// Brand yellow — primary CTA, active navigation, highlights.
  final Color brandPrimary;

  /// Content colour on top of [brandPrimary] (brand black).
  final Color onBrandPrimary;

  /// Convenience alias for [onBrandPrimary].
  Color get brandOnPrimary => onBrandPrimary;

  /// Translucent brand yellow used for selected/soft backgrounds.
  final Color brandSoft;

  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color divider;
  final Color hover;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textInverse;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  final Color sidebarBackground;
  final Color headerBackground;

  final Color navItemForeground;
  final Color navItemSelectedBackground;
  final Color navItemSelectedForeground;
  final Color navItemHover;

  final Color shadow;

  /// Light palette: warm background, white cards, near-black text, yellow CTA.
  static const AppPalette light = AppPalette(
    brandPrimary: AppColors.brandYellow,
    onBrandPrimary: AppColors.brandBlack,
    brandSoft: AppColors.brandYellowSoft,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    card: AppColors.lightCard,
    border: AppColors.lightBorder,
    divider: AppColors.lightDivider,
    hover: AppColors.lightHover,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    textInverse: AppColors.white,
    success: AppColors.lightSuccess,
    successSoft: AppColors.softSuccess,
    warning: AppColors.lightWarning,
    warningSoft: AppColors.softWarning,
    danger: AppColors.lightDanger,
    dangerSoft: AppColors.softDanger,
    info: AppColors.lightInfo,
    infoSoft: AppColors.softInfo,
    sidebarBackground: AppColors.lightSidebar,
    headerBackground: AppColors.lightHeader,
    navItemForeground: AppColors.lightTextSecondary,
    navItemSelectedBackground: AppColors.brandYellowSoft,
    navItemSelectedForeground: AppColors.brandBlack,
    navItemHover: AppColors.lightHover,
    shadow: Color(0x14000000),
  );

  /// Dark palette — yellow stays the accent on the #101010/#181818/#202020 scale.
  static const AppPalette dark = AppPalette(
    brandPrimary: AppColors.brandYellow,
    onBrandPrimary: AppColors.brandBlack,
    brandSoft: AppColors.brandYellowSoft,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    card: AppColors.darkCard,
    border: AppColors.darkBorder,
    divider: AppColors.darkDivider,
    hover: AppColors.darkHover,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    textInverse: AppColors.brandBlack,
    success: AppColors.darkSuccess,
    successSoft: AppColors.softSuccessDark,
    warning: AppColors.darkWarning,
    warningSoft: AppColors.softWarningDark,
    danger: AppColors.darkDanger,
    dangerSoft: AppColors.softDangerDark,
    info: AppColors.darkInfo,
    infoSoft: AppColors.softInfoDark,
    sidebarBackground: AppColors.darkSidebar,
    headerBackground: AppColors.darkHeader,
    navItemForeground: AppColors.darkTextSecondary,
    navItemSelectedBackground: AppColors.brandYellowSoft,
    navItemSelectedForeground: AppColors.brandYellow,
    navItemHover: AppColors.darkHover,
    shadow: Color(0x66000000),
  );

  /// Reads the palette registered on the active theme.
  static AppPalette of(BuildContext context) {
    final AppPalette? palette = Theme.of(context).extension<AppPalette>();
    assert(
      palette != null,
      'AppPalette missing from ThemeData — use AppTheme.light / AppTheme.dark '
      'instead of constructing ThemeData manually.',
    );
    return palette ?? light;
  }

  /// True when this palette is the dark variant.
  bool get isDark => background == AppColors.darkBackground;

  @override
  AppPalette copyWith({
    Color? brandPrimary,
    Color? onBrandPrimary,
    Color? brandSoft,
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? divider,
    Color? hover,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textInverse,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? sidebarBackground,
    Color? headerBackground,
    Color? navItemForeground,
    Color? navItemSelectedBackground,
    Color? navItemSelectedForeground,
    Color? navItemHover,
    Color? shadow,
  }) {
    return AppPalette(
      brandPrimary: brandPrimary ?? this.brandPrimary,
      onBrandPrimary: onBrandPrimary ?? this.onBrandPrimary,
      brandSoft: brandSoft ?? this.brandSoft,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      hover: hover ?? this.hover,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textInverse: textInverse ?? this.textInverse,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      headerBackground: headerBackground ?? this.headerBackground,
      navItemForeground: navItemForeground ?? this.navItemForeground,
      navItemSelectedBackground:
          navItemSelectedBackground ?? this.navItemSelectedBackground,
      navItemSelectedForeground:
          navItemSelectedForeground ?? this.navItemSelectedForeground,
      navItemHover: navItemHover ?? this.navItemHover,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) {
      return this;
    }
    return copyWith(
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t),
      onBrandPrimary: Color.lerp(onBrandPrimary, other.onBrandPrimary, t),
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t),
      background: Color.lerp(background, other.background, t),
      surface: Color.lerp(surface, other.surface, t),
      card: Color.lerp(card, other.card, t),
      border: Color.lerp(border, other.border, t),
      divider: Color.lerp(divider, other.divider, t),
      hover: Color.lerp(hover, other.hover, t),
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t),
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t),
      textMuted: Color.lerp(textMuted, other.textMuted, t),
      textInverse: Color.lerp(textInverse, other.textInverse, t),
      success: Color.lerp(success, other.success, t),
      successSoft: Color.lerp(successSoft, other.successSoft, t),
      warning: Color.lerp(warning, other.warning, t),
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t),
      danger: Color.lerp(danger, other.danger, t),
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t),
      info: Color.lerp(info, other.info, t),
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t),
      sidebarBackground: Color.lerp(
        sidebarBackground,
        other.sidebarBackground,
        t,
      ),
      headerBackground: Color.lerp(headerBackground, other.headerBackground, t),
      navItemForeground: Color.lerp(
        navItemForeground,
        other.navItemForeground,
        t,
      ),
      navItemSelectedBackground: Color.lerp(
        navItemSelectedBackground,
        other.navItemSelectedBackground,
        t,
      ),
      navItemSelectedForeground: Color.lerp(
        navItemSelectedForeground,
        other.navItemSelectedForeground,
        t,
      ),
      navItemHover: Color.lerp(navItemHover, other.navItemHover, t),
      shadow: Color.lerp(shadow, other.shadow, t),
    );
  }
}
