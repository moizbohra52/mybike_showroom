import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/core/constants/app_strings.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/routes/navigation_registry.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';
import 'package:mybike_showroom/core/theme/theme_controller.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';

/// Responsive navigation shell wrapping every module route.
///
/// Reads the current [Breakpoint] to render desktop (sidebar + header),
/// tablet (navigation rail + header) or mobile (bottom navigation) layouts.
/// Destinations are filtered by the `module.view` permissions of the current
/// showroom — convenience only; RLS enforces access to the data.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    required this.child,
    required this.currentPath,
    super.key,
  });

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> permissions = ref.watch(currentPermissionsProvider);
    final Breakpoint breakpoint = context.breakpoint;

    if (breakpoint.usesSidebar) {
      return DesktopShell(currentPath: currentPath, permissions: permissions, child: child);
    }
    if (breakpoint.isMedium) {
      return TabletShell(currentPath: currentPath, permissions: permissions, child: child);
    }
    return MobileShell(currentPath: currentPath, permissions: permissions, child: child);
  }
}

// ── Desktop shell ────────────────────────────────────────────────────────────

class DesktopShell extends StatelessWidget {
  const DesktopShell({
    required this.child,
    required this.currentPath,
    required this.permissions,
    super.key,
  });

  final Widget child;
  final String currentPath;
  final Set<String> permissions;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Scaffold(
      body: Row(
        children: <Widget>[
          // Material is the ink ancestor so ListTile splash/selected
          // backgrounds render instead of being hidden by a DecoratedBox.
          Material(
            color: palette.sidebarBackground,
            child: Container(
              width: AppDimensions.sidebarWidth,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: palette.border)),
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    height: AppDimensions.headerHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space20,
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'MyBike',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: palette.brandPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.space12,
                      ),
                      children: <Widget>[
                        for (final NavigationEntry entry
                            in NavigationRegistry.visibleFor(permissions))
                          _SidebarTile(
                            entry: entry,
                            selected: entry.matches(currentPath),
                            onTap: () => context.go(entry.path),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    height: AppDimensions.headerHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space20,
                    ),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: palette.border)),
                    ),
                    child: const _ThemeToggleButton(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Container(
                  height: AppDimensions.headerHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space24,
                  ),
                  decoration: BoxDecoration(
                    color: palette.headerBackground,
                    border: Border(bottom: BorderSide(color: palette.border)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          NavigationRegistry.labelForPath(currentPath),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      const ShellSessionActions(),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tablet shell ─────────────────────────────────────────────────────────────

class TabletShell extends StatelessWidget {
  const TabletShell({
    required this.child,
    required this.currentPath,
    required this.permissions,
    super.key,
  });

  final Widget child;
  final String currentPath;
  final Set<String> permissions;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final List<NavigationEntry> entries = NavigationRegistry.visibleFor(permissions);
    final int selectedIndex = entries.indexWhere(
      (NavigationEntry e) => e.matches(currentPath),
    );

    return Scaffold(
      body: Row(
        children: <Widget>[
          if (entries.length >= 2)
            NavigationRail(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (int index) {
                context.go(entries[index.clamp(0, entries.length - 1)].path);
              },
              indicatorColor: palette.navItemSelectedBackground,
              selectedIconTheme: IconThemeData(
                color: palette.onBrandPrimary,
                size: AppDimensions.icon,
              ),
              unselectedIconTheme: IconThemeData(
                color: palette.navItemForeground,
                size: AppDimensions.iconMd,
              ),
              destinations: <NavigationRailDestination>[
                for (final NavigationEntry entry in entries)
                  NavigationRailDestination(
                    icon: Icon(entry.icon),
                    selectedIcon: Icon(entry.effectiveSelectedIcon),
                    label: Text(entry.label),
                  ),
              ],
            ),
          Expanded(
            child: Column(
              children: <Widget>[
                Container(
                  height: AppDimensions.headerHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space20,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          NavigationRegistry.labelForPath(currentPath),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const ShellSessionActions(),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile shell ─────────────────────────────────────────────────────────────

class MobileShell extends StatelessWidget {
  const MobileShell({
    required this.child,
    required this.currentPath,
    required this.permissions,
    super.key,
  });

  final Widget child;
  final String currentPath;
  final Set<String> permissions;

  @override
  Widget build(BuildContext context) {
    final List<NavigationEntry> primary = NavigationRegistry.mobilePrimary(permissions);
    final int selectedIndex = primary.indexWhere(
      (NavigationEntry e) => e.matches(currentPath),
    );

    return Scaffold(
      body: Column(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: AppDimensions.headerHeightCompact,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        NavigationRegistry.labelForPath(currentPath),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const ShellSessionActions(),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
      // NavigationBar needs at least two destinations.
      bottomNavigationBar: primary.length < 2
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (int index) {
                context.go(primary[index].path);
              },
              destinations: <NavigationDestination>[
                for (final NavigationEntry entry in primary)
                  NavigationDestination(
                    icon: Icon(entry.icon),
                    selectedIcon: Icon(entry.effectiveSelectedIcon),
                    label: entry.label,
                  ),
              ],
            ),
    );
  }
}

// ── Shared sub-widgets ───────────────────────────────────────────────────────

/// Current showroom (tap to switch when there is a choice) and sign-out.
class ShellSessionActions extends ConsumerWidget {
  const ShellSessionActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    if (state is! SignedIn || state.session == null) {
      return const SizedBox.shrink();
    }
    final bool canSwitch = state.session!.showrooms.length > 1 || state.session!.canViewAllShowrooms;
    final String label = state.selection?.isAll ?? false
        ? AppStrings.allShowrooms
        : state.showroom?.name ?? '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: TextButton.icon(
            onPressed: canSwitch ? () => context.go(AppRoutes.selectShowroomPath) : null,
            icon: const Icon(Icons.storefront_outlined, size: AppDimensions.iconMd),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        IconButton(
          tooltip: AppStrings.signOut,
          icon: const Icon(Icons.logout),
          onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
        ),
      ],
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final NavigationEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return ListTile(
      leading: Icon(
        selected ? entry.effectiveSelectedIcon : entry.icon,
        color: selected ? palette.onBrandPrimary : palette.navItemForeground,
      ),
      selectedTileColor: selected
          ? palette.navItemSelectedBackground
          : Colors.transparent,
      iconColor: selected ? palette.onBrandPrimary : palette.navItemForeground,
      textColor: selected ? palette.onBrandPrimary : palette.textPrimary,
      selectedColor: palette.onBrandPrimary,
      trailing: entry.plannedPhase != null && entry.plannedPhase! > 1
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space6,
                vertical: AppDimensions.space2,
              ),
              decoration: BoxDecoration(
                color: palette.infoSoft,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
              ),
              child: Text(
                'P${entry.plannedPhase}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.info,
                  fontSize: AppDimensions.space12,
                ),
              ),
            )
          : null,
      title: Text(
        entry.label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeMode mode = ref.watch(themeControllerProvider);

    return TextButton.icon(
      onPressed: () => ref.read(themeControllerProvider.notifier).cycleMode(),
      icon: Icon(mode.icon, size: AppDimensions.iconMd),
      label: Text(mode.label),
    );
  }
}
