import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/widgets/app_button.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Reusable error placeholder view with retry capability.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.title,
    this.message,
    this.icon = Icons.error_outline,
    this.retryText = 'Retry',
    this.onRetry,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String retryText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppDimensions.iconXl,
                color: palette.danger,
              ),
            ),
            const SizedBox(height: AppDimensions.space20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.titleMedium?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppDimensions.space8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppDimensions.space24),
              AppButton(
                text: retryText,
                onPressed: onRetry,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
