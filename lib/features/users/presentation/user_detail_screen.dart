import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/features/users/application/users_controller.dart';
import 'package:mybike_showroom/features/users/domain/user_admin.dart';
import 'package:mybike_showroom/features/users/presentation/user_dialogs.dart';
import 'package:mybike_showroom/features/users/presentation/users_screen.dart';

/// A user's profile, status, global roles and showroom access. Every action
/// is offered only when the server says the caller may do it (rpc flags);
/// RLS re-checks each write.
class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({required this.profileId, super.key});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserAccess?> access = ref.watch(userAccessProvider(profileId));
    return Scaffold(
      body: SafeArea(
        child: AppAsyncView<UserAccess?>(
          value: access,
          onRetry: () => ref.invalidate(userAccessProvider(profileId)),
          data: (UserAccess? data) => data == null
              ? AppEmptyState(
                  title: 'User not found',
                  message: 'The user does not exist or is outside your showrooms.',
                  icon: Icons.person_off_outlined,
                  actionText: 'Back to users',
                  onAction: () => context.go(AppRoutes.usersPath),
                )
              : UserAccessView(access: data),
        ),
      ),
    );
  }
}

class UserAccessView extends ConsumerWidget {
  const UserAccessView({required this.access, super.key});

  final UserAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final ManagedUser user = access.user;
    final UserAdminActions actions = ref.read(userAdminActionsProvider);
    final bool showGlobal = access.global.roles.isNotEmpty || access.global.grantableRoles.isNotEmpty;

    return ListView(
      padding: context.pagePadding,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(AppRoutes.usersPath),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Users'),
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
                  Text(user.fullName, style: Theme.of(context).textTheme.headlineSmall),
                  UserStatusBadge(status: user.status),
                ],
              ),
              const SizedBox(height: AppDimensions.space8),
              for (final String line in <String?>[
                user.email,
                user.phone,
                <String?>[user.designation, user.employeeCode].whereType<String>().join(' · '),
              ].whereType<String>().where((String s) => s.isNotEmpty))
                Text(line, style: TextStyle(color: palette.textSecondary)),
              if (access.isSelf) ...<Widget>[
                const SizedBox(height: AppDimensions.space12),
                const Text('This is your own account. Your access can only be changed by another administrator.'),
              ],
              if (access.canManage) ...<Widget>[
                const SizedBox(height: AppDimensions.space16),
                Wrap(
                  spacing: AppDimensions.space8,
                  runSpacing: AppDimensions.space8,
                  children: <Widget>[
                    AppOutlinedButton(
                      text: 'Edit profile',
                      icon: Icons.edit_outlined,
                      onPressed: () => EditProfileDialog.show(context, user),
                    ),
                    AppOutlinedButton(
                      text: 'Set password',
                      icon: Icons.password,
                      onPressed: () async {
                        if (await SetPasswordDialog.show(context, user) == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed.')));
                        }
                      },
                    ),
                    if (user.isActive)
                      AppButton(
                        text: 'Deactivate',
                        icon: Icons.block,
                        variant: AppButtonVariant.danger,
                        onPressed: () async {
                          final bool ok = await AppConfirmDialog.show(
                            context: context,
                            title: 'Deactivate ${user.fullName}?',
                            message: 'They lose access to every showroom immediately, even if signed in. '
                                'Their records and history stay.',
                            confirmLabel: 'Deactivate',
                            isDestructive: true,
                          );
                          if (ok && context.mounted) {
                            await AppFeedback.run(
                              context,
                              () => actions.setStatus(user.id, UserStatuses.deactivated),
                              success: 'User deactivated.',
                            );
                          }
                        },
                      )
                    else
                      AppButton(
                        text: 'Activate',
                        icon: Icons.check_circle_outline,
                        onPressed: () => AppFeedback.run(
                          context,
                          () => actions.setStatus(user.id, UserStatuses.active),
                          success: 'User activated.',
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (showGlobal) ...<Widget>[
          const SizedBox(height: AppDimensions.space24),
          AccessScopeCard(
            userId: user.id,
            scope: access.global,
            title: 'All showrooms (global roles)',
            subtitle: 'Global roles apply in every showroom the user belongs to.',
          ),
        ],
        const SizedBox(height: AppDimensions.space24),
        AppSectionHeader(
          title: 'Showrooms',
          subtitle: access.hiddenShowroomCount > 0
              ? 'Also assigned to ${access.hiddenShowroomCount} showroom(s) outside your access.'
              : null,
          trailing: access.canManage && access.addableShowrooms.isNotEmpty
              ? AppOutlinedButton(
                  text: 'Add showroom',
                  icon: Icons.add_business_outlined,
                  onPressed: () => AddShowroomDialog.show(context, userId: user.id, options: access.addableShowrooms),
                )
              : null,
        ),
        if (access.showrooms.isEmpty)
          const AppEmptyState(title: 'No showroom assigned', icon: Icons.storefront_outlined)
        else
          for (final AccessScope scope in access.showrooms)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space12),
              child: AccessScopeCard(userId: user.id, scope: scope, title: scope.name ?? scope.code ?? 'Showroom'),
            ),
      ],
    );
  }
}

