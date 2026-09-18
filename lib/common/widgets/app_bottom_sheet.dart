import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Modal bottom sheet container for mobile and tablet views.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.title,
    required this.content,
    this.subtitle,
    this.actions,
    super.key,
  });

  final String title;
  final Widget content;
  final String? subtitle;
  final List<Widget>? actions;

  /// Public helper to present a styled modal bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    String? subtitle,
    List<Widget>? actions,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => AppBottomSheet(
        title: title,
        subtitle: subtitle,
        content: content,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      padding: EdgeInsets.only(
        top: AppDimensions.space12,
        left: AppDimensions.space20,
        right: AppDimensions.space20,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.space20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
          // Title & Subtitle
          Row(
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
              IconButton(
                icon: const Icon(Icons.close),
                iconSize: AppDimensions.iconSm,
                color: palette.textSecondary,
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),
          // Body content
          Flexible(child: content),
          // Actions
          if (actions != null && actions!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppDimensions.space20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions!
                  .map(
                    (Widget a) => Padding(
                      padding: const EdgeInsets.only(left: AppDimensions.space8),
                      child: a,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
