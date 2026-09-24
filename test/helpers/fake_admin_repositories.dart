import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/features/roles/data/roles_repository.dart';
import 'package:mybike_showroom/features/roles/domain/role_admin.dart';
import 'package:mybike_showroom/features/users/data/users_repository.dart';
import 'package:mybike_showroom/features/users/domain/user_admin.dart';

/// In-memory [UsersRepository]: canned reads, recorded writes.
final class FakeUsersRepository implements UsersRepository {
  FakeUsersRepository({this.users = const <ManagedUser>[], Map<String, UserAccess>? accessById, this.failWith})
      : accessById = accessById ?? <String, UserAccess>{};

  List<ManagedUser> users;
  final Map<String, UserAccess> accessById;
  List<RoleOption> grantable = const <RoleOption>[RoleOption(id: 'r-se', code: 'SALES_EXECUTIVE', name: 'Sales Executive')];

  /// Thrown by every write when set (simulates RLS refusing).
  AppFailure? failWith;
  final List<String> calls = <String>[];
  final List<UsersQuery> queries = <UsersQuery>[];
  NewUserRequest? created;

  Future<void> record(String call) async {
    calls.add(call);
    if (failWith != null) {
      throw failWith!;
    }
  }

  @override
  Future<UsersPage> list(UsersQuery query) async {
    queries.add(query);
    return UsersPage(items: users, total: users.length);
  }

  @override
  Future<UserAccess?> access(String profileId) async => accessById[profileId];

  @override
  Future<List<RoleOption>> grantableRoles(String? showroomId) async => grantable;

  @override
  Future<String> create(NewUserRequest request) async {
    await record('create ${request.email}');
    created = request;
    return 'new-user';
  }

  @override
  Future<void> updateProfile(String profileId, UserProfileUpdate update) => record('updateProfile $profileId');

  @override
  Future<void> setStatus(String profileId, String status) => record('setStatus $profileId $status');

  @override
  Future<void> setPassword(String profileId, String password) => record('setPassword $profileId');

  @override
  Future<void> addShowroom(String profileId, String showroomId) => record('addShowroom $profileId $showroomId');

  @override
  Future<void> removeShowroom(String profileId, String showroomId) => record('removeShowroom $profileId $showroomId');

  @override
  Future<void> grantRole(String profileId, String roleId, String? showroomId) =>
      record('grantRole $profileId $roleId $showroomId');

  @override
  Future<void> revokeRole(String assignmentId) => record('revokeRole $assignmentId');
}

/// In-memory [RolesRepository].
final class FakeRolesRepository implements RolesRepository {
  FakeRolesRepository({required this.roleList, required this.catalogue, Map<String, RoleDetail>? details})
      : details = details ?? <String, RoleDetail>{};

  List<AppRole> roleList;
  List<PermissionEntry> catalogue;
  final Map<String, RoleDetail> details;
  final List<String> calls = <String>[];

  @override
  Future<List<AppRole>> roles() async => roleList;

  @override
  Future<List<PermissionEntry>> permissions() async => catalogue;

  @override
  Future<RoleDetail> detail(String roleId) async => details[roleId]!;

  @override
  Future<String> create(RoleDraft draft) async {
    calls.add('create ${draft.code} ${draft.precedence}');
    return 'new-role';
  }

  @override
  Future<void> update(String roleId, RoleDraft draft) async => calls.add('update $roleId');

  @override
  Future<void> delete(String roleId) async => calls.add('delete $roleId');

  @override
  Future<void> grant(String roleId, String permissionId) async => calls.add('grant $roleId $permissionId');

  @override
  Future<void> revoke(String roleId, String permissionId) async => calls.add('revoke $roleId $permissionId');
}

const ManagedUser salesExec = ManagedUser(
  id: 'u-exec',
  fullName: 'Imran Khan',
  status: 'active',
  email: 'sales.exec@mybike.test',
  employeeCode: 'MB-0006',
  roleNames: <String>['Sales Executive'],
);

/// rpc_get_user_access payload for [user] as seen by a showroom manager.
UserAccess testAccess({
  ManagedUser user = salesExec,
  bool canManage = true,
  bool isSelf = false,
  int hiddenShowroomCount = 0,
}) {
  return UserAccess(
    user: user,
    createdAt: null,
    isSelf: isSelf,
    canManage: canManage,
    global: const AccessScope(canManage: false, roles: <RoleAssignment>[], grantableRoles: <RoleOption>[]),
    showrooms: <AccessScope>[
      AccessScope(
        showroomId: 's-ind',
        code: 'INDORE-MAIN',
        name: 'Indore Main',
        canManage: canManage,
        roles: const <RoleAssignment>[
          RoleAssignment(assignmentId: 'a-1', roleId: 'r-se', code: 'SALES_EXECUTIVE', name: 'Sales Executive', isUsable: true),
        ],
        grantableRoles: canManage
            ? const <RoleOption>[RoleOption(id: 'r-ca', code: 'CASHIER', name: 'Cashier')]
            : const <RoleOption>[],
      ),
    ],
    hiddenShowroomCount: hiddenShowroomCount,
    addableShowrooms: const <ShowroomOption>[],
  );
}
