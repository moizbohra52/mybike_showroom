import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/validators/validators.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:mybike_showroom/features/auth/presentation/access_blocked_screen.dart';
import 'package:mybike_showroom/features/users/domain/user_admin.dart';

import '../../helpers/fake_admin_repositories.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_app.dart';

const Size desktop = Size(1280, 900);
const Size phone = Size(390, 844);

const Set<String> managerPermissions = <String>{'dashboard.view', 'users.view', 'users.create', 'users.edit'};

Future<GoRouter> openUsers(
  WidgetTester tester,
  Set<String> permissions, {
  FakeUsersRepository? users,
  Size size = desktop,
  String path = AppRoutes.usersPath,
}) async {
  final UserSession session = testSession(
    showrooms: <SessionShowroom>[testShowroom('s-ind', 'Indore Main', permissions: permissions)],
  );
  final (_, GoRouter router) = await pumpMyBikeApp(
    tester,
    size: size,
    auth: FakeAuthRepository(session: session, signedIn: true),
    users: users ?? FakeUsersRepository(users: <ManagedUser>[salesExec]),
  );
  router.go(path);
  await settle(tester);
  return router;
}

/// The shell has perpetual animations; pump fixed frames instead of settling.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('the list shows visible users and starts at the current showroom', (WidgetTester tester) async {
    final FakeUsersRepository users = FakeUsersRepository(users: <ManagedUser>[salesExec]);
    await openUsers(tester, managerPermissions, users: users);

    expect(find.text('Imran Khan'), findsOneWidget);
    expect(find.text('Sales Executive'), findsOneWidget);
    expect(users.queries.first.showroomId, 's-ind');
    expect(find.widgetWithText(AppButton, 'New user'), findsOneWidget);
  });

  testWidgets('phones get cards instead of the table', (WidgetTester tester) async {
    await openUsers(tester, managerPermissions, size: phone);

    expect(find.byType(AppDataTable<ManagedUser>), findsNothing);
    expect(find.text('Imran Khan'), findsOneWidget);
  });

  testWidgets('users.view alone (sales manager) cannot create users', (WidgetTester tester) async {
    await openUsers(tester, <String>{'dashboard.view', 'users.view'});

    expect(find.text('Imran Khan'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'New user'), findsNothing);
  });

  testWidgets('without users.view (cashier) the module is hidden and forbidden', (WidgetTester tester) async {
    await openUsers(tester, <String>{'dashboard.view', 'sales.view'}, path: AppRoutes.userDetailPath('u-exec'));

    expect(find.byType(AccessBlockedScreen), findsOneWidget);
    expect(find.text('Access denied'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Users'), findsNothing);
  });

  testWidgets('a manageable user is deactivated only after confirmation', (WidgetTester tester) async {
    final FakeUsersRepository users = FakeUsersRepository(accessById: <String, UserAccess>{'u-exec': testAccess()});
    await openUsers(tester, managerPermissions, users: users, path: AppRoutes.userDetailPath('u-exec'));

    await tester.tap(find.widgetWithText(AppButton, 'Deactivate'));
    await settle(tester);
    expect(find.text('Deactivate Imran Khan?'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Deactivate').last);
    await settle(tester);

    expect(users.calls, <String>['setStatus u-exec deactivated']);
    expect(find.text('User deactivated.'), findsOneWidget);
  });

  testWidgets('without manage rights no action is offered', (WidgetTester tester) async {
    final FakeUsersRepository users = FakeUsersRepository(
      accessById: <String, UserAccess>{'u-exec': testAccess(canManage: false, hiddenShowroomCount: 1)},
    );
    await openUsers(tester, managerPermissions, users: users, path: AppRoutes.userDetailPath('u-exec'));

    expect(find.text('Imran Khan'), findsOneWidget);
    expect(find.text('Deactivate'), findsNothing);
    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('Add role'), findsNothing);
    expect(find.byTooltip('Remove role'), findsNothing);
    expect(find.textContaining('outside your access'), findsOneWidget);
  });

  testWidgets('own account: notice, no actions', (WidgetTester tester) async {
    final FakeUsersRepository users = FakeUsersRepository(
      accessById: <String, UserAccess>{'u-exec': testAccess(canManage: false, isSelf: true)},
    );
    await openUsers(tester, managerPermissions, users: users, path: AppRoutes.userDetailPath('u-exec'));

    expect(find.textContaining('This is your own account'), findsOneWidget);
    expect(find.text('Set password'), findsNothing);
  });

  testWidgets('a refused change shows the friendly permission message', (WidgetTester tester) async {
    final FakeUsersRepository users = FakeUsersRepository(
      accessById: <String, UserAccess>{'u-exec': testAccess()},
      failWith: const PermissionFailure(),
    );
    await openUsers(tester, managerPermissions, users: users, path: AppRoutes.userDetailPath('u-exec'));

    await tester.tap(find.byTooltip('Remove role'));
    await settle(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Remove role'));
    await settle(tester);

    expect(users.calls, <String>['revokeRole a-1']);
    expect(find.text(FailureMessages.permission), findsOneWidget);
  });

  testWidgets('create user validates, sends the request and opens the new user', (WidgetTester tester) async {
    final FakeUsersRepository users = FakeUsersRepository(users: <ManagedUser>[salesExec]);
    final GoRouter router = await openUsers(tester, managerPermissions, users: users);

    await tester.tap(find.widgetWithText(AppButton, 'New user'));
    await settle(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Create user'));
    await settle(tester);
    expect(find.text('Full name is required.'), findsOneWidget);
    expect(users.created, isNull);

    final Finder fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextFormField));
    await tester.enterText(fields.at(0), 'New Exec');
    await tester.enterText(fields.at(1), 'new.exec@mybike.test');
    await tester.enterText(fields.at(5), 'Welcome@2026');
    // Open the role dropdown and pick the grantable role.
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>).last);
    await settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await settle(tester);
    await tester.tap(find.text('Sales Executive').last);
    await settle(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Create user'));
    await settle(tester);

    expect(users.created?.email, 'new.exec@mybike.test');
    expect(users.created?.showroomId, 's-ind');
    expect(users.created?.roleId, 'r-se');
    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.userDetailPath('new-user'));
  });

  group('validators match the database rules', () {
    test('password: 10+ characters with lower, upper and digit', () {
      expect(Validators.password('Welcome@2026'), isNull);
      expect(Validators.password('welcome2026'), isNotNull);
      expect(Validators.password('Short1a'), isNotNull);
    });

    test('phone and employee code are optional but checked', () {
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('+919800000001'), isNull);
      expect(Validators.phone('98-00'), isNotNull);
      expect(Validators.employeeCode('mb-0015'), isNull);
      expect(Validators.employeeCode('x'), isNotNull);
    });
  });

  test('UserAccess parses the rpc_get_user_access payload', () {
    final UserAccess access = UserAccess.fromJson(const <String, Object?>{
      'profile': <String, Object?>{'id': 'u1', 'full_name': 'A', 'status': 'active', 'email': 'a@x.in'},
      'is_self': false,
      'can_manage': true,
      'global': <String, Object?>{'can_manage': false, 'roles': <Object?>[], 'grantable_roles': <Object?>[]},
      'showrooms': <Object?>[
        <String, Object?>{
          'id': 's1',
          'code': 'IND',
          'name': 'Indore',
          'is_active': true,
          'can_manage': true,
          'roles': <Object?>[
            <String, Object?>{'assignment_id': 'a1', 'role_id': 'r1', 'code': 'CASHIER', 'name': 'Cashier', 'is_usable': true},
          ],
          'grantable_roles': <Object?>[
            <String, Object?>{'id': 'r2', 'code': 'VIEWER', 'name': 'Viewer'},
          ],
        },
      ],
      'hidden_showroom_count': 2,
      'addable_showrooms': <Object?>[
        <String, Object?>{'id': 's2', 'code': 'BPL', 'name': 'Bhopal'},
      ],
    });

    expect(access.canManage, isTrue);
    expect(access.global.isGlobal, isTrue);
    expect(access.showrooms.single.roles.single.code, 'CASHIER');
    expect(access.showrooms.single.grantableRoles.single.name, 'Viewer');
    expect(access.hiddenShowroomCount, 2);
    expect(access.addableShowrooms.single.name, 'Bhopal');
  });
}
