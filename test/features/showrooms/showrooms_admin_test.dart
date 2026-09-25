import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/constants/storage_keys.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/storage/preference_store.dart';
import 'package:mybike_showroom/core/validators/validators.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/auth/data/auth_repository.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:mybike_showroom/features/showrooms/domain/showroom_admin.dart';
import 'package:mybike_showroom/features/users/domain/user_admin.dart';

import '../../helpers/fake_admin_repositories.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_preference_store.dart';
import '../../helpers/fake_showrooms_repository.dart';
import '../../helpers/pump_app.dart';

const Set<String> adminPermissions = <String>{
  'dashboard.view',
  'showrooms.view',
  'showrooms.create',
  'showrooms.edit',
  'users.view',
  'users.edit',
};
const Set<String> managerPermissions = <String>{'dashboard.view', 'showrooms.view', 'users.view'};

/// The shell animates forever; pump fixed frames. The last one lets data
/// that loaded for a freshly built tab page render.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<(FakeAuthRepository, GoRouter)> openShowrooms(
  WidgetTester tester,
  Set<String> permissions, {
  FakeShowroomsRepository? showrooms,
  FakeUsersRepository? users,
  String path = AppRoutes.showroomsPath,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    session: testSession(showrooms: <SessionShowroom>[testShowroom('s-ind', 'Indore Main', permissions: permissions)]),
    signedIn: true,
  );
  final (_, GoRouter router) = await pumpMyBikeApp(
    tester,
    size: const Size(1280, 900),
    auth: auth,
    showrooms: showrooms ?? FakeShowroomsRepository(),
    users: users ?? FakeUsersRepository(),
  );
  router.go(path);
  await settle(tester);
  return (auth, router);
}

Future<void> openTab(WidgetTester tester, String tab) async {
  await tester.tap(find.widgetWithText(Tab, tab));
  await settle(tester);
}

