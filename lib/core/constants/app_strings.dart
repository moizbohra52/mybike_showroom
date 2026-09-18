/// Centralised user-facing strings.
///
/// English is the only language in v1. Every screen reads its text from here so
/// a future localisation layer (or `flutter_localizations` ARB files) can be
/// dropped in without hunting for literals across features.
abstract final class AppStrings {
  // ── Shell / navigation ─────────────────────────────────────────────────
  static const String navMore = 'More';
  static const String navAllModules = 'All modules';
  static const String searchHint = 'Search vehicles, customers, invoices…';
  static const String notificationsTooltip = 'Notifications';
  static const String showroomSelectorTooltip = 'Showroom';
  static const String allShowrooms = 'All showrooms';
  static const String userMenuTooltip = 'Account';
  static const String signOut = 'Sign out';
  static const String profile = 'Profile';
  static const String about = 'About';

  // ── Theme switcher ─────────────────────────────────────────────────────
  static const String themeLabel = 'Theme';
  static const String themeSystem = 'System';
  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';

  // ── Home / foundation screen ───────────────────────────────────────────
  static const String welcomeTitle = 'Welcome to MyBike';
  static const String welcomeSubtitle =
      'Multi-showroom bike dealership management & accounting ERP.';
  static const String foundationNotice =
      'Phase 1 foundation is running. Business modules arrive in later phases.';
  static const String sectionEnvironment = 'Environment';
  static const String sectionLayout = 'Layout & breakpoint';
  static const String sectionTheme = 'Theme tokens';
  static const String sectionTypography = 'Typography';
  static const String sectionStatus = 'Status colours';
  static const String sectionPhasePlan = 'Delivery phases';
  static const String breakpointLabel = 'Breakpoint';
  static const String windowSizeLabel = 'Window size';
  static const String platformLabel = 'Platform';
  static const String environmentLabel = 'Build environment';
  static const String gitShaLabel = 'Build';
  static const String supabaseLabel = 'Supabase';
  static const String configuredLabel = 'Configured';
  static const String notConfiguredLabel = 'Not configured yet';
  static const String pushSupportLabel = 'Push notifications';
  static const String supportedLabel = 'Supported';
  static const String unsupportedLabel = 'Not supported (uses in-app centre)';
  static const String versionLabel = 'Version';

  // ── Placeholder screens ────────────────────────────────────────────────
  static const String moduleComingSoon = 'Coming soon';
  static const String modulePlaceholderHeadline =
      'This module is not built yet';
  static const String plannedInPhase = 'Planned in';
  static const String backToDashboard = 'Back to dashboard';

  // ── Errors ─────────────────────────────────────────────────────────────
  static const String notFoundTitle = 'Page not found';
  static const String notFoundMessage =
      'The page you tried to open does not exist or is not available for your role.';
  static const String goHome = 'Go to dashboard';
  static const String configErrorTitle = 'Configuration problem';
  static const String configErrorIntro =
      'MyBike cannot start because this build is misconfigured. No data was loaded.';
  static const String retry = 'Retry';
  static const String close = 'Close';

  // ── Generic actions ────────────────────────────────────────────────────
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String create = 'Create';
  static const String apply = 'Apply';
  static const String reset = 'Reset';
  static const String yes = 'Yes';
  static const String no = 'No';
}
