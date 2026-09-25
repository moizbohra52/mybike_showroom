/// Route names and paths for the whole application.
///
/// Paths are web-friendly (`/sales/invoices` style in later phases) so deep
/// links work on Web/Windows. Every route is declared here — screens never
/// hardcode a path string.
abstract final class AppRoutes {
  static const String rootPath = '/';
  static const String notFoundPath = '/not-found';

  // ── Authentication (Phase 5) ───────────────────────────────────────────
  static const String splashPath = '/splash';
  static const String loginPath = '/login';
  static const String selectShowroomPath = '/select-showroom';
  static const String accessBlockedPath = '/access-blocked';
  static const String forbiddenPath = '/forbidden';

  // ── Phase 2 design-system gallery ──────────────────────────────────────
  static const String galleryName = 'gallery';
  static const String galleryPath = '/gallery';

  // ── Core ───────────────────────────────────────────────────────────────
  static const String dashboardName = 'dashboard';
  static const String dashboardPath = '/dashboard';

  static const String moreName = 'more';
  static const String morePath = '/more';

  // ── Administration ─────────────────────────────────────────────────────
  static const String showroomsName = 'showrooms';
  static const String showroomsPath = '/showrooms';
  static String showroomDetailPath(String id) => '$showroomsPath/$id';

  static const String usersName = 'users';
  static const String usersPath = '/users';
  static String userDetailPath(String id) => '$usersPath/$id';

  static const String rolesName = 'roles';
  static const String rolesPath = '/roles';
  static String roleDetailPath(String id) => '$rolesPath/$id';

  static const String settingsName = 'settings';
  static const String settingsPath = '/settings';

  static const String approvalsName = 'approvals';
  static const String approvalsPath = '/approvals';

  static const String auditName = 'audit';
  static const String auditPath = '/audit';

  static const String notificationsName = 'notifications';
  static const String notificationsPath = '/notifications';

  static const String documentsName = 'documents';
  static const String documentsPath = '/documents';

  // ── Masters & operations ───────────────────────────────────────────────
  static const String vehiclesName = 'vehicles';
  static const String vehiclesPath = '/vehicles';
  static String vehicleUnitPath(String id) => '$vehiclesPath/units/$id';
  static String vehicleVariantPath(String id) => '$vehiclesPath/variants/$id';

  static const String inventoryName = 'inventory';
  static const String inventoryPath = '/inventory';

  static const String purchasesName = 'purchases';
  static const String purchasesPath = '/purchases';

  static const String suppliersName = 'suppliers';
  static const String suppliersPath = '/suppliers';

  static const String salesName = 'sales';
  static const String salesPath = '/sales';

  static const String customersName = 'customers';
  static const String customersPath = '/customers';

  static const String bookingsName = 'bookings';
  static const String bookingsPath = '/bookings';

  // ── Finance ────────────────────────────────────────────────────────────
  static const String financeName = 'finance';
  static const String financePath = '/finance';

  static const String accountingName = 'accounting';
  static const String accountingPath = '/accounting';

  static const String expensesName = 'expenses';
  static const String expensesPath = '/expenses';

  static const String incomeName = 'income';
  static const String incomePath = '/income';

  static const String reportsName = 'reports';
  static const String reportsPath = '/reports';

  /// Every routable module path (excluding root/not-found helpers).
  static const List<String> modulePaths = <String>[
    dashboardPath,
    showroomsPath,
    usersPath,
    rolesPath,
    settingsPath,
    approvalsPath,
    auditPath,
    notificationsPath,
    documentsPath,
    vehiclesPath,
    inventoryPath,
    purchasesPath,
    suppliersPath,
    salesPath,
    customersPath,
    bookingsPath,
    financePath,
    accountingPath,
    expensesPath,
    incomePath,
    reportsPath,
  ];
}
