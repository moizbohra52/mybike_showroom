import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/constants/module_keys.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/routes/navigation_registry.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/roles/application/roles_controller.dart';
import 'package:mybike_showroom/features/roles/domain/role_admin.dart';
import 'package:mybike_showroom/features/roles/presentation/roles_screen.dart';

/// A role and its permission matrix (module × action). Chips are editable
/// only where the server allows it: can_edit_role(), and granting only
/// permissions the caller holds globally. The database re-checks each change.
class RoleDetailScreen extends ConsumerWidget {
  const RoleDetailScreen({required this.roleId, super.key});

  final String roleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RoleDetail> detail = ref.watch(roleDetailProvider(roleId));
    final AsyncValue<List<PermissionEntry>> catalogue = ref.watch(permissionCatalogueProvider);
    return Scaffold(
      body: SafeArea(
        child: AppAsyncView<List<PermissionEntry>>(
          value: catalogue,
          onRetry: () => ref.invalidate(permissionCatalogueProvider),
          data: (List<PermissionEntry> permissions) => AppAsyncView<RoleDetail>(
            value: detail,
            onRetry: () => ref.invalidate(roleDetailProvider(roleId)),
            data: (RoleDetail data) => RoleDetailView(detail: data, permissions: permissions),
          ),
        ),
      ),
    );
  }
}

class RoleDetailView extends ConsumerWidget {
  const RoleDetailView({required this.detail, required this.permissions, super.key});

  final RoleDetail detail;
  final List<PermissionEntry> permissions;

  static const String deletePermission = 'roles.delete';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final AppRole role = detail.role;
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final bool callerIsSuperAdmin = state is SignedIn && (state.session?.isSuperAdmin ?? false);
    final Set<String> callerGlobal =
        state is SignedIn ? state.session?.globalPermissions ?? const <String>{} : const <String>{};

    return ListView(
      padding: context.pagePadding,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(AppRoutes.rolesPath),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Roles'),
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: AppDimensions.space12,
                runSpacing: AppDimensions.space8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(role.name, style: Theme.of(context).textTheme.headlineSmall),
                  RoleBadges(role: role),
                ],
              ),
              const SizedBox(height: AppDimensions.space4),
              Text('${role.code} · rank ${role.precedence}', style: TextStyle(color: palette.textSecondary)),
              if (role.description != null) ...<Widget>[
                const SizedBox(height: AppDimensions.space8),
                Text(role.description!),
              ],
              if (role.isSuperAdmin) ...<Widget>[
                const SizedBox(height: AppDimensions.space12),
                const Text('Super Admin always holds every permission; its matrix cannot be changed.'),
              ] else if (!detail.canEdit) ...<Widget>[
                const SizedBox(height: AppDimensions.space12),
                const Text('Read only: you can change only roles ranking below your own.'),
              ],
              if (detail.canEdit) ...<Widget>[
                const SizedBox(height: AppDimensions.space16),
                Wrap(
                  spacing: AppDimensions.space8,
                  runSpacing: AppDimensions.space8,
                  children: <Widget>[
                    AppOutlinedButton(
                      text: 'Edit role',
                      icon: Icons.edit_outlined,
                      onPressed: () => RoleFormDialog.show(context, role: role),
                    ),
                    if (!role.isSystem)
                      AppPermissionWidget(
                        permission: deletePermission,
                        child: AppButton(
                          text: 'Delete role',
                          icon: Icons.delete_outline,
                          variant: AppButtonVariant.danger,
                          onPressed: () async {
                            final bool ok = await AppConfirmDialog.show(
                              context: context,
                              title: 'Delete ${role.name}?',
                              message: 'A role that is still assigned to someone cannot be deleted.',
                              confirmLabel: 'Delete',
                              isDestructive: true,
                            );
                            if (!ok || !context.mounted) {
                              return;
                            }
                            final bool deleted = await AppFeedback.run(
                              context,
                              () => ref.read(roleAdminActionsProvider).delete(role.id),
                              success: 'Role deleted.',
                            );
                            if (deleted && context.mounted) {
                              context.go(AppRoutes.rolesPath);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.space24),
        AppSectionHeader(
          title: 'Permissions',
          subtitle: '${detail.grantedPermissionIds.length} of ${permissions.length} granted',
        ),
        PermissionMatrix(
          permissions: permissions,
          granted: detail.grantedPermissionIds,
          canToggle: (PermissionEntry p, {required bool isGranted}) =>
              detail.canEdit &&
              !role.isSuperAdmin &&
              p.action != PermissionMatrix.viewAllAction &&
              (isGranted || callerIsSuperAdmin || callerGlobal.contains(p.code)),
          onToggle: (PermissionEntry p, {required bool grant}) => AppFeedback.run(
            context,
            () => ref.read(roleAdminActionsProvider).setPermission(role.id, p.id, granted: grant),
          ),
        ),
      ],
    );
  }
}

/// Module rows with one chip per action. Responsive: label beside the chips
/// on wide screens, above them on phones.
class PermissionMatrix extends StatelessWidget {
  const PermissionMatrix({
    required this.permissions,
    required this.granted,
    required this.canToggle,
    required this.onToggle,
    super.key,
  });

  final List<PermissionEntry> permissions;
  final Set<String> granted;
  final bool Function(PermissionEntry permission, {required bool isGranted}) canToggle;
  final void Function(PermissionEntry permission, {required bool grant}) onToggle;

  static const String viewAllAction = 'view_all';
  static const List<String> actionOrder = <String>[...PermissionActions.all, viewAllAction];

  static String actionLabel(String action) => switch (action) {
        viewAllAction => 'All showrooms',
        _ => '${action[0].toUpperCase()}${action.substring(1)}',
      };

  static String moduleLabel(String module) {
    for (final NavigationEntry entry in NavigationRegistry.entries) {
      if (entry.moduleKey == module) {
        return entry.label;
      }
    }
    return module;
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = context.isCompactLayout;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (final String module in ModuleKeys.all)
            if (permissions.any((PermissionEntry p) => p.module == module))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16, vertical: AppDimensions.space12),
                child: Flex(
                  direction: compact ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: compact ? null : 200,
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppDimensions.space8, bottom: AppDimensions.space4),
                        child: Text(moduleLabel(module), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    Flexible(
                      fit: compact ? FlexFit.loose : FlexFit.tight,
                      child: Wrap(
                        spacing: AppDimensions.space8,
                        runSpacing: AppDimensions.space8,
                        children: <Widget>[
                          for (final String action in actionOrder)
                            for (final PermissionEntry p in permissions)
                              if (p.module == module && p.action == action)
                                FilterChip(
                                  label: Text(actionLabel(action)),
                                  tooltip: p.code,
                                  selected: granted.contains(p.id),
                                  onSelected: canToggle(p, isGranted: granted.contains(p.id))
                                      ? (bool value) => onToggle(p, grant: value)
                                      : null,
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
