import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/core/config/env_config.dart';
import 'package:mybike_showroom/core/config/platform_target.dart';
import 'package:mybike_showroom/core/constants/app_strings.dart';
import 'package:mybike_showroom/core/routes/navigation_registry.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Phase 1 home screen.
///
/// Renders the MyBike visual identity, reports the live platform /
/// breakpoint / environment status and lists navigation entries as tappable
/// cards. From Phase 15 this becomes the real dashboard.
class FoundationScreen extends StatelessWidget {
  const FoundationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Breakpoint breakpoint = context.breakpoint;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: context.pagePaddingWithHeader,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const HeaderSection(),
              const SizedBox(height: AppDimensions.space32),
              StatusSection(breakpoint: breakpoint),
              const SizedBox(height: AppDimensions.space40),
              const ModuleGridSection(),
              const SizedBox(height: AppDimensions.space40),
              const TypographySection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brand header + environment notice.
class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final EnvValidation validation = EnvConfig.current.validate();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.welcomeTitle,
          style: AppTypography.resolved.displayLarge?.copyWith(
            color: palette.brandPrimary,
          ),
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          AppStrings.welcomeSubtitle,
          style: AppTypography.resolved.bodyLarge?.copyWith(
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimensions.space16),
        if (validation.hasWarnings)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.space8),
            child: Text(
              'Notice: ${validation.warnings.join("; ")}',
              style: AppTypography.resolved.bodySmall?.copyWith(
                color: palette.warning,
              ),
            ),
          ),
        Text(
          AppStrings.foundationNotice,
          style: AppTypography.resolved.bodySmall?.copyWith(
            color: palette.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Live status cards: platform, breakpoint, window, env, supabase, push.
class StatusSection extends StatelessWidget {
  const StatusSection({required this.breakpoint, super.key});

  final Breakpoint breakpoint;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Size size = MediaQuery.sizeOf(context);

    final List<_StatusItem> items = <_StatusItem>[
      _StatusItem(
        AppStrings.platformLabel,
        PlatformTarget.label,
        Icons.devices_outlined,
      ),
      _StatusItem(
        AppStrings.breakpointLabel,
        breakpoint.label,
        Icons.monitor_outlined,
      ),
      _StatusItem(
        AppStrings.windowSizeLabel,
        '${size.width.toInt()} × ${size.height.toInt()} px',
        Icons.square_foot_outlined,
      ),
      _StatusItem(
        AppStrings.environmentLabel,
        EnvConfig.current.describe,
        Icons.public,
      ),
      _StatusItem(
        AppStrings.supabaseLabel,
        EnvConfig.current.isSupabaseConfigured
            ? AppStrings.configuredLabel
            : AppStrings.notConfiguredLabel,
        Icons.cloud_outlined,
      ),
      _StatusItem(
        AppStrings.pushSupportLabel,
        PlatformTarget.supportsPushNotifications
            ? AppStrings.supportedLabel
            : AppStrings.unsupportedLabel,
        Icons.notifications_outlined,
      ),
    ];

    return Wrap(
      spacing: AppDimensions.space16,
      runSpacing: AppDimensions.space12,
      children: <Widget>[
        for (final _StatusItem item in items)
          _StatusCard(item: item, palette: palette),
      ],
    );
  }
}

/// Tappable grid of all module entries.
class ModuleGridSection extends StatelessWidget {
  const ModuleGridSection({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final String currentPath = GoRouterState.of(context).uri.path;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.sectionPhasePlan,
          style: AppTypography.resolved.titleLarge,
        ),
        const SizedBox(height: AppDimensions.space12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            const double spacing = AppDimensions.space16;
            final int columns = (width / (AppDimensions.cardMinWidth + spacing))
                .floor()
                .clamp(1, 6);
            final double cardWidth = (width + spacing) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: AppDimensions.space12,
              children: <Widget>[
                for (final NavigationEntry entry
                    in NavigationRegistry.sidebarEntries)
                  SizedBox(
                    width: cardWidth,
                    child: _ModuleCard(
                      entry: entry,
                      palette: palette,
                      currentPath: currentPath,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Typography sample — also a visual style reference for Phase 2.
class TypographySection extends StatelessWidget {
  const TypographySection({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = AppTypography.resolved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(AppStrings.sectionTypography, style: text.titleLarge),
        const SizedBox(height: AppDimensions.space12),
        Wrap(
          spacing: AppDimensions.space24,
          runSpacing: AppDimensions.space8,
          children: <Widget>[
            _TypeSample('Display', text.displayLarge, palette),
            _TypeSample('Headline', text.headlineMedium, palette),
            _TypeSample('Title', text.titleLarge, palette),
            _TypeSample('Body', text.bodyMedium, palette),
            _TypeSample('Label', text.labelLarge, palette),
            _TypeSample('Caption', text.bodySmall, palette),
          ],
        ),
      ],
    );
  }
}

class _StatusItem {
  const _StatusItem(this.title, this.value, this.icon);
  final String title;
  final String value;
  final IconData icon;
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.item, required this.palette});

  final _StatusItem item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: AppDimensions.kpiCardMinWidth,
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  item.icon,
                  size: AppDimensions.iconMd,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: AppDimensions.space8),
                Flexible(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space8),
            Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.entry,
    required this.palette,
    required this.currentPath,
  });

  final NavigationEntry entry;
  final AppPalette palette;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final bool active = entry.path == currentPath;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: () => context.go(entry.path),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                entry.icon,
                size: AppDimensions.iconLg,
                color: active ? palette.onBrandPrimary : palette.textSecondary,
              ),
              const SizedBox(height: AppDimensions.space12),
              Text(
                entry.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: active ? palette.onBrandPrimary : palette.textPrimary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: AppDimensions.space4),
              Text(
                entry.viewPermission,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeSample extends StatelessWidget {
  const _TypeSample(this.label, this.style, this.palette);

  final String label;
  final TextStyle? style;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: palette.textMuted),
        ),
        const SizedBox(height: AppDimensions.space4),
        Text(
          'Aa',
          style: style?.copyWith(fontFamily: AppTypography.fontFamily),
        ),
      ],
    );
  }
}
