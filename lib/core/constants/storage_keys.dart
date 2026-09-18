/// Keys used in local preferences (`shared_preferences`).
///
/// Only non-sensitive, device-local UI state belongs here. Sessions, tokens and
/// any financial data are never stored in preferences
/// (see docs/phase-00/04-multishowroom-security.md §9).
abstract final class StorageKeys {
  /// Selected `AppThemeMode.storageValue` (light / dark / system).
  static const String themeMode = 'mybike.pref.theme_mode';

  /// Collapsed state of the desktop sidebar.
  static const String sidebarCollapsed = 'mybike.pref.sidebar_collapsed';

  /// Currently selected showroom id (Phase 5/7). `all` means ALL SHOWROOMS mode.
  static const String selectedShowroomId = 'mybike.pref.selected_showroom_id';

  /// Sentinel stored in [selectedShowroomId] for the consolidated view.
  static const String allShowroomsSentinel = 'all';

  /// Prefix for "last used showroom" per user: `mybike.pref.last_showroom.<id>`.
  static const String lastShowroomPrefix = 'mybike.pref.last_showroom.';

  /// Prefix for persisted list filters: `mybike.pref.filters.<screen>`.
  static const String filtersPrefix = 'mybike.pref.filters.';

  /// Last successful sign-in email (convenience only, never a credential).
  static const String lastLoginEmail = 'mybike.pref.last_login_email';

  /// Builds the per-user last-showroom key.
  static String lastShowroomFor(String profileId) =>
      '$lastShowroomPrefix$profileId';

  /// Builds the filter key for a screen.
  static String filtersFor(String screenKey) => '$filtersPrefix$screenKey';
}
