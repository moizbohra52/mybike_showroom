import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:mybike_showroom/features/roles/domain/role_admin.dart';

import '../../helpers/fake_admin_repositories.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_app.dart';

const AppRole floorLead =
    AppRole(id: 'r-fl', code: 'FLOOR_LEAD', name: 'Floor Lead', precedence: 60, isSystem: false, isActive: true);
const AppRole superAdmin =
    AppRole(id: 'r-sa', code: 'SUPER_ADMIN', name: 'Super Admin', precedence: 100, isSystem: true, isActive: true);

const List<PermissionEntry> catalogue = <PermissionEntry>[
  PermissionEntry(id: 'p-sales-view', module: 'sales', action: 'view'),
  PermissionEntry(id: 'p-sales-create', module: 'sales', action: 'create'),
  PermissionEntry(id: 'p-showrooms-all', module: 'showrooms', action: 'view_all'),
];

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> openRoles(
  WidgetTester tester,
  FakeRolesRepository roles, {
  Set<String> permissions = const <String>{'dashboard.view', 'roles.view', 'roles.edit', 'roles.create'},
  Set<String> globalPermissions = const <String>{'sales.view'},
  String path = AppRoutes.rolesPath,
}) async {
  final UserSession session = testSession(
    showrooms: <SessionShowroom>[testShowroom('s-ind', 'Indore Main', permissions: permissions)],
    globalPermissions: globalPermissions,
  );
  final (_, GoRouter router) = await pumpMyBikeApp(
    tester,
    size: const Size(1280, 900),
    auth: FakeAuthRepository(session: session, signedIn: true),
    roles: roles,
  );
  router.go(path);
  await settle(tester);
}

FilterChip chip(WidgetTester tester, String label) => tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));

void main() {
  testWidgets('roles list; New role needs roles.create', (WidgetTester tester) async {
    final FakeRolesRepository roles = FakeRolesRepository(roleList: <AppRole>[superAdmin, floorLead], catalogue: catalogue);
    await openRoles(tester, roles);
    expect(find.text('Floor Lead'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'New role'), findsOneWidget);
  });

  testWidgets('without roles.create there is no New role button', (WidgetTester tester) async {
    final FakeRolesRepository roles = FakeRolesRepository(roleList: <AppRole>[floorLead], catalogue: catalogue);
    await openRoles(tester, roles, permissions: <String>{'dashboard.view', 'roles.view'});
    expect(find.text('Floor Lead'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'New role'), findsNothing);
  });

  testWidgets('matrix: grants a permission the caller holds; others stay locked', (WidgetTester tester) async {
    final FakeRolesRepository roles = FakeRolesRepository(
      roleList: <AppRole>[floorLead],
      catalogue: catalogue,
      details: <String, RoleDetail>{
        'r-fl': const RoleDetail(role: floorLead, grantedPermissionIds: <String>{}, canEdit: true),
      },
    );
    await openRoles(tester, roles, path: AppRoutes.roleDetailPath('r-fl'));

    expect(chip(tester, 'Create').onSelected, isNull, reason: 'caller does not hold sales.create globally');
    expect(chip(tester, 'All showrooms').onSelected, isNull, reason: 'showrooms.view_all is Super Admin only');

    await tester.tap(find.widgetWithText(FilterChip, 'View'));
    await settle(tester);
    expect(roles.calls, <String>['grant r-fl p-sales-view']);
  });

  testWidgets('matrix: read only when the server says the role is not editable', (WidgetTester tester) async {
    final FakeRolesRepository roles = FakeRolesRepository(
      roleList: <AppRole>[floorLead],
      catalogue: catalogue,
      details: <String, RoleDetail>{
        'r-fl': const RoleDetail(role: floorLead, grantedPermissionIds: <String>{'p-sales-view'}, canEdit: false),
      },
    );
    await openRoles(tester, roles, path: AppRoutes.roleDetailPath('r-fl'));

    expect(find.textContaining('Read only'), findsOneWidget);
    expect(chip(tester, 'View').selected, isTrue);
    expect(chip(tester, 'View').onSelected, isNull);
    expect(find.text('Edit role'), findsNothing);
  });

  testWidgets('matrix: Super Admin is locked even for an editor', (WidgetTester tester) async {
    final FakeRolesRepository roles = FakeRolesRepository(
      roleList: <AppRole>[superAdmin],
      catalogue: catalogue,
      details: <String, RoleDetail>{
        'r-sa': const RoleDetail(
          role: superAdmin,
          grantedPermissionIds: <String>{'p-sales-view', 'p-sales-create', 'p-showrooms-all'},
          canEdit: true,
        ),
      },
    );
    await openRoles(tester, roles, path: AppRoutes.roleDetailPath('r-sa'));

    expect(find.textContaining('always holds every permission'), findsOneWidget);
    for (final String label in <String>['View', 'Create', 'All showrooms']) {
      expect(chip(tester, label).onSelected, isNull);
    }
    expect(find.text('Delete role'), findsNothing, reason: 'system roles cannot be deleted');
  });
}
