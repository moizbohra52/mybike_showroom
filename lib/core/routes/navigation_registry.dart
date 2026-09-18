import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/constants/module_keys.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';

/// A navigable module destination.
///
/// One registry drives the desktop sidebar, tablet rail, mobile bottom
/// navigation and the "More" screen, so navigation never drifts between
/// layouts. Visibility is expressed as a permission code (`module.view`) that
/// RLS also enforces — the client filter is convenience, never security.
@immutable
class NavigationEntry {
  const NavigationEntry({
    required this.moduleKey,
    required this.label,
    required this.path,
    required this.icon,
    this.plannedPhase,
    this.selectedIcon,
    this.inSidebar = true,
    this.inMobilePrimary = false,
    this.sortOrder = 0,
  });

  /// Module key shared with the database `permissions.module` column.
  final String moduleKey;

  /// Sidebar / tab label.
  final String label;

  /// Route path (see [AppRoutes]).
  final String path;

  final IconData icon;
  final IconData? selectedIcon;

  /// Phase that implements this module (shown on placeholder screens).
  final int? plannedPhase;

  /// Whether the module appears in the desktop sidebar.
  final bool inSidebar;

  /// Whether the module is a mobile bottom-navigation destination.
  final bool inMobilePrimary;

  /// Display order within the sidebar.
  final int sortOrder;

  /// Permission required to see this destination, e.g. `sales.view`.
  String get viewPermission => PermissionKeys.view(moduleKey);

  IconData get effectiveSelectedIcon => selectedIcon ?? icon;

  /// Permission check used for visibility.
  ///
  /// `grantedPermissions == null` means "permissions not loaded yet". Until
  /// authentication lands in Phase 5 the app runs with `null`, which shows all
  /// destinations; from Phase 5 the permission service always supplies a real
  /// set, so this branch disappears.
  bool isVisibleFor(Iterable<String>? grantedPermissions) {
    if (grantedPermissions == null) {
      return true;
    }
    return grantedPermissions.contains(viewPermission);
  }
}

/// The single source of truth for module navigation.
abstract final class NavigationRegistry {
  static const List<NavigationEntry> entries = <NavigationEntry>[
    NavigationEntry(
      moduleKey: ModuleKeys.dashboard,
      label: 'Dashboard',
      path: AppRoutes.dashboardPath,
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard,
      plannedPhase: 15,
      inMobilePrimary: true,
      sortOrder: 10,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.showrooms,
      label: 'Showrooms',
      path: AppRoutes.showroomsPath,
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront,
      plannedPhase: 7,
      sortOrder: 20,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.vehicles,
      label: 'Vehicles',
      path: AppRoutes.vehiclesPath,
      icon: Icons.two_wheeler_outlined,
      selectedIcon: Icons.two_wheeler,
      plannedPhase: 8,
      sortOrder: 30,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.inventory,
      label: 'Inventory',
      path: AppRoutes.inventoryPath,
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      plannedPhase: 9,
      inMobilePrimary: true,
      sortOrder: 40,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.purchases,
      label: 'Purchases',
      path: AppRoutes.purchasesPath,
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
      plannedPhase: 10,
      sortOrder: 50,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.suppliers,
      label: 'Suppliers',
      path: AppRoutes.suppliersPath,
      icon: Icons.local_shipping_outlined,
      selectedIcon: Icons.local_shipping,
      plannedPhase: 10,
      sortOrder: 60,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.sales,
      label: 'Sales',
      path: AppRoutes.salesPath,
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      plannedPhase: 11,
      inMobilePrimary: true,
      sortOrder: 70,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.customers,
      label: 'Customers',
      path: AppRoutes.customersPath,
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      plannedPhase: 11,
      sortOrder: 80,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.bookings,
      label: 'Bookings',
      path: AppRoutes.bookingsPath,
      icon: Icons.event_available_outlined,
      selectedIcon: Icons.event_available,
      plannedPhase: 11,
      sortOrder: 90,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.finance,
      label: 'Finance',
      path: AppRoutes.financePath,
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      plannedPhase: 13,
      inMobilePrimary: true,
      sortOrder: 100,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.accounting,
      label: 'Accounting',
      path: AppRoutes.accountingPath,
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      plannedPhase: 12,
      sortOrder: 110,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.expenses,
      label: 'Expenses',
      path: AppRoutes.expensesPath,
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      plannedPhase: 13,
      sortOrder: 120,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.income,
      label: 'Income',
      path: AppRoutes.incomePath,
      icon: Icons.savings_outlined,
      selectedIcon: Icons.savings,
      plannedPhase: 13,
      sortOrder: 130,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.reports,
      label: 'Reports',
      path: AppRoutes.reportsPath,
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      plannedPhase: 16,
      sortOrder: 140,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.approvals,
      label: 'Approvals',
      path: AppRoutes.approvalsPath,
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check,
      plannedPhase: 21,
      sortOrder: 150,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.documents,
      label: 'Documents',
      path: AppRoutes.documentsPath,
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      plannedPhase: 19,
      sortOrder: 160,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.notifications,
      label: 'Notifications',
      path: AppRoutes.notificationsPath,
      icon: Icons.notifications_none,
      selectedIcon: Icons.notifications,
      plannedPhase: 18,
      sortOrder: 170,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.users,
      label: 'Users',
      path: AppRoutes.usersPath,
      icon: Icons.manage_accounts_outlined,
      selectedIcon: Icons.manage_accounts,
      plannedPhase: 6,
      sortOrder: 180,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.roles,
      label: 'Roles & Permissions',
      path: AppRoutes.rolesPath,
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings,
      plannedPhase: 6,
      sortOrder: 190,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.audit,
      label: 'Audit Logs',
      path: AppRoutes.auditPath,
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      plannedPhase: 20,
      sortOrder: 200,
    ),
    NavigationEntry(
      moduleKey: ModuleKeys.settings,
      label: 'Settings',
      path: AppRoutes.settingsPath,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      plannedPhase: 7,
      sortOrder: 210,
    ),
  ];

  static const List<NavigationEntry> sidebarEntries = entries;

  static List<NavigationEntry> visibleFor(Iterable<String>? granted) {
    return entries
        .where((NavigationEntry e) => e.isVisibleFor(granted))
        .toList();
  }

  static List<NavigationEntry> mobilePrimary(Iterable<String>? granted) {
    return visibleFor(
      granted,
    ).where((NavigationEntry e) => e.inMobilePrimary).toList();
  }

  /// Returns "More" entries (not primary navigation), used to build the
  /// mobile / tablet "More" screen.
  static List<NavigationEntry> secondary(Iterable<String>? granted) {
    return visibleFor(
      granted,
    ).where((NavigationEntry e) => !e.inMobilePrimary).toList();
  }

  static NavigationEntry? byPath(String path) {
    for (final NavigationEntry entry in entries) {
      if (entry.path == path) {
        return entry;
      }
    }
    return null;
  }

  static String labelForPath(String path) {
    final NavigationEntry? entry = byPath(path);
    return entry?.label ?? 'MyBike';
  }
}
