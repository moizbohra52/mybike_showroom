import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/screens/foundation_screen.dart';
import 'package:mybike_showroom/core/constants/storage_keys.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:mybike_showroom/features/auth/presentation/access_blocked_screen.dart';
import 'package:mybike_showroom/features/auth/presentation/login_screen.dart';
import 'package:mybike_showroom/features/auth/presentation/select_showroom_screen.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_preference_store.dart';
import '../../helpers/pump_app.dart';

const Size desktop = Size(1280, 800);
const Size phone = Size(390, 844);

Future<void> signIn(WidgetTester tester, {String password = FakeAuthRepository.validPassword}) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'user@mybike.test');
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.widgetWithText(InkWell, 'Sign in'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('signed-out user lands on login; wrong password shows a friendly error', (WidgetTester tester) async {
    await pumpMyBikeApp(tester, size: phone, auth: FakeAuthRepository(session: testSession()));

    expect(find.byType(LoginScreen), findsOneWidget);

    await signIn(tester, password: 'wrong-password');

    expect(find.text(FailureMessages.invalidCredentials), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('empty form is validated before calling the server', (WidgetTester tester) async {
    final FakeAuthRepository auth = FakeAuthRepository(session: testSession());
    await pumpMyBikeApp(tester, size: phone, auth: auth);

    await tester.tap(find.widgetWithText(InkWell, 'Sign in'));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(auth.signedIn, isFalse);
  });

  testWidgets('single-showroom user goes straight to the dashboard', (WidgetTester tester) async {
    await pumpMyBikeApp(tester, size: desktop, auth: FakeAuthRepository(session: testSession()));

    await signIn(tester);

    expect(find.byType(FoundationScreen), findsOneWidget);
    expect(find.text('Indore Main'), findsOneWidget); // header showroom chip
  });

  testWidgets('multi-showroom user must choose; the choice is remembered', (WidgetTester tester) async {
    final UserSession session = testSession(
      showrooms: <SessionShowroom>[testShowroom('s-bpl', 'Bhopal'), testShowroom('s-ind', 'Indore Main')],
    );
    final (FakePreferenceStore store, _) = await pumpMyBikeApp(
      tester,
      size: desktop,
      auth: FakeAuthRepository(session: session),
    );

    await signIn(tester);
    expect(find.byType(SelectShowroomScreen), findsOneWidget);

    await tester.tap(find.text('Bhopal'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FoundationScreen), findsOneWidget);
    expect(store.strings[StorageKeys.lastShowroomFor(session.profileId)], 's-bpl');
  });

  testWidgets('a remembered showroom is reopened on the next start', (WidgetTester tester) async {
    final UserSession session = testSession(
      showrooms: <SessionShowroom>[testShowroom('s-bpl', 'Bhopal'), testShowroom('s-ind', 'Indore Main')],
    );
    final FakePreferenceStore store = FakePreferenceStore();
    await store.writeString(StorageKeys.lastShowroomFor(session.profileId), 's-ind');

    await pumpMyBikeApp(tester, size: desktop, store: store, auth: FakeAuthRepository(session: session, signedIn: true));

    expect(find.byType(FoundationScreen), findsOneWidget);
    expect(find.text('Indore Main'), findsOneWidget);
  });

  testWidgets('deactivated user is blocked with an explanation', (WidgetTester tester) async {
    await pumpMyBikeApp(tester, size: phone, auth: FakeAuthRepository(session: testSession(isActive: false)));

    await signIn(tester);

    expect(find.byType(AccessBlockedScreen), findsOneWidget);
    expect(find.text(FailureMessages.accountDisabled), findsOneWidget);
  });

  testWidgets('user without profile or showroom is blocked', (WidgetTester tester) async {
    await pumpMyBikeApp(tester, size: phone, auth: FakeAuthRepository(session: testSession(showrooms: <SessionShowroom>[])));

    await signIn(tester);

    expect(find.byType(AccessBlockedScreen), findsOneWidget);
    expect(find.textContaining('No showroom is assigned'), findsOneWidget);
  });

  testWidgets('sign-out clears the session and returns to login', (WidgetTester tester) async {
    final FakeAuthRepository auth = FakeAuthRepository(session: testSession(), signedIn: true);
    await pumpMyBikeApp(tester, size: desktop, auth: auth);
    expect(find.byType(FoundationScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(auth.signOutCalls, 1);
    expect(auth.signedIn, isFalse);
  });

  testWidgets('an expired session (SDK sign-out) returns to login', (WidgetTester tester) async {
    final FakeAuthRepository auth = FakeAuthRepository(session: testSession(), signedIn: true);
    await pumpMyBikeApp(tester, size: desktop, auth: auth);

    auth.expireSession();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('modules without view permission are hidden and forbidden', (WidgetTester tester) async {
    final UserSession limited = testSession(
      showrooms: <SessionShowroom>[
        testShowroom('s-ind', 'Indore Main', permissions: <String>{'dashboard.view', 'sales.view'}),
      ],
    );
    final (_, GoRouter router) = await pumpMyBikeApp(
      tester,
      size: desktop,
      auth: FakeAuthRepository(session: limited, signedIn: true),
    );

    expect(find.widgetWithText(ListTile, 'Sales'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Inventory'), findsNothing);

    router.go(AppRoutes.inventoryPath);
    await tester.pumpAndSettle();

    expect(find.byType(AccessBlockedScreen), findsOneWidget);
    expect(find.text('Access denied'), findsOneWidget);
  });
}
