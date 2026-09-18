import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Material 3 theme assembly.
///
/// Both themes are generated from [AppPalette] + [AppTypography] so the brand
/// (yellow `#F9C846`, black `#171717`, white) is expressed once and every
/// component inherits it. Widgets must not style themselves individually.
abstract final class AppTheme {
  static ThemeData get light => build(AppPalette.light, Brightness.light);

  static ThemeData get dark => build(AppPalette.dark, Brightness.dark);

  /// Builds a complete theme for a palette/brightness pair.
  static ThemeData build(AppPalette palette, Brightness brightness) {
    final TextTheme text = AppTypography.resolved;
    final ColorScheme scheme = buildColorScheme(palette, brightness);

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      textTheme: text,
      primaryTextTheme: text,
      extensions: <ThemeExtension<dynamic>>[palette],
      dividerColor: palette.divider,
      disabledColor: palette.textMuted,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.headerBackground,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: AppDimensions.headerHeight,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: palette.textPrimary),
        iconTheme: IconThemeData(color: palette.textSecondary),
        actionsIconTheme: IconThemeData(color: palette.textSecondary),
        shape: Border(bottom: BorderSide(color: palette.border)),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          side: BorderSide(color: palette.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.brandPrimary,
          foregroundColor: palette.onBrandPrimary,
          disabledBackgroundColor: palette.divider,
          disabledForegroundColor: palette.textMuted,
          minimumSize: const Size(0, AppDimensions.controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space20,
          ),
          textStyle: text.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: palette.onBrandPrimary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.card,
          foregroundColor: palette.textPrimary,
          disabledBackgroundColor: palette.divider,
          disabledForegroundColor: palette.textMuted,
          elevation: 0,
          minimumSize: const Size(0, AppDimensions.controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space20,
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            side: BorderSide(color: palette.border),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          disabledForegroundColor: palette.textMuted,
          minimumSize: const Size(0, AppDimensions.controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space20,
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(0, AppDimensions.controlHeightSm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space12,
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.textSecondary,
          minimumSize: const Size(
            AppDimensions.minTouchTarget,
            AppDimensions.minTouchTarget,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space12,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: palette.textMuted),
        labelStyle: text.labelLarge?.copyWith(color: palette.textSecondary),
        floatingLabelStyle: text.labelMedium?.copyWith(
          color: palette.textPrimary,
        ),
        helperStyle: text.bodySmall?.copyWith(color: palette.textMuted),
        errorStyle: text.bodySmall?.copyWith(color: palette.danger),
        prefixIconColor: palette.textMuted,
        suffixIconColor: palette.textMuted,
        border: inputBorder(palette, palette.border, AppDimensions.borderWidth),
        enabledBorder: inputBorder(
          palette,
          palette.border,
          AppDimensions.borderWidth,
        ),
        focusedBorder: inputBorder(
          palette,
          palette.brandPrimary,
          AppDimensions.focusBorderWidth,
        ),
        errorBorder: inputBorder(
          palette,
          palette.danger,
          AppDimensions.borderWidth,
        ),
        focusedErrorBorder: inputBorder(
          palette,
          palette.danger,
          AppDimensions.focusBorderWidth,
        ),
        disabledBorder: inputBorder(
          palette,
          palette.divider,
          AppDimensions.borderWidth,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: AppDimensions.borderWidth,
        space: AppDimensions.space24,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.textPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: palette.isDark ? palette.background : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppDimensions.space16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppDimensions.space24),
        titleTextStyle: text.titleLarge?.copyWith(color: palette.textPrimary),
        contentTextStyle: text.bodyMedium?.copyWith(
          color: palette.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          side: BorderSide(color: palette.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: palette.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.textPrimary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        textStyle: text.labelMedium?.copyWith(
          color: palette.isDark ? palette.background : Colors.white,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space6,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.brandPrimary,
        linearTrackColor: palette.divider,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 4,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll<double>(6),
        radius: const Radius.circular(AppDimensions.radiusPill),
        thumbColor: WidgetStatePropertyAll<Color>(palette.textMuted),
        trackColor: WidgetStatePropertyAll<Color>(palette.divider),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.brandSoft,
        disabledColor: palette.divider,
        side: BorderSide(color: palette.border),
        labelStyle: text.labelMedium?.copyWith(color: palette.textPrimary),
        secondaryLabelStyle: text.labelMedium?.copyWith(
          color: palette.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        textColor: palette.textPrimary,
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
        ),
        minVerticalPadding: AppDimensions.space12,
        titleTextStyle: text.titleSmall?.copyWith(color: palette.textPrimary),
        subtitleTextStyle: text.bodySmall?.copyWith(color: palette.textMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.sidebarBackground,
        indicatorColor: palette.navItemSelectedBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: AppDimensions.bottomNavHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStatePropertyAll<IconThemeData>(
          IconThemeData(
            color: palette.navItemForeground,
            size: AppDimensions.icon,
          ),
        ),
        labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
          text.labelSmall?.copyWith(color: palette.navItemForeground),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.sidebarBackground,
        indicatorColor: palette.navItemSelectedBackground,
        selectedIconTheme: IconThemeData(
          color: palette.navItemSelectedForeground,
        ),
        unselectedIconTheme: IconThemeData(color: palette.navItemForeground),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: palette.textPrimary,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: palette.textSecondary,
        ),
        elevation: 0,
        labelType: NavigationRailLabelType.none,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: text.bodyMedium?.copyWith(color: palette.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(color: palette.border),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(palette.card),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
          elevation: const WidgetStatePropertyAll<double>(0),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              side: BorderSide(color: palette.border),
            ),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          return states.contains(WidgetState.selected)
              ? palette.brandPrimary
              : Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll<Color>(palette.onBrandPrimary),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          return states.contains(WidgetState.selected)
              ? palette.brandPrimary
              : palette.textMuted;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          return states.contains(WidgetState.selected)
              ? palette.onBrandPrimary
              : palette.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          return states.contains(WidgetState.selected)
              ? palette.brandPrimary
              : palette.divider;
        }),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll<Color>(palette.background),
        dataRowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        headingTextStyle: text.labelMedium?.copyWith(
          color: palette.textSecondary,
        ),
        dataTextStyle: text.bodyMedium?.copyWith(color: palette.textPrimary),
        dividerThickness: AppDimensions.borderWidth,
        headingRowHeight: AppDimensions.tableRowHeight,
        dataRowMinHeight: AppDimensions.tableRowHeight,
        dataRowMaxHeight: AppDimensions.tableRowHeight + 12,
      ),
    );
  }

  /// Rounded input border used by every text field in the app.
  static OutlineInputBorder inputBorder(
    AppPalette palette,
    Color color,
    double width,
  ) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Colour scheme derived from the brand palette.
  static ColorScheme buildColorScheme(
    AppPalette palette,
    Brightness brightness,
  ) {
    final Color onInverse = palette.isDark ? Colors.white : Colors.white;
    return ColorScheme(
      brightness: brightness,
      primary: palette.brandPrimary,
      onPrimary: palette.onBrandPrimary,
      primaryContainer: palette.brandSoft,
      onPrimaryContainer: palette.textPrimary,
      secondary: palette.textPrimary,
      onSecondary: onInverse,
      secondaryContainer: palette.surface,
      onSecondaryContainer: palette.textPrimary,
      tertiary: palette.info,
      onTertiary: onInverse,
      error: palette.danger,
      onError: onInverse,
      errorContainer: palette.dangerSoft,
      onErrorContainer: palette.textPrimary,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      surfaceContainerLowest: palette.background,
      surfaceContainerLow: palette.surface,
      surfaceContainer: palette.card,
      surfaceContainerHigh: palette.card,
      surfaceContainerHighest: palette.hover,
      outline: palette.border,
      outlineVariant: palette.divider,
      shadow: palette.shadow,
      scrim: palette.shadow,
      inverseSurface: palette.textPrimary,
      onInverseSurface: palette.isDark
          ? palette.textPrimary
          : palette.background,
      inversePrimary: palette.brandPrimary,
    );
  }
}
