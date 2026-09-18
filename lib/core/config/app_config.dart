/// Application-wide static configuration.
///
/// Values that never change at runtime live here. Anything that differs per
/// build/environment belongs in `EnvConfig` instead.
abstract final class AppConfig {
  /// Human readable application name (window title, web tab, task switcher).
  static const String appName = 'MyBike';

  /// Short name used in compact UI (mobile app bar, splash).
  static const String appShortName = 'MyBike';

  /// Brand tagline used on the splash/login screens.
  static const String tagline = 'Multi-Showroom Bike Dealership ERP';

  /// Version metadata mirrored from `pubspec.yaml` (`version: x.y.z+b`).
  ///
  /// Phase 27 replaces these with values injected by the build pipeline; until
  /// then they are the single source of truth for display purposes.
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  /// Default locale / currency used across formatting helpers.
  static const String localeName = 'en_IN';
  static const String localeLanguageCode = 'en';
  static const String localeCountryCode = 'IN';
  static const String currencyCode = 'INR';
  static const String currencySymbol = '\u20B9';

  /// Pagination defaults (see docs/phase-00/03-architecture.md §11).
  static const int defaultPageSize = 25;
  static const List<int> pageSizeOptions = <int>[25, 50, 100];

  /// Debounce used by search fields (milliseconds).
  static const int searchDebounceMs = 350;
  static const int minSearchLength = 3;

  /// Minimum desktop window size (applied in Phase 26 with window management).
  static const double minWindowWidth = 900;
  static const double minWindowHeight = 600;

  /// Support / legal metadata shown in the About section.
  static const String supportEmail = 'support@mybike.example';

  /// Build metadata string used in the About screen and error reports.
  static String get fullVersionLabel => 'v$appVersion+$buildNumber';
}
