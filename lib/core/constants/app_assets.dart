/// Paths of bundled assets.
///
/// Fonts are bundled rather than fetched at runtime so Android, iOS, Web and
/// Windows render identically (and the `pdf` package can embed the same TTFs
/// for invoices in Phase 17).
abstract final class AppAssets {
  // ── Fonts (family name: AppTypography.fontFamily) ──────────────────────
  static const String fontFamily = 'Inter';
  static const String interRegular = 'assets/fonts/Inter-Regular.ttf';
  static const String interMedium = 'assets/fonts/Inter-Medium.ttf';
  static const String interSemiBold = 'assets/fonts/Inter-SemiBold.ttf';
  static const String interBold = 'assets/fonts/Inter-Bold.ttf';

  /// Every bundled font file — used by tests to assert the assets ship.
  static const List<String> fontFiles = <String>[
    interRegular,
    interMedium,
    interSemiBold,
    interBold,
  ];

  // ── Branding (added in Phase 2/27 with the final artwork) ─────────────
  static const String logoPlaceholder = '';
  static const String splashPlaceholder = '';
}
