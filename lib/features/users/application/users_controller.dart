import 'package:mybike_showroom/features/users/data/users_repository.dart';
import 'package:mybike_showroom/features/users/domain/user_admin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'users_controller.g.dart';

/// One page of the users list.
@riverpod
Future<UsersPage> usersPage(Ref ref, UsersQuery query) => ref.watch(usersRepositoryProvider).list(query);

/// A user's detail with what the caller may change.
@riverpod
Future<UserAccess?> userAccess(Ref ref, String profileId) => ref.watch(usersRepositoryProvider).access(profileId);

/// Roles the caller may grant in a showroom (`null` = globally).
@riverpod
Future<List<RoleOption>> grantableRoles(Ref ref, String? showroomId) =>
    ref.watch(usersRepositoryProvider).grantableRoles(showroomId);

/// User-administration commands. Each one refreshes the affected views;
/// failures surface as AppFailure with a user-safe message.
@Riverpod(keepAlive: true)
UserAdminActions userAdminActions(Ref ref) => UserAdminActions(ref);

class UserAdminActions {
  UserAdminActions(this.ref);

  final Ref ref;

  UsersRepository get repository => ref.read(usersRepositoryProvider);

  Future<String> create(NewUserRequest request) async {
    final String id = await repository.create(request);
    ref.invalidate(usersPageProvider);
    return id;
  }

  Future<void> updateProfile(String profileId, UserProfileUpdate update) async {
    await repository.updateProfile(profileId, update);
    refresh(profileId);
  }

  Future<void> setStatus(String profileId, String status) async {
    await repository.setStatus(profileId, status);
    refresh(profileId);
  }

  Future<void> setPassword(String profileId, String password) => repository.setPassword(profileId, password);

  /// Adds the showroom and, when given, a first role there.
  Future<void> addShowroom(String profileId, String showroomId, {String? roleId}) async {
    try {
      await repository.addShowroom(profileId, showroomId);
      if (roleId != null) {
        await repository.grantRole(profileId, roleId, showroomId);
      }
    } finally {
      refresh(profileId);
    }
  }

  Future<void> removeShowroom(String profileId, String showroomId) async {
    await repository.removeShowroom(profileId, showroomId);
    refresh(profileId);
  }

  Future<void> grantRole(String profileId, String roleId, String? showroomId) async {
    await repository.grantRole(profileId, roleId, showroomId);
    refresh(profileId);
  }

  Future<void> revokeRole(String profileId, String assignmentId) async {
    await repository.revokeRole(assignmentId);
    refresh(profileId);
  }

  void refresh(String profileId) {
    ref
      ..invalidate(userAccessProvider(profileId))
      ..invalidate(usersPageProvider);
  }
}
