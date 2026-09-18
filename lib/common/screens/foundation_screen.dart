import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/config/env_config.dart';
import 'package:mybike_showroom/core/config/platform_target.dart';
import 'package:mybike_showroom/core/constants/app_strings.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/routes/navigation_registry.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Phase 1 & 2 home screen.
///
/// Renders the MyBike visual identity, reports the live platform /
/// breakpoint / environment status, showcases the Phase 2 design system,
/// and lists navigation entries as tappable cards.
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
              const DesignSystemSection(),
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
        const SizedBox(height: AppDimensions.space16),
        AppOutlinedButton(
          text: 'Open Phase 2 Component Gallery',
          icon: Icons.palette_outlined,
          onPressed: () => context.go(AppRoutes.galleryPath),
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

    final List<FoundationStatusItem> items = <FoundationStatusItem>[
      FoundationStatusItem(
        AppStrings.platformLabel,
        PlatformTarget.label,
        Icons.devices_outlined,
      ),
      FoundationStatusItem(
        AppStrings.breakpointLabel,
        breakpoint.label,
        Icons.monitor_outlined,
      ),
      FoundationStatusItem(
        AppStrings.windowSizeLabel,
        '${size.width.toInt()} × ${size.height.toInt()} px',
        Icons.square_foot_outlined,
      ),
      FoundationStatusItem(
        AppStrings.environmentLabel,
        EnvConfig.current.describe,
        Icons.public,
      ),
      FoundationStatusItem(
        AppStrings.supabaseLabel,
        EnvConfig.current.isSupabaseConfigured
            ? AppStrings.configuredLabel
            : AppStrings.notConfiguredLabel,
        Icons.cloud_outlined,
      ),
      FoundationStatusItem(
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
        for (final FoundationStatusItem item in items)
          FoundationStatusCard(item: item, palette: palette),
      ],
    );
  }
}

/// Showcase of Phase 2 MyBike design system components.
class DesignSystemSection extends StatelessWidget {
  const DesignSystemSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionHeader(
          title: 'Design System Showcase (Phase 2)',
          subtitle: 'Reusable UI components adhering to MyBike brand guidelines and tokens',
        ),
        const SizedBox(height: AppDimensions.space16),

        // Stat Cards row
        Wrap(
          spacing: AppDimensions.space16,
          runSpacing: AppDimensions.space16,
          children: <Widget>[
            SizedBox(
              width: 280,
              child: AppStatCard(
                label: "Today's Sales",
                value: '₹ 4,85,000',
                icon: Icons.payments_outlined,
                deltaText: '+14.2%',
                deltaPositive: true,
                onTap: () {},
              ),
            ),
            SizedBox(
              width: 280,
              child: AppStatCard(
                label: 'Stock Value',
                value: '₹ 1.45 Cr',
                icon: Icons.two_wheeler_outlined,
                deltaText: '28 Units',
                deltaPositive: true,
                onTap: () {},
              ),
            ),
            SizedBox(
              width: 280,
              child: AppStatCard(
                label: 'Pending Receivables',
                value: '₹ 3,40,000',
                icon: Icons.account_balance_wallet_outlined,
                deltaText: '-4.8%',
                deltaPositive: false,
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space24),

        // Badges row
        const AppSectionHeader(
          title: 'Status Badges',
          subtitle: 'Semantic state indicators for orders, stock, and invoices',
        ),
        Wrap(
          spacing: AppDimensions.space8,
          runSpacing: AppDimensions.space8,
          children: <Widget>[
            AppStatusBadge.fromKey(statusKey: 'Available'),
            AppStatusBadge.fromKey(statusKey: 'In Stock'),
            AppStatusBadge.fromKey(statusKey: 'Low Stock'),
            AppStatusBadge.fromKey(statusKey: 'Delivered'),
            AppStatusBadge.fromKey(statusKey: 'Pending'),
            AppStatusBadge.fromKey(statusKey: 'Cancelled'),
            AppStatusBadge.fromKey(statusKey: 'Draft'),
          ],
        ),
        const SizedBox(height: AppDimensions.space24),

        // Buttons row
        const AppSectionHeader(
          title: 'Buttons & Controls',
          subtitle: 'Action buttons with variants, touch targets, and loading states',
        ),
        Wrap(
          spacing: AppDimensions.space12,
          runSpacing: AppDimensions.space12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            AppButton(
              text: 'Primary CTA',
              icon: Icons.add,
              onPressed: () {},
            ),
            AppOutlinedButton(
              text: 'Outlined Action',
              icon: Icons.tune,
              onPressed: () {},
            ),
            const AppButton(
              text: 'Loading Spinner',
              loading: true,
            ),
            AppButton(
              text: 'Danger Action',
              variant: AppButtonVariant.danger,
              icon: Icons.delete_outline,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space24),

        // Inputs preview
        const AppSectionHeader(
          title: 'Form Fields & Search',
          subtitle: 'Standardized text input, search with clear button, and currency',
        ),
        Wrap(
          spacing: AppDimensions.space16,
          runSpacing: AppDimensions.space16,
          children: <Widget>[
            SizedBox(
              width: 320,
              child: AppSearchField(
                hint: 'Search vehicles, VIN, or customer...',
                onChanged: (_) {},
              ),
            ),
            const SizedBox(
              width: 260,
              child: AppTextField(
                label: 'Customer Mobile',
                hint: '10-digit mobile number',
                prefixIcon: Icons.phone_outlined,
              ),
            ),
            const SizedBox(
              width: 220,
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'TOTAL BOOKING AMOUNT',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    AppCurrencyText(125000, large: true),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                    child: FoundationModuleCard(
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
            TypeSample('Display', text.displayLarge, palette),
            TypeSample('Headline', text.headlineMedium, palette),
            TypeSample('Title', text.titleLarge, palette),
            TypeSample('Body', text.bodyMedium, palette),
            TypeSample('Label', text.labelLarge, palette),
            TypeSample('Caption', text.bodySmall, palette),
          ],
        ),
      ],
    );
  }
}

class FoundationStatusItem {
  const FoundationStatusItem(this.title, this.value, this.icon);
  final String title;
  final String value;
  final IconData icon;
}

class FoundationStatusCard extends StatelessWidget {
  const FoundationStatusCard({required this.item, required this.palette, super.key});

  final FoundationStatusItem item;
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

class FoundationModuleCard extends StatelessWidget {
  const FoundationModuleCard({
    required this.entry,
    required this.palette,
    required this.currentPath,
    super.key,
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

class TypeSample extends StatelessWidget {
  const TypeSample(this.label, this.style, this.palette, {super.key});

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