void main() {
  testWidgets('list: New showroom needs showrooms.create', (WidgetTester tester) async {
    await openShowrooms(tester, adminPermissions);
    expect(find.text('Indore Main'), findsWidgets);
    expect(find.widgetWithText(AppButton, 'New showroom'), findsOneWidget);
  });

  testWidgets('a showroom manager (view only) sees the setup but cannot change it', (WidgetTester tester) async {
    await openShowrooms(tester, managerPermissions, path: AppRoutes.showroomDetailPath('s-ind'));

    expect(find.text('23ABCDE1234F1Z5'), findsOneWidget);
    expect(find.widgetWithText(AppOutlinedButton, 'Edit'), findsNothing);
    expect(find.text('Deactivate showroom'), findsNothing);

    await openTab(tester, 'Bank');
    expect(find.text('Add account'), findsNothing);
    await openTab(tester, 'Users');
    expect(find.text('Assign user'), findsNothing);
  });

  testWidgets('invoice tab shows the next document number and the texts', (WidgetTester tester) async {
    await openShowrooms(tester, adminPermissions, path: AppRoutes.showroomDetailPath('s-ind'));
    await openTab(tester, 'Invoice');

    expect(find.text('IND/26-27/00001'), findsOneWidget);
    expect(find.text('Goods once sold will not be taken back.'), findsOneWidget);
  });

  testWidgets('settings tab shows money exactly as stored (no floating point)', (WidgetTester tester) async {
    await openShowrooms(tester, adminPermissions, path: AppRoutes.showroomDetailPath('s-ind'));
    await openTab(tester, 'Settings');

    expect(find.text('₹ 5000.50'), findsOneWidget);
  });

  testWidgets('bank account: the IFSC is validated before saving', (WidgetTester tester) async {
    final FakeShowroomsRepository showrooms = FakeShowroomsRepository();
    await openShowrooms(tester, adminPermissions, showrooms: showrooms, path: AppRoutes.showroomDetailPath('s-ind'));
    await openTab(tester, 'Bank');
    expect(find.text('No bank account yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppOutlinedButton, 'Add account'));
    await settle(tester);
    final Finder fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextFormField));
    await tester.enterText(fields.at(0), 'MyBike Motors Private Limited');
    await tester.enterText(fields.at(1), 'HDFC Bank');
    await tester.enterText(fields.at(2), '50200012345678');
    await tester.enterText(fields.at(3), 'HDFC123');
    await tester.tap(find.widgetWithText(AppButton, 'Save'));
    await settle(tester);
    expect(find.textContaining('11-character IFSC'), findsOneWidget);
    expect(showrooms.calls, isEmpty);

    await tester.enterText(fields.at(3), 'hdfc0001234');
    await tester.tap(find.widgetWithText(AppButton, 'Save'));
    await settle(tester);
    expect(showrooms.calls, <String>['saveBankAccount HDFC0001234']);
  });

  testWidgets('deactivation asks first, then reloads the session and returns to the list', (WidgetTester tester) async {
    final FakeShowroomsRepository showrooms = FakeShowroomsRepository();
    final (FakeAuthRepository auth, GoRouter router) =
        await openShowrooms(tester, adminPermissions, showrooms: showrooms, path: AppRoutes.showroomDetailPath('s-ind'));
    final int fetchesBefore = auth.fetchCalls;

    await tester.tap(find.widgetWithText(AppButton, 'Deactivate showroom'));
    await settle(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Deactivate'));
    await settle(tester);

    expect(showrooms.calls, <String>['setActive s-ind false']);
    expect(auth.fetchCalls, fetchesBefore + 1);
    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.showroomsPath);
  });

  testWidgets('create: the GSTIN must match the state and PAN; then it opens the new showroom', (WidgetTester tester) async {
    final FakeShowroomsRepository showrooms = FakeShowroomsRepository();
    final (FakeAuthRepository auth, GoRouter router) = await openShowrooms(tester, adminPermissions, showrooms: showrooms);

    await tester.tap(find.widgetWithText(AppButton, 'New showroom'));
    await settle(tester);
    final Finder fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextFormField));
    await tester.enterText(fields.at(0), 'Dewas Showroom');
    await tester.enterText(fields.at(1), 'dewas');
    await tester.enterText(fields.at(2), 'dws');
    await tester.enterText(fields.at(4), '27ABCDE1234F1Z5');
    await tester.enterText(fields.at(5), 'ABCDE1234F');
    // State: Madhya Pradesh (23).
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String?>).first);
    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
    await settle(tester);
    await tester.tap(find.text('23 · Madhya Pradesh').last);
    await settle(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Create showroom'));
    await settle(tester);
    expect(find.textContaining('starts with its state code (23)'), findsOneWidget);
    expect(showrooms.created, isNull);

    await tester.enterText(fields.at(4), '23abcde1234f1z5');
    await tester.tap(find.widgetWithText(AppButton, 'Create showroom'));
    await settle(tester);

    expect(showrooms.created?.toJson()['code'], 'DEWAS');
    expect(showrooms.created?.toJson()['invoice_prefix'], 'DWS');
    expect(showrooms.created?.toJson()['gstin'], '23ABCDE1234F1Z5');
    expect(auth.fetchCalls, greaterThan(1), reason: 'the new showroom joins the switcher');
    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.showroomDetailPath('s-new'));
  });

  testWidgets('switching showroom moves the users list along', (WidgetTester tester) async {
    final FakeUsersRepository users = FakeUsersRepository(users: <ManagedUser>[salesExec]);
    final FakeAuthRepository auth = FakeAuthRepository(
      session: testSession(showrooms: <SessionShowroom>[
        testShowroom('s-bpl', 'Bhopal', permissions: adminPermissions),
        testShowroom('s-ind', 'Indore Main', permissions: adminPermissions),
      ]),
      signedIn: true,
    );
    final FakePreferenceStore store = FakePreferenceStore();
    await store.writeString(StorageKeys.lastShowroomFor(testSession().profileId), 's-ind');
    final (_, GoRouter router) =
        await pumpMyBikeApp(tester, size: const Size(1280, 900), auth: auth, store: store, users: users);
    router.go(AppRoutes.usersPath);
    await settle(tester);
    expect(users.queries.last.showroomId, 's-ind');

    final ProviderContainer container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    await container.read(sessionControllerProvider.notifier).selectShowroom(const ShowroomSelection.showroom('s-bpl'));
    await settle(tester);

    expect(users.queries.last.showroomId, 's-bpl');
  });

  group('session refresh after showroom changes', () {
    Future<ProviderContainer> signedInContainer(FakeAuthRepository auth) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          preferenceStoreProvider.overrideWithValue(FakePreferenceStore()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionControllerProvider.future);
      return container;
    }

    test('keeps the current showroom while it is still available', () async {
      final FakeAuthRepository auth = FakeAuthRepository(
        session: testSession(showrooms: <SessionShowroom>[testShowroom('s-bpl', 'Bhopal'), testShowroom('s-ind', 'Indore')]),
        signedIn: true,
      );
      final ProviderContainer container = await signedInContainer(auth);
      await container.read(sessionControllerProvider.notifier).selectShowroom(const ShowroomSelection.showroom('s-ind'));

      auth.session = testSession(showrooms: <SessionShowroom>[
        testShowroom('s-bpl', 'Bhopal'),
        testShowroom('s-ind', 'Indore'),
        testShowroom('s-dws', 'Dewas'),
      ]);
      await container.read(sessionControllerProvider.notifier).refresh();

      final SignedIn state = container.read(sessionControllerProvider).value! as SignedIn;
      expect(state.selection, const ShowroomSelection.showroom('s-ind'));
      expect(state.session!.showrooms.length, 3);
    });

    test('a deactivated current showroom falls back to the remaining one', () async {
      final FakeAuthRepository auth = FakeAuthRepository(
        session: testSession(showrooms: <SessionShowroom>[testShowroom('s-bpl', 'Bhopal'), testShowroom('s-ind', 'Indore')]),
        signedIn: true,
      );
      final ProviderContainer container = await signedInContainer(auth);
      await container.read(sessionControllerProvider.notifier).selectShowroom(const ShowroomSelection.showroom('s-ind'));

      auth.session = testSession(showrooms: <SessionShowroom>[testShowroom('s-bpl', 'Bhopal')]);
      await container.read(sessionControllerProvider.notifier).refresh();

      final SignedIn state = container.read(sessionControllerProvider).value! as SignedIn;
      expect(state.selection, const ShowroomSelection.showroom('s-bpl'));
    });

    test('losing the last showroom blocks access', () async {
      final FakeAuthRepository auth = FakeAuthRepository(session: testSession(), signedIn: true);
      final ProviderContainer container = await signedInContainer(auth);

      auth.session = testSession(showrooms: <SessionShowroom>[]);
      await container.read(sessionControllerProvider.notifier).refresh();

      final SignedIn state = container.read(sessionControllerProvider).value! as SignedIn;
      expect(state.blockReason, SessionBlockReason.noShowroom);
    });
  });

  test('numbering preview matches fn_next_document_number', () {
    const NumberingSeries series =
        NumberingSeries(docType: 'credit_note', prefix: 'INDCN', nextNumber: 42, padding: 4, financialYear: '2026-27');
    expect(series.preview, 'INDCN/26-27/0042');
    expect(series.label, 'Credit Note');
  });

  test('GST and bank validators match the database checks', () {
    expect(Validators.gstin('23ABCDE1234F1Z5'), isNull);
    expect(Validators.gstin('23ABCDE1234F1X5'), isNotNull);
    expect(Validators.pan('abcde1234f'), isNull);
    expect(Validators.ifsc('HDFC0001234'), isNull);
    expect(Validators.ifsc('HDFC1001234'), isNotNull);
    expect(Validators.bankAccountNumber('12345678'), isNotNull);
    expect(Validators.upi('mybike.indore@hdfcbank'), isNull);
    expect(Validators.amount('5000.50'), isNull);
    expect(Validators.amount('5000.505'), isNotNull);
    expect(Validators.amount('1e3'), isNotNull);
    expect(Validators.pincode('012345'), isNotNull);
  });
}
