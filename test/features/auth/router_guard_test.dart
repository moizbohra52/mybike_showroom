import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/core/routes/app_router.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  AsyncValue<SessionState> signedIn(UserSession? session, {ShowroomSelection? selection}) =>
      AsyncData<SessionState>(SignedIn(session: session, selection: selection));

  const ShowroomSelection ind = ShowroomSelection.showroom('s-ind');

  test('loading goes to splash', () {
    expect(AppRouter.guard(const AsyncLoading<SessionState>(), AppRoutes.dashboardPath), AppRoutes.splashPath);
    expect(AppRouter.guard(const AsyncLoading<SessionState>(), AppRoutes.splashPath), isNull);
  });

  test('signed out, or a failed session load, goes to login', () {
    expect(AppRouter.guard(const AsyncData<SessionState>(SignedOut()), AppRoutes.salesPath), AppRoutes.loginPath);
    expect(
      AppRouter.guard(AsyncError<SessionState>(Exception('x'), StackTrace.empty), AppRoutes.dashboardPath),
      AppRoutes.loginPath,
    );
    expect(AppRouter.guard(const AsyncData<SessionState>(SignedOut()), AppRoutes.loginPath), isNull);
  });

  test('blocked users only see the access screen', () {
    expect(AppRouter.guard(signedIn(null), AppRoutes.dashboardPath), AppRoutes.accessBlockedPath);
    expect(AppRouter.guard(signedIn(testSession(isActive: false)), AppRoutes.loginPath), AppRoutes.accessBlockedPath);
    expect(
      AppRouter.guard(signedIn(testSession(showrooms: <SessionShowroom>[])), AppRoutes.dashboardPath),
      AppRoutes.accessBlockedPath,
    );
  });

  test('no showroom selected goes to the picker', () {
    expect(AppRouter.guard(signedIn(testSession()), AppRoutes.dashboardPath), AppRoutes.selectShowroomPath);
  });

  test('ready users leave auth screens for the dashboard', () {
    expect(AppRouter.guard(signedIn(testSession(), selection: ind), AppRoutes.loginPath), AppRoutes.dashboardPath);
    expect(AppRouter.guard(signedIn(testSession(), selection: ind), AppRoutes.splashPath), AppRoutes.dashboardPath);
    expect(AppRouter.guard(signedIn(testSession(), selection: ind), AppRoutes.dashboardPath), isNull);
  });

  test('the picker stays reachable for switching showrooms', () {
    expect(AppRouter.guard(signedIn(testSession(), selection: ind), AppRoutes.selectShowroomPath), isNull);
  });

  test('a module without view permission is forbidden', () {
    final UserSession limited = testSession(
      showrooms: <SessionShowroom>[testShowroom('s-ind', 'Indore', permissions: <String>{'dashboard.view'})],
    );
    expect(AppRouter.guard(signedIn(limited, selection: ind), AppRoutes.salesPath), AppRoutes.forbiddenPath);
    expect(AppRouter.guard(signedIn(limited, selection: ind), AppRoutes.dashboardPath), isNull);
  });
}
