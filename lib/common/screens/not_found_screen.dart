import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Shown when the user navigates to a path that does not exist.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: context.pagePadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.error_outline_outlined, size: 80),
                const SizedBox(height: AppDimensions.space24),
                Text(
                  '404 — Page not found',
                  style: AppTypography.resolved.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space12),
                Text(
                  'The page you tried to open does not exist or is not available for your role.',
                  style: AppTypography.resolved.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space32),
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.dashboardPath),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Go to dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
