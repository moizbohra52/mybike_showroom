import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/core/validators/validators.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:mybike_showroom/features/users/application/users_controller.dart';
import 'package:mybike_showroom/features/users/domain/user_admin.dart';

const ValidationFailure chooseShowroomAndRole = ValidationFailure(message: 'Choose a showroom and a role.');

/// Creates a user with an initial password, a showroom and a first role
/// (admin-users Edge Function). Returns the new user id.
class CreateUserDialog extends ConsumerStatefulWidget {
  const CreateUserDialog({super.key});

  static Future<String?> show(BuildContext context) =>
      showDialog<String>(context: context, builder: (_) => const CreateUserDialog());

  @override
  ConsumerState<CreateUserDialog> createState() => CreateUserDialogState();
}

class CreateUserDialogState extends ConsumerState<CreateUserDialog> {
  final TextEditingController name = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController designation = TextEditingController();
  final TextEditingController employeeCode = TextEditingController();
  final TextEditingController password = TextEditingController();
  String? showroomId;
  String? roleId;

  /// Showrooms where the session grants users.create (UI hint; the Edge
  /// Function and RLS re-check).
  List<SessionShowroom> get showrooms {
    final SessionState? state = ref.read(sessionControllerProvider).value;
    final List<SessionShowroom> all = state is SignedIn ? state.session?.showrooms ?? const <SessionShowroom>[] : const <SessionShowroom>[];
    return <SessionShowroom>[for (final SessionShowroom s in all) if (s.permissions.contains('users.create')) s];
  }

