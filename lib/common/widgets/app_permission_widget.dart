import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';

/// Renders [child] only when the caller holds [permission] (`module.action`).
///
/// UI convenience only — RLS enforces the rule (G1). [permissions] defaults to
/// the signed-in user's permissions in the current showroom; the widget fails
/// closed: signed out, still loading or no showroom chosen → [fallback].
///
/// ```dart
/// AppPermissionWidget(
///   permission: 'users.create',
///   child: AppButton(text: 'New user', onPressed: openForm),
/// )
/// ```
class AppPermissionWidget extends ConsumerWidget {
  const AppPermissionWidget({
    required this.permission,
    required this.child,
    this.permissions,
    this.fallback,
    super.key,
  });

  /// The permission code that must be granted, e.g. `sales.create`.
  final String permission;

  /// Overrides the session permissions (tests, previews).
  final Set<String>? permissions;

  /// Shown instead of [child]; defaults to nothing.
  final Widget? fallback;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> granted = permissions ?? ref.watch(currentPermissionsProvider);
    return granted.contains(permission) ? child : (fallback ?? const SizedBox.shrink());
  }
}
