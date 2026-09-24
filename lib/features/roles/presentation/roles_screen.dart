import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/validators/validators.dart';
import 'package:mybike_showroom/features/roles/application/roles_controller.dart';
import 'package:mybike_showroom/features/roles/domain/role_admin.dart';

/// Roles list. Rank (precedence) decides who may grant or edit a role: only
/// people ranking above it (Super Admin: any).
class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  static const String createPermission = 'roles.create';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppRole>> roles = ref.watch(roleListProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: context.pagePadding,
          children: <Widget>[
            AppSectionHeader(
              title: 'Roles & permissions',
              subtitle: 'What each role may do. Higher-ranked roles manage lower-ranked ones.',
              trailing: AppPermissionWidget(
                permission: createPermission,
                child: AppButton(
                  text: 'New role',
                  icon: Icons.add_moderator_outlined,
                  onPressed: () async {
                    final String? id = await RoleFormDialog.show(context);
                    if (id != null && context.mounted) {
                      context.go(AppRoutes.roleDetailPath(id));
                    }
                  },
                ),
              ),
            ),
            AppAsyncView<List<AppRole>>(
              value: roles,
              onRetry: () => ref.invalidate(roleListProvider),
              data: (List<AppRole> list) => context.isCompactLayout
                  ? Column(
                      children: <Widget>[
                        for (final AppRole role in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                            child: AppCard(
                              onTap: () => context.go(AppRoutes.roleDetailPath(role.id)),
                              child: RoleSummary(role: role),
                            ),
                          ),
                      ],
                    )
                  : AppDataTable<AppRole>(
                      items: list,
                      onRowTap: (AppRole role) => context.go(AppRoutes.roleDetailPath(role.id)),
                      columns: <AppDataTableColumn<AppRole>>[
                        AppDataTableColumn<AppRole>(title: 'Role', flex: 3, cellBuilder: (_, AppRole r) => RoleSummary(role: r)),
                        AppDataTableColumn<AppRole>(title: 'Rank', cellBuilder: (_, AppRole r) => Text('${r.precedence}')),
                        AppDataTableColumn<AppRole>(title: 'Type', cellBuilder: (_, AppRole r) => RoleBadges(role: r)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoleSummary extends StatelessWidget {
  const RoleSummary({required this.role, super.key});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(role.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        Text(
          context.isCompactLayout ? '${role.code} · rank ${role.precedence}' : role.code,
          style: TextStyle(color: palette.textSecondary, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        if (context.isCompactLayout) ...<Widget>[
          const SizedBox(height: AppDimensions.space4),
          RoleBadges(role: role),
        ],
      ],
    );
  }
}

class RoleBadges extends StatelessWidget {
  const RoleBadges({required this.role, super.key});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.space4,
      children: <Widget>[
        AppStatusBadge(label: role.isSystem ? 'System' : 'Custom', intent: role.isSystem ? AppStatusIntent.info : AppStatusIntent.neutral),
        if (!role.isActive) const AppStatusBadge(label: 'Inactive', intent: AppStatusIntent.warning),
      ],
    );
  }
}

/// Creates a role (returns its id) or edits [role] (returns the id).
class RoleFormDialog extends ConsumerStatefulWidget {
  const RoleFormDialog({this.role, super.key});

  final AppRole? role;

  static Future<String?> show(BuildContext context, {AppRole? role}) =>
      showDialog<String>(context: context, builder: (_) => RoleFormDialog(role: role));

  @override
  ConsumerState<RoleFormDialog> createState() => RoleFormDialogState();
}

class RoleFormDialogState extends ConsumerState<RoleFormDialog> {
  static final RegExp codePattern = RegExp(r'^[A-Z][A-Z0-9_]{1,39}$');

  late final TextEditingController code = TextEditingController(text: widget.role?.code);
  late final TextEditingController name = TextEditingController(text: widget.role?.name);
  late final TextEditingController description = TextEditingController(text: widget.role?.description);
  late final TextEditingController precedence = TextEditingController(text: widget.role?.precedence.toString() ?? '40');
  late bool isActive = widget.role?.isActive ?? true;

  bool get isNew => widget.role == null;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[code, name, description, precedence]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<String> submit() async {
    final RoleDraft draft = RoleDraft(
      code: code.text,
      name: name.text,
      description: description.text,
      precedence: int.parse(precedence.text),
      isActive: isActive,
    );
    final RoleAdminActions actions = ref.read(roleAdminActionsProvider);
    if (isNew) {
      return actions.create(draft);
    }
    await actions.update(widget.role!.id, draft);
    return widget.role!.id;
  }

  @override
  Widget build(BuildContext context) {
    final bool system = widget.role?.isSystem ?? false;
    return AppFormDialog<String>(
      title: isNew ? 'New role' : 'Edit role',
      subtitle: isNew ? null : widget.role!.code,
      submitLabel: isNew ? 'Create role' : 'Save',
      onSubmit: submit,
      children: <Widget>[
        if (isNew)
          AppTextField(
            controller: code,
            label: 'Code',
            hint: 'FLOOR_LEAD',
            helperText: 'Capital letters, digits and _; cannot be changed later.',
            validator: (String? v) =>
                codePattern.hasMatch((v ?? '').trim().toUpperCase()) ? null : 'Use 2–40 capital letters, digits or _, starting with a letter.',
          ),
        AppTextField(controller: name, label: 'Name', validator: (String? v) => Validators.required(v, field: 'Name')),
        AppTextField(controller: description, label: 'Description', maxLines: 3),
        AppTextField(
          controller: precedence,
          label: 'Rank',
          helperText: 'Higher ranks manage lower ones. Custom roles: 1–${AppRole.maxCustomPrecedence}, below your own rank.',
          keyboardType: TextInputType.number,
          readOnly: system,
          validator: (String? v) {
            final int? n = int.tryParse(v ?? '');
            final int max = system ? 1000 : AppRole.maxCustomPrecedence;
            return n != null && n >= 1 && n <= max ? null : 'Enter a number from 1 to $max.';
          },
        ),
        if (!isNew)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            subtitle: Text(system ? 'System roles are always active.' : 'Inactive roles grant nothing.'),
            value: isActive,
            onChanged: system ? null : (bool v) => setState(() => isActive = v),
          ),
      ],
    );
  }
}