  @override
  void initState() {
    super.initState();
    final SessionState? state = ref.read(sessionControllerProvider).value;
    final String? current = state is SignedIn ? state.selection?.showroomId : null;
    final List<SessionShowroom> options = showrooms;
    showroomId = options.any((SessionShowroom s) => s.id == current) ? current : (options.isEmpty ? null : options.first.id);
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[name, email, phone, designation, employeeCode, password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<String> submit() {
    if (showroomId == null || roleId == null) {
      throw chooseShowroomAndRole;
    }
    return ref.read(userAdminActionsProvider).create(NewUserRequest(
          email: email.text,
          password: password.text,
          fullName: name.text,
          showroomId: showroomId!,
          roleId: roleId!,
          phone: phone.text,
          designation: designation.text,
          employeeCode: employeeCode.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final List<RoleOption> roles =
        showroomId == null ? const <RoleOption>[] : ref.watch(grantableRolesProvider(showroomId)).value ?? const <RoleOption>[];
    return AppFormDialog<String>(
      title: 'New user',
      subtitle: 'The user signs in with this email and the initial password.',
      submitLabel: 'Create user',
      onSubmit: submit,
      children: <Widget>[
        AppTextField(
          controller: name,
          label: 'Full name',
          validator: (String? v) => Validators.required(v, field: 'Full name'),
        ),
        AppTextField(
          controller: email,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
          validator: Validators.email,
        ),
        AppTextField(controller: phone, label: 'Phone (optional)', keyboardType: TextInputType.phone, validator: Validators.phone),
        AppTextField(controller: designation, label: 'Designation (optional)'),
        AppTextField(controller: employeeCode, label: 'Employee code (optional)', validator: Validators.employeeCode),
        AppTextField(
          controller: password,
          label: 'Initial password',
          obscureText: true,
          helperText: 'Share it with the user privately; they can change it later.',
          validator: Validators.password,
        ),
        AppDropdown<String>(
          label: 'Showroom',
          value: showroomId,
          items: <AppDropdownItem<String>>[
            for (final SessionShowroom s in showrooms) AppDropdownItem<String>(value: s.id, label: s.name),
          ],
          onChanged: (String? id) => setState(() {
            showroomId = id;
            roleId = null;
          }),
        ),
        AppDropdown<String>(
          // Rebuilt per showroom: the field keeps its own selection.
          key: ValueKey<String?>('role-$showroomId'),
          label: 'Role',
          value: roleId,
          enabled: roles.isNotEmpty,
          hint: roles.isEmpty ? 'No role you can grant here' : null,
          items: <AppDropdownItem<String>>[
            for (final RoleOption r in roles) AppDropdownItem<String>(value: r.id, label: r.name),
          ],
          onChanged: (String? id) => setState(() => roleId = id),
        ),
      ],
    );
  }
}

/// Name, phone, designation and employee code of another user.
class EditProfileDialog extends ConsumerStatefulWidget {
  const EditProfileDialog({required this.user, super.key});

  final ManagedUser user;

  static Future<bool?> show(BuildContext context, ManagedUser user) =>
      showDialog<bool>(context: context, builder: (_) => EditProfileDialog(user: user));

  @override
  ConsumerState<EditProfileDialog> createState() => EditProfileDialogState();
}

class EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  late final TextEditingController name = TextEditingController(text: widget.user.fullName);
  late final TextEditingController phone = TextEditingController(text: widget.user.phone);
  late final TextEditingController designation = TextEditingController(text: widget.user.designation);
  late final TextEditingController employeeCode = TextEditingController(text: widget.user.employeeCode);

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[name, phone, designation, employeeCode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> submit() async {
    await ref.read(userAdminActionsProvider).updateProfile(
          widget.user.id,
          UserProfileUpdate(fullName: name.text, phone: phone.text, designation: designation.text, employeeCode: employeeCode.text),
        );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog<bool>(
      title: 'Edit profile',
      subtitle: widget.user.email,
      onSubmit: submit,
      children: <Widget>[
        AppTextField(controller: name, label: 'Full name', validator: (String? v) => Validators.required(v, field: 'Full name')),
        AppTextField(controller: phone, label: 'Phone', keyboardType: TextInputType.phone, validator: Validators.phone),
        AppTextField(controller: designation, label: 'Designation'),
        AppTextField(controller: employeeCode, label: 'Employee code', validator: Validators.employeeCode),
      ],
    );
  }
}

/// Sets a new password for another user (admin-users Edge Function).
class SetPasswordDialog extends ConsumerStatefulWidget {
  const SetPasswordDialog({required this.user, super.key});

  final ManagedUser user;

  static Future<bool?> show(BuildContext context, ManagedUser user) =>
      showDialog<bool>(context: context, builder: (_) => SetPasswordDialog(user: user));

  @override
  ConsumerState<SetPasswordDialog> createState() => SetPasswordDialogState();
}

class SetPasswordDialogState extends ConsumerState<SetPasswordDialog> {
  final TextEditingController password = TextEditingController();
  final TextEditingController confirm = TextEditingController();

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<bool> submit() async {
    await ref.read(userAdminActionsProvider).setPassword(widget.user.id, password.text);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog<bool>(
      title: 'Set a new password',
      subtitle: widget.user.fullName,
      submitLabel: 'Set password',
      onSubmit: submit,
      children: <Widget>[
        AppTextField(controller: password, label: 'New password', obscureText: true, validator: Validators.password),
        AppTextField(
          controller: confirm,
          label: 'Repeat the password',
          obscureText: true,
          validator: (String? v) => v == password.text ? null : 'The passwords do not match.',
        ),
      ],
    );
  }
}

/// Picks one of [options] and grants it in [showroomId] (`null` = globally).
class GrantRoleDialog extends ConsumerStatefulWidget {
  const GrantRoleDialog({required this.userId, required this.showroomId, required this.options, required this.scopeLabel, super.key});

  final String userId;
  final String? showroomId;
  final List<RoleOption> options;
  final String scopeLabel;

  static Future<bool?> show(BuildContext context,
          {required String userId, required String? showroomId, required List<RoleOption> options, required String scopeLabel}) =>
      showDialog<bool>(
        context: context,
        builder: (_) => GrantRoleDialog(userId: userId, showroomId: showroomId, options: options, scopeLabel: scopeLabel),
      );

  @override
  ConsumerState<GrantRoleDialog> createState() => GrantRoleDialogState();
}

class GrantRoleDialogState extends ConsumerState<GrantRoleDialog> {
  String? roleId;

  Future<bool> submit() async {
    if (roleId == null) {
      throw const ValidationFailure(message: 'Choose a role.');
    }
    await ref.read(userAdminActionsProvider).grantRole(widget.userId, roleId!, widget.showroomId);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog<bool>(
      title: 'Add role',
      subtitle: widget.scopeLabel,
      submitLabel: 'Add role',
      onSubmit: submit,
      children: <Widget>[
        AppDropdown<String>(
          label: 'Role',
          value: roleId,
          items: <AppDropdownItem<String>>[
            for (final RoleOption r in widget.options) AppDropdownItem<String>(value: r.id, label: r.name),
          ],
          onChanged: (String? id) => setState(() => roleId = id),
        ),
      ],
    );
  }
}

/// Gives the user access to one more showroom, with a first role there.
class AddShowroomDialog extends ConsumerStatefulWidget {
  const AddShowroomDialog({required this.userId, required this.options, super.key});

  final String userId;
  final List<ShowroomOption> options;

  static Future<bool?> show(BuildContext context, {required String userId, required List<ShowroomOption> options}) =>
      showDialog<bool>(context: context, builder: (_) => AddShowroomDialog(userId: userId, options: options));

  @override
  ConsumerState<AddShowroomDialog> createState() => AddShowroomDialogState();
}

class AddShowroomDialogState extends ConsumerState<AddShowroomDialog> {
  String? showroomId;
  String? roleId;

  Future<bool> submit() async {
    if (showroomId == null || roleId == null) {
      throw chooseShowroomAndRole;
    }
    await ref.read(userAdminActionsProvider).addShowroom(widget.userId, showroomId!, roleId: roleId);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final List<RoleOption> roles =
        showroomId == null ? const <RoleOption>[] : ref.watch(grantableRolesProvider(showroomId)).value ?? const <RoleOption>[];
    return AppFormDialog<bool>(
      title: 'Add showroom',
      submitLabel: 'Add showroom',
      onSubmit: submit,
      children: <Widget>[
        AppDropdown<String>(
          label: 'Showroom',
          value: showroomId,
          items: <AppDropdownItem<String>>[
            for (final ShowroomOption s in widget.options) AppDropdownItem<String>(value: s.id, label: s.name),
          ],
          onChanged: (String? id) => setState(() {
            showroomId = id;
            roleId = null;
          }),
        ),
        AppDropdown<String>(
          key: ValueKey<String?>('role-$showroomId'),
          label: 'Role in this showroom',
          value: roleId,
          enabled: roles.isNotEmpty,
          items: <AppDropdownItem<String>>[
            for (final RoleOption r in roles) AppDropdownItem<String>(value: r.id, label: r.name),
          ],
          onChanged: (String? id) => setState(() => roleId = id),
        ),
      ],
    );
  }
}