/// Roles of the user in one scope, with add / remove where allowed.
class AccessScopeCard extends ConsumerWidget {
  const AccessScopeCard({required this.userId, required this.scope, required this.title, this.subtitle, super.key});

  final String userId;
  final AccessScope scope;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final UserAdminActions actions = ref.read(userAdminActionsProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: AppDimensions.space8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (!scope.isActive) const AppStatusBadge(label: 'Inactive', intent: AppStatusIntent.warning),
                  ],
                ),
              ),
              if (!scope.isGlobal && scope.canManage)
                IconButton(
                  tooltip: 'Remove showroom',
                  icon: Icon(Icons.remove_circle_outline, color: palette.danger),
                  onPressed: () async {
                    final bool ok = await AppConfirmDialog.show(
                      context: context,
                      title: 'Remove $title?',
                      message: 'The user loses access to this showroom and every role in it.',
                      confirmLabel: 'Remove',
                      isDestructive: true,
                    );
                    if (ok && context.mounted) {
                      await AppFeedback.run(context, () => actions.removeShowroom(userId, scope.showroomId!),
                          success: 'Showroom removed.');
                    }
                  },
                ),
            ],
          ),
          if (subtitle != null) Text(subtitle!, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
          const SizedBox(height: AppDimensions.space12),
          Wrap(
            spacing: AppDimensions.space8,
            runSpacing: AppDimensions.space8,
            children: <Widget>[
              if (scope.roles.isEmpty) Text('No role', style: TextStyle(color: palette.textSecondary)),
              for (final RoleAssignment role in scope.roles)
                InputChip(
                  label: Text(role.isUsable ? role.name : '${role.name} (inactive)'),
                  onDeleted: scope.canManage
                      ? () async {
                          final bool ok = await AppConfirmDialog.show(
                            context: context,
                            title: 'Remove ${role.name}?',
                            message: 'The permissions of this role stop applying for the user in $title.',
                            confirmLabel: 'Remove role',
                            isDestructive: true,
                          );
                          if (ok && context.mounted) {
                            await AppFeedback.run(context, () => actions.revokeRole(userId, role.assignmentId),
                                success: 'Role removed.');
                          }
                        }
                      : null,
                  deleteButtonTooltipMessage: 'Remove role',
                ),
              if (scope.grantableRoles.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.add, size: AppDimensions.iconSm),
                  label: const Text('Add role'),
                  onPressed: () => GrantRoleDialog.show(
                    context,
                    userId: userId,
                    showroomId: scope.showroomId,
                    options: scope.grantableRoles,
                    scopeLabel: title,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
