import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/core/routes/navigation_registry.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';
import 'package:mybike_showroom/core/theme/theme_controller.dart';

/// Responsive navigation shell wrapping every module route.
///
/// Reads the current [Breakpoint] to render desktop (sidebar + header),
/// tablet (navigation rail + header) or mobile (bottom navigation) layouts.
/// Phase 1 sees all entries; Phase 5 supplies a real permission set that
/// narrows [NavigationRegistry.visibleFor].
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
    final Breakpoint breakpoint = context.breakpoint;

    if (breakpoint.usesSidebar) {
      return DesktopShell(currentPath: currentPath, child: child);
    }
    if (breakpoint.isMedium) {
      return TabletShell(currentPath: currentPath, child: child);
    }
    return MobileShell(currentPath: currentPath, child: child);
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬ Desktop shell Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class DesktopShell extends StatelessWidget {
  const DesktopShell({
    required this.child,
    required this.currentPath,
    super.key,
  });

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Scaffold(
      body: Row(
        children: <Widget>[
          // Sidebar
          Container(
            width: AppDimensions.sidebarWidth,
            decoration: BoxDecoration(
              color: palette.sidebarBackground,
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
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                          in NavigationRegistry.sidebarEntries)
                        _SidebarTile(
                          entry: entry,
                          selected: entry.path == currentPath,
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
          // Main content
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
                  alignment: Alignment.centerLeft,
                  child: Text(
                    NavigationRegistry.labelForPath(currentPath),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: palette.textPrimary,
                    ),
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

// Ã¢â€â‚¬Ã¢â€â‚¬ Tablet shell Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class TabletShell extends StatelessWidget {
  const TabletShell({
    required this.child,
    required this.currentPath,
    super.key,
  });

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    const List<NavigationEntry> entries = NavigationRegistry.sidebarEntries;
    final int selectedIndex = entries.indexWhere(
      (NavigationEntry e) => e.path == currentPath,
    );

    return Scaffold(
      body: Row(
        children: <Widget>[
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
                  alignment: Alignment.centerLeft,
                  child: Text(
                    NavigationRegistry.labelForPath(currentPath),
                    style: Theme.of(context).textTheme.titleLarge,
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

// Ã¢â€â‚¬Ã¢â€â‚¬ Mobile shell Ã¢â€â‚¬Ã¯Â¿Â½Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class MobileShell extends ConsumerWidget {
  const MobileShell({
    required this.child,
    required this.currentPath,
    super.key,
  });

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<NavigationEntry> primary = NavigationRegistry.mobilePrimary(
      null,
    );
    final int selectedIndex = primary.indexWhere(
      (NavigationEntry e) => e.path == currentPath,
    );

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
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

// Ã¢â€â‚¬Ã¢â€â‚¬ Shared sub-widgets Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

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
