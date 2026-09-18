/// Canonical module keys and permission actions.
///
/// These strings are shared by the navigation registry, route guards, sidebar
/// visibility and the database `permissions` table (`module.action`), so the
/// client and the RLS policies speak the same language
/// (see docs/phase-00/02-roles-permissions.md §2).
abstract final class ModuleKeys {
  static const String dashboard = 'dashboard';
  static const String showrooms = 'showrooms';
  static const String users = 'users';
  static const String roles = 'roles';
  static const String vehicles = 'vehicles';
  static const String inventory = 'inventory';
  static const String purchases = 'purchases';
  static const String suppliers = 'suppliers';
  static const String sales = 'sales';
  static const String customers = 'customers';
  static const String bookings = 'bookings';
  static const String finance = 'finance';
  static const String accounting = 'accounting';
  static const String expenses = 'expenses';
  static const String income = 'income';
  static const String reports = 'reports';
  static const String documents = 'documents';
  static const String notifications = 'notifications';
  static const String audit = 'audit';
  static const String settings = 'settings';
  static const String approvals = 'approvals';

  /// Every module key in display-independent order.
  static const List<String> all = <String>[
    dashboard,
    showrooms,
    vehicles,
    inventory,
    purchases,
    suppliers,
    sales,
    customers,
    bookings,
    finance,
    accounting,
    expenses,
    income,
    reports,
    documents,
    notifications,
    approvals,
    audit,
    users,
    roles,
    settings,
  ];
}

/// Permission actions available on every module.
abstract final class PermissionActions {
  static const String view = 'view';
  static const String create = 'create';
  static const String edit = 'edit';
  static const String delete = 'delete';
  static const String approve = 'approve';
  static const String export = 'export';
  static const String print = 'print';

  static const List<String> all = <String>[
    view,
    create,
    edit,
    delete,
    approve,
    export,
    print,
  ];
}

/// Helpers for building/parsing permission codes.
abstract final class PermissionKeys {
  /// Builds a `module.action` permission code, e.g. `sales.create`.
  static String code(String module, String action) => '$module.$action';

  /// Parses a permission code into `(module, action)`; returns null when the
  /// code is malformed.
  static ({String module, String action})? parse(String code) {
    final int separator = code.indexOf('.');
    if (separator <= 0 || separator == code.length - 1) {
      return null;
    }
    return (
      module: code.substring(0, separator),
      action: code.substring(separator + 1),
    );
  }

  /// Shortcut for `module.view`.
  static String view(String module) => code(module, PermissionActions.view);
}
