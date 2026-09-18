import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/constants/module_keys.dart';

/// Conditionally renders [child] based on whether the caller holds [permission].
///
/// Phase 2: the permission set is not yet wired to a real session, so the
/// widget defaults to **showing** content (permissive mode) while the
/// authentication + role system (Phase 5/6) is absent.  Once those phases
/// land, callers simply pass the resolved [Set<String>] from the session
/// service and this widget enforces the restriction automatically.
///
/// Usage:
/// ```dart
/// AppPermissionWidget(
///   permission: ModuleKeys.sales,           // required permission key
///   permissions: resolvedPermissionsOrNull, // null → always shows (Phase 2)
///   child: ElevatedButton(onPressed: _sell, child: Text('Sell')),
///   fallback: Text('No access'),            // optional; defaults to SizedBox.shrink()
/// )
/// ```
class AppPermissionWidget extends StatelessWidget {
  const AppPermissionWidget({
    required this.permission,
    required this.child,
    this.permissions,
    this.fallback,
    super.key,
  });

  /// The permission key that must be present in [permissions].
  ///
  /// Use constants from [ModuleKeys] or the role-permission string constants
  /// that will be introduced in Phase 6.
  final String permission;

  /// The resolved set of permission keys for the current user + showroom.
  ///
  /// When `null` (Phase 2 default / Phase 5 loading state) the widget shows
  /// [child] — permissive-by-default while auth is not yet wired.
  final Set<String>? permissions;

  /// Widget to show when [permission] is absent from [permissions].
  ///
  /// Defaults to [SizedBox.shrink] (invisible, zero-size).
  final Widget? fallback;

  /// The widget to render when the caller has [permission].
  final Widget child;

  /// Returns `true` when the user has [permission] or the permissions set is
  /// not yet resolved (`null`).
  bool get _hasAccess => permissions == null || permissions!.contains(permission);

  @override
  Widget build(BuildContext context) {
    return _hasAccess ? child : (fallback ?? const SizedBox.shrink());
  }
}
