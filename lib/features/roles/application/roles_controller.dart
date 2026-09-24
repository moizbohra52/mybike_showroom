import 'package:mybike_showroom/features/roles/data/roles_repository.dart';
import 'package:mybike_showroom/features/roles/domain/role_admin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'roles_controller.g.dart';

@riverpod
Future<List<AppRole>> roleList(Ref ref) => ref.watch(rolesRepositoryProvider).roles();

/// The permission catalogue (code-defined; changes only with migrations).
@Riverpod(keepAlive: true)
Future<List<PermissionEntry>> permissionCatalogue(Ref ref) => ref.watch(rolesRepositoryProvider).permissions();

@riverpod
Future<RoleDetail> roleDetail(Ref ref, String roleId) => ref.watch(rolesRepositoryProvider).detail(roleId);

/// Role and matrix commands; each refreshes the affected views.
@Riverpod(keepAlive: true)
RoleAdminActions roleAdminActions(Ref ref) => RoleAdminActions(ref);

class RoleAdminActions {
  RoleAdminActions(this.ref);

  final Ref ref;

  RolesRepository get repository => ref.read(rolesRepositoryProvider);

  Future<String> create(RoleDraft draft) async {
    final String id = await repository.create(draft);
    ref.invalidate(roleListProvider);
    return id;
  }

  Future<void> update(String roleId, RoleDraft draft) async {
    await repository.update(roleId, draft);
    refresh(roleId);
  }

  Future<void> delete(String roleId) async {
    await repository.delete(roleId);
    ref.invalidate(roleListProvider);
  }

  /// Grants or revokes one permission of the role.
  Future<void> setPermission(String roleId, String permissionId, {required bool granted}) async {
    try {
      if (granted) {
        await repository.grant(roleId, permissionId);
      } else {
        await repository.revoke(roleId, permissionId);
      }
    } finally {
      ref.invalidate(roleDetailProvider(roleId));
    }
  }

  void refresh(String roleId) {
    ref
      ..invalidate(roleDetailProvider(roleId))
      ..invalidate(roleListProvider);
  }
}
