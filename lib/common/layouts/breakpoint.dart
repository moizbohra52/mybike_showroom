import 'package:flutter/widgets.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';

/// Responsive layout classes used across the app.
///
/// Boundaries follow docs/phase-00/03-architecture.md §7:
/// compact `<600`, medium `600–1024`, expanded `1024–1440`, large `>1440`.
enum Breakpoint {
  compact,
  medium,
  expanded,
  large;

  /// Inclusive lower bound of this breakpoint.
  double get minWidth => switch (this) {
    Breakpoint.compact => 0,
    Breakpoint.medium => AppDimensions.compactBreakpoint,
    Breakpoint.expanded => AppDimensions.mediumBreakpoint,
    Breakpoint.large => AppDimensions.expandedBreakpoint,
  };

  bool get isCompact => this == Breakpoint.compact;
  bool get isMedium => this == Breakpoint.medium;
  bool get isExpanded => this == Breakpoint.expanded;
  bool get isLarge => this == Breakpoint.large;

  /// Phones: bottom navigation shell.
  bool get usesBottomNavigation => isCompact;

  /// Tablets / small windows: collapsed navigation rail.
  bool get usesNavigationRail => isMedium;

  /// Desktop and web: full sidebar + header shell.
  bool get usesSidebar => isExpanded || isLarge;

  /// Suggested KPI/stat card columns for dashboards.
  int get gridColumns => switch (this) {
    Breakpoint.compact => 1,
    Breakpoint.medium => 2,
    Breakpoint.expanded => 3,
    Breakpoint.large => 4,
  };

  /// Human readable label shown in the Phase 1 foundation screen.
  String get label => switch (this) {
    Breakpoint.compact => 'Compact (< 600 px)',
    Breakpoint.medium => 'Medium (600–1024 px)',
    Breakpoint.expanded => 'Expanded (1024–1440 px)',
    Breakpoint.large => 'Large (> 1440 px)',
  };
}

/// Resolves the active [Breakpoint].
abstract final class Breakpoints {
  /// Classifies a raw width (unit-testable without a widget tree).
  static Breakpoint fromWidth(double width) {
    if (width < AppDimensions.compactBreakpoint) {
      return Breakpoint.compact;
    }
    if (width < AppDimensions.mediumBreakpoint) {
      return Breakpoint.medium;
    }
    if (width < AppDimensions.expandedBreakpoint) {
      return Breakpoint.expanded;
    }
    return Breakpoint.large;
  }

  /// Classifies the current window/device.
  static Breakpoint of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);
}

/// Responsive helpers available on any [BuildContext].
extension BreakpointContextX on BuildContext {
  Breakpoint get breakpoint => Breakpoints.of(this);

  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isCompactLayout => breakpoint.isCompact;

  bool get isMediumLayout => breakpoint.isMedium;

  bool get isExpandedLayout => breakpoint.isExpanded;

  bool get isLargeLayout => breakpoint.isLarge;

  /// True when the sidebar shell (desktop/web) is active.
  bool get isDesktopLayout => breakpoint.usesSidebar;

  /// Standard page padding for the current breakpoint.
  EdgeInsets get pagePadding => EdgeInsets.all(
    breakpoint.isCompact
        ? AppDimensions.pagePaddingCompact
        : AppDimensions.pagePadding,
  );

  /// Default page padding, horizontally configurable (used by list screens that
  /// need tighter gutters on desktop while keeping mobile comfortable).
  EdgeInsets get pagePaddingWithHeader => EdgeInsets.fromLTRB(
    breakpoint.isCompact
        ? AppDimensions.pagePaddingCompact
        : AppDimensions.pagePadding,
    breakpoint.isCompact ? AppDimensions.space12 : AppDimensions.space24,
    breakpoint.isCompact
        ? AppDimensions.pagePaddingCompact
        : AppDimensions.pagePadding,
    breakpoint.isCompact
        ? AppDimensions.pagePaddingCompact
        : AppDimensions.pagePadding,
  );
}
