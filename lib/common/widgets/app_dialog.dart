import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Modal dialog component conforming to MyBike styling.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.content,
    this.subtitle,
    this.actions,
    this.maxWidth = 480.0,
    this.showCloseButton = true,
    super.key,
  });

  final String title;
  final Widget content;
  final String? subtitle;
  final List<Widget>? actions;
  final double maxWidth;
  final bool showCloseButton;

  /// Public helper to present the dialog modally.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    String? subtitle,
    List<Widget>? actions,
    double maxWidth = 480.0,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext ctx) => AppDialog(
        title: title,
        subtitle: subtitle,
        content: content,
        actions: actions,
        maxWidth: maxWidth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Dialog(
      backgroundColor: palette.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        side: BorderSide(color: palette.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: AppTypography.textTheme.titleLarge?.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppDimensions.space4),
                          Text(
                            subtitle!,
                            style: AppTypography.bodySmall.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showCloseButton)
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: AppDimensions.iconSm,
                      color: palette.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.space20),
              // Body Content
              Flexible(child: content),
              // Actions
              if (actions != null && actions!.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppDimensions.space24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!
                      .map(
                        (Widget a) => Padding(
                          padding: const EdgeInsets.only(left: AppDimensions.space12),
                          child: a,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
