import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/routes/navigation_registry.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Placeholder shown for modules not yet implemented (Phase 1 only).
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({required this.moduleKey, super.key});

  final String moduleKey;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final NavigationEntry entry = NavigationRegistry.entries.firstWhere(
      (NavigationEntry e) => e.moduleKey == moduleKey,
    );
    final int plannedPhase = entry.plannedPhase ?? 99;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: context.pagePadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  entry.icon,
                  size: AppDimensions.iconLg * 2,
                  color: palette.textMuted,
                ),
                const SizedBox(height: AppDimensions.space24),
                Text(
                  entry.label,
                  style: AppTypography.resolved.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space12),
                Text(
                  'Planned in Phase $plannedPhase',
                  style: AppTypography.resolved.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space4),
                Text(
                  'Permission: ${entry.viewPermission}',
                  style: AppTypography.resolved.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space32),
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.dashboardPath),
                  icon: const Icon(Icons.arrow_back_outlined),
                  label: const Text('Back to dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
