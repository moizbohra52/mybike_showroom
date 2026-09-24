import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  group('UserSession.fromJson', () {
    test('parses the rpc_get_my_session payload', () {
      final UserSession session = UserSession.fromJson(const <String, Object?>{
        'profile': <String, Object?>{
          'id': 'p1',
          'full_name': 'Neha Joshi',
          'email': 'manager.indore@mybike.test',
          'status': 'active',
          'is_active': true,
        },
        'is_super_admin': false,
        'global_permissions': <Object?>[],
        'showrooms': <Object?>[
          <String, Object?>{
            'id': 's1',
            'code': 'INDORE-MAIN',
            'name': 'Indore Main Showroom',
            'is_active': true,
            'is_default': true,
            'roles': <Object?>['SHOWROOM_MANAGER'],
            'permissions': <Object?>['sales.view', 'sales.approve'],
          },
        ],
      });

      expect(session.fullName, 'Neha Joshi');
      expect(session.showrooms.single.code, 'INDORE-MAIN');
      expect(session.showrooms.single.permissions, <String>{'sales.view', 'sales.approve'});
      expect(session.blockReason, isNull);
    });
  });

  group('blockReason', () {
    test('deactivated user is blocked', () {
      expect(testSession(isActive: false).blockReason, SessionBlockReason.deactivated);
    });

    test('no showroom and no ALL SHOWROOMS is blocked', () {
      expect(testSession(showrooms: <SessionShowroom>[]).blockReason, SessionBlockReason.noShowroom);
    });

    test('ALL SHOWROOMS permission alone is enough', () {
      final UserSession session = testSession(
        showrooms: <SessionShowroom>[],
        globalPermissions: <String>{UserSession.viewAllPermission},
      );
      expect(session.blockReason, isNull);
    });
  });

  group('initialSelection', () {
    final UserSession multi = testSession(
      showrooms: <SessionShowroom>[testShowroom('a', 'Bhopal'), testShowroom('b', 'Indore')],
    );

    test('single showroom is selected automatically', () {
      expect(testSession().initialSelection(null), const ShowroomSelection.showroom('s-ind'));
    });

    test('multi-showroom user must choose on first sign-in', () {
      expect(multi.initialSelection(null), isNull);
    });

    test('last used showroom is restored while still accessible', () {
      expect(multi.initialSelection('b'), const ShowroomSelection.showroom('b'));
    });

    test('a revoked last showroom forces a new choice', () {
      expect(multi.initialSelection('gone'), isNull);
    });

    test('ALL SHOWROOMS is restored only with showrooms.view_all', () {
      expect(multi.initialSelection(ShowroomSelection.allSentinel), isNull);
      final UserSession admin = testSession(
        showrooms: multi.showrooms,
        globalPermissions: <String>{UserSession.viewAllPermission},
      );
      expect(admin.initialSelection(ShowroomSelection.allSentinel), const ShowroomSelection.all());
    });
  });

  test('permissionsFor uses the showroom set, or the global set for ALL', () {
    final UserSession session = testSession(
      showrooms: <SessionShowroom>[testShowroom('a', 'Bhopal', permissions: <String>{'sales.view'})],
      globalPermissions: <String>{'reports.view'},
    );
    expect(session.permissionsFor(const ShowroomSelection.showroom('a')), <String>{'sales.view'});
    expect(session.permissionsFor(const ShowroomSelection.all()), <String>{'reports.view'});
    expect(session.permissionsFor(const ShowroomSelection.showroom('unknown')), isEmpty);
  });
}
