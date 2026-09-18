import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Loading indicator component with optional label.
class AppLoading extends StatelessWidget {
  const AppLoading({
    this.message,
    this.size = AppDimensions.iconLg,
    this.color,
    super.key,
  });

  final String? message;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color progressColor = color ?? palette.brandPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2.8,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
        if (message != null && message!.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppDimensions.space16),
          Text(
            message!,
            style: AppTypography.bodySmall.copyWith(color: palette.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Convenience alias for [AppLoading] satisfying naming conventions.
class AppLoader extends StatelessWidget {
  const AppLoader({
    this.message,
    this.size = AppDimensions.iconLg,
    this.color,
    super.key,
  });

  final String? message;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppLoading(
      message: message,
      size: size,
      color: color,
    );
  }
}
