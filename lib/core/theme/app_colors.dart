import 'package:flutter/material.dart';

/// Raw brand colour tokens — the single source of truth for every colour value
/// used in MYBIKE. Widgets must never hardcode a `Color(0x...)`; they read a
/// semantic value from [AppPalette] instead.
///
/// Values are the brand palette defined in the project brief:
/// Yellow `#F9C846` + Black `#171717` + White, with a warm light background and
/// a true-black dark scale.
abstract final class AppColors {
  // ── Brand ───────────────────────────────────────────────────────────────
  static const Color brandYellow = Color(0xFFF9C846);
  static const Color brandBlack = Color(0xFF171717);
  static const Color white = Color(0xFFFFFFFF);

  /// Yellow at 20% / 12% — used for soft highlights behind active items.
  static const Color brandYellowSoft = Color(0x33F9C846);
  static const Color brandYellowFaint = Color(0x1FF9C846);

  // ── Light theme ────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF7F7F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE8E8E5);
  static const Color lightDivider = Color(0xFFEFEFEC);
  static const Color lightTextPrimary = Color(0xFF171717);
  static const Color lightTextSecondary = Color(0xFF6B6B6B);
  static const Color lightTextMuted = Color(0xFF999999);
  static const Color lightSidebar = Color(0xFFFFFFFF);
  static const Color lightHeader = Color(0xFFF7F7F5);
  static const Color lightHover = Color(0xFFF2F2EF);

  // ── Dark theme ──────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF101010);
  static const Color darkSurface = Color(0xFF181818);
  static const Color darkCard = Color(0xFF202020);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkDivider = Color(0xFF2A2A2A);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB5B5B5);
  static const Color darkTextMuted = Color(0xFF999999);
  static const Color darkSidebar = Color(0xFF181818);
  static const Color darkHeader = Color(0xFF181818);
  static const Color darkHover = Color(0xFF262626);

  // ── Semantic status (light) ─────────────────────────────────────────────
  static const Color lightSuccess = Color(0xFF1B8A5A);
  static const Color lightDanger = Color(0xFFC62828);
  static const Color lightWarning = Color(0xFFB27400);
  static const Color lightInfo = Color(0xFF1D4ED8);

  // ─ Semantic status (dark — lightened for contrast on black) ────────────
  static const Color darkSuccess = Color(0xFF4CD08A);
  static const Color darkDanger = Color(0xFFF8777D);
  static const Color darkWarning = Color(0xFFF0B429);
  static const Color darkInfo = Color(0xFF7BA6FF);

  /// Soft (background) variants of the status colours, light theme.
  static const Color softSuccess = Color(0x1F1B8A5A);
  static const Color softDanger = Color(0x1FC62828);
  static const Color softWarning = Color(0x1FB27400);
  static const Color softInfo = Color(0x1F1D4ED8);

  /// Soft (background) variants of the status colours, dark theme.
  static const Color softSuccessDark = Color(0x334CD08A);
  static const Color softDangerDark = Color(0x33F8777D);
  static const Color softWarningDark = Color(0x33F0B429);
  static const Color softInfoDark = Color(0x337BA6FF);
}
