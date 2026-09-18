import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Style variants for [AppButton].
enum AppButtonVariant { primary, secondary, outline, text, danger }

/// Size presets for [AppButton].
enum AppButtonSize { sm, md, lg }

/// Primary action button for the MyBike design system.
///
/// Implements minimum touch target (44px on md), brand colors (#F9C846 for primary),
/// loading indicator spinner, prefix/suffix icons, and disabled states.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expanded = false,
    super.key,
  });

  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final bool isEnabled = onPressed != null && !loading;

    final double height = resolveHeight(size);
    final EdgeInsetsGeometry padding = resolvePadding(size);
    final TextStyle textStyle = resolveTextStyle(size);
    final double iconSize = resolveIconSize(size);

    final Color bgColor = resolveBackgroundColor(palette, variant, isEnabled);
    final Color fgColor = resolveForegroundColor(palette, variant, isEnabled);
    final BorderSide borderSide = resolveBorderSide(palette, variant, isEnabled);

    final Widget content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading) ...<Widget>[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: AppDimensions.space8),
        ] else if (icon != null) ...<Widget>[
          Icon(icon, size: iconSize, color: fgColor),
          const SizedBox(width: AppDimensions.space8),
        ],
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle.copyWith(color: fgColor),
        ),
        if (!loading && trailingIcon != null) ...<Widget>[
          const SizedBox(width: AppDimensions.space8),
          Icon(trailingIcon, size: iconSize, color: fgColor),
        ],
      ],
    );

    final Widget button = SizedBox(
      height: height,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: borderSide != BorderSide.none ? Border.fromBorderSide(borderSide) : null,
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );

    return expanded ? button : IntrinsicWidth(child: button);
  }

  /// Resolves button height based on size enum.
  static double resolveHeight(AppButtonSize size) {
    return switch (size) {
      AppButtonSize.sm => AppDimensions.controlHeightSm,
      AppButtonSize.md => AppDimensions.controlHeight,
      AppButtonSize.lg => AppDimensions.controlHeightLg,
    };
  }

  /// Resolves internal padding based on size enum.
  static EdgeInsetsGeometry resolvePadding(AppButtonSize size) {
    return switch (size) {
      AppButtonSize.sm => const EdgeInsets.symmetric(horizontal: AppDimensions.space12),
      AppButtonSize.md => const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
      AppButtonSize.lg => const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
    };
  }

  /// Resolves icon size based on size enum.
  static double resolveIconSize(AppButtonSize size) {
    return switch (size) {
      AppButtonSize.sm => AppDimensions.iconSm,
      AppButtonSize.md => AppDimensions.iconMd,
      AppButtonSize.lg => AppDimensions.icon,
    };
  }

  /// Resolves text typography based on size enum.
  static TextStyle resolveTextStyle(AppButtonSize size) {
    return switch (size) {
      AppButtonSize.sm => AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
      AppButtonSize.md => AppTypography.button,
      AppButtonSize.lg => AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
    };
  }

  /// Resolves background color based on palette, variant, and enabled state.
  static Color resolveBackgroundColor(AppPalette palette, AppButtonVariant variant, bool isEnabled) {
    if (!isEnabled) {
      return variant == AppButtonVariant.text || variant == AppButtonVariant.outline
          ? Colors.transparent
          : palette.hover;
    }
    return switch (variant) {
      AppButtonVariant.primary => palette.brandPrimary,
      AppButtonVariant.secondary => palette.surface,
      AppButtonVariant.outline => Colors.transparent,
      AppButtonVariant.text => Colors.transparent,
      AppButtonVariant.danger => palette.danger,
    };
  }

  /// Resolves foreground color based on palette, variant, and enabled state.
  static Color resolveForegroundColor(AppPalette palette, AppButtonVariant variant, bool isEnabled) {
    if (!isEnabled) {
      return palette.textMuted;
    }
    return switch (variant) {
      AppButtonVariant.primary => palette.brandOnPrimary,
      AppButtonVariant.secondary => palette.textPrimary,
      AppButtonVariant.outline => palette.textPrimary,
      AppButtonVariant.text => palette.brandPrimary,
      AppButtonVariant.danger => Colors.white,
    };
  }

  /// Resolves border side based on palette, variant, and enabled state.
  static BorderSide resolveBorderSide(AppPalette palette, AppButtonVariant variant, bool isEnabled) {
    if (variant == AppButtonVariant.outline || variant == AppButtonVariant.secondary) {
      return BorderSide(
        color: isEnabled ? palette.border : palette.hover,
      );
    }
    return BorderSide.none;
  }
}
