import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';

/// Base card for the MyBike design system.
///
/// Rounded (16px), bordered, zero-elevation card that reads colours from
/// [AppPalette] so it adapts to light/dark automatically. All higher-level
/// cards (stat, dashboard, vehicle, customer…) compose this widget.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppDimensions.space16),
    this.margin = EdgeInsets.zero,
    this.highlighted = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Widget content = Padding(padding: padding, child: child);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: highlighted ? palette.brandSoft : palette.card,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: highlighted ? palette.brandPrimary : palette.border,
          width: highlighted
              ? AppDimensions.focusBorderWidth
              : AppDimensions.borderWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}
