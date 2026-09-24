import 'dart:async';

import 'package:mybike_showroom/core/constants/module_keys.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/features/auth/data/auth_repository.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';

/// In-memory [AuthRepository]: one valid password, a configurable session.
final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.session, this.signedIn = false});

  static const String validPassword = 'MyBike@Dev2026';

  /// What `fetchSession()` returns (null = no profile).
  UserSession? session;
  bool signedIn;
  int signOutCalls = 0;
  final StreamController<void> signedOutController = StreamController<void>.broadcast();

  @override
  bool get hasSession => signedIn;

  @override
  Stream<void> get signedOut => signedOutController.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (password != validPassword) {
      throw const AuthFailure(message: FailureMessages.invalidCredentials);
    }
    signedIn = true;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    signedIn = false;
  }

  @override
  Future<UserSession?> fetchSession() async => session;

  /// Simulates the SDK ending the session (refresh failure, other device).
  void expireSession() {
    signedIn = false;
    signedOutController.add(null);
  }
}

/// Every `module.action` permission.
final Set<String> allPermissions = <String>{
  for (final String module in ModuleKeys.all)
    for (final String action in PermissionActions.all) PermissionKeys.code(module, action),
};

SessionShowroom testShowroom(String id, String name, {Set<String>? permissions, bool isDefault = false}) {
  return SessionShowroom(
    id: id,
    code: name.toUpperCase().replaceAll(' ', '-'),
    name: name,
    isActive: true,
    isDefault: isDefault,
    roles: const <String>['TEST_ROLE'],
    permissions: permissions ?? allPermissions,
  );
}

UserSession testSession({
  List<SessionShowroom>? showrooms,
  Set<String> globalPermissions = const <String>{},
  bool isActive = true,
}) {
  return UserSession(
    profileId: 'a0000000-0000-4000-8000-000000000099',
    fullName: 'Test User',
    email: 'test@mybike.test',
    isActive: isActive,
    isSuperAdmin: false,
    globalPermissions: globalPermissions,
    showrooms: showrooms ?? <SessionShowroom>[testShowroom('s-ind', 'Indore Main')],
  );
}
