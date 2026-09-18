/// Spacing, radius, sizing and layout tokens.
///
/// All paddings, gaps, radii and fixed sizes in the app come from here so the
/// visual rhythm stays consistent and theme changes stay cheap.
abstract final class AppDimensions {
  // ── Spacing scale (4pt rhythm) ─────────────────────────────────────────
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;
  static const double space64 = 64;

  // ── Radius ─────────────────────────────────────────────────────────────
  static const double radiusXs = 6;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusXxl = 28;
  static const double radiusPill = 999;

  // ── Borders ────────────────────────────────────────────────────────────
  static const double borderWidth = 1;
  static const double focusBorderWidth = 2;

  // ── Controls ───────────────────────────────────────────────────────────
  static const double controlHeightSm = 36;
  static const double controlHeight = 48;
  static const double controlHeightLg = 56;
  static const double minTouchTarget = 44;

  // ── Icons ──────────────────────────────────────────────────────────────
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double icon = 24;
  static const double iconLg = 32;
  static const double iconXl = 40;

  // ── Layout shell ───────────────────────────────────────────────────────
  static const double sidebarWidth = 264;
  static const double sidebarCollapsedWidth = 80;
  static const double headerHeight = 64;
  static const double headerHeightCompact = 56;
  static const double bottomNavHeight = 64;
  static const double pagePaddingCompact = 16;
  static const double pagePadding = 24;
  static const double contentMaxWidth = 1600;
  static const double formMaxWidth = 720;
  static const double dialogMaxWidth = 560;
  static const double sheetMaxWidth = 640;
  static const double cardMinWidth = 240;
  static const double kpiCardMinWidth = 220;
  static const double tableHeaderHeight = 44;
  static const double tableRowHeight = 52;

  // ── Breakpoints (docs/phase-00/03-architecture.md §7) ──────────────────
  static const double compactBreakpoint = 600;
  static const double mediumBreakpoint = 1024;
  static const double expandedBreakpoint = 1440;

  // ── Motion ─────────────────────────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  /// Opacity used for disabled controls and skeleton placeholders.
  static const double disabledOpacity = 0.45;
  static const double mutedOpacity = 0.7;
}
