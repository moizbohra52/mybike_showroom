import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/core/errors/error_mapper.dart';
import 'package:mybike_showroom/features/roles/domain/role_admin.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Roles and the role × permission matrix. RLS decides every write
/// (roles.* granted globally, only for roles ranking below the caller).
abstract interface class RolesRepository {
  Future<List<AppRole>> roles();
  Future<List<PermissionEntry>> permissions();
  Future<RoleDetail> detail(String roleId);
  Future<String> create(RoleDraft draft);
  Future<void> update(String roleId, RoleDraft draft);
  Future<void> delete(String roleId);
  Future<void> grant(String roleId, String permissionId);
  Future<void> revoke(String roleId, String permissionId);
}

final class SupabaseRolesRepository implements RolesRepository {
  SupabaseRolesRepository(this.client);

  final SupabaseClient client;

  static const String roleColumns = 'id, code, name, description, precedence, is_system, is_active';

  @override
  Future<List<AppRole>> roles() {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows =
          await client.from('roles').select(roleColumns).order('precedence', ascending: false).order('code');
      return <AppRole>[for (final Map<String, dynamic> row in rows) AppRole.fromJson(row)];
    });
  }

  @override
  Future<List<PermissionEntry>> permissions() {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client.from('permissions').select('id, module, action');
      return <PermissionEntry>[for (final Map<String, dynamic> row in rows) PermissionEntry.fromJson(row)];
    });
  }

  @override
  Future<RoleDetail> detail(String roleId) {
    return ErrorMapper.guard(() async {
      final Map<String, dynamic> role = await client.from('roles').select(roleColumns).eq('id', roleId).single();
      final List<Map<String, dynamic>> grants =
          await client.from('role_permissions').select('permission_id').eq('role_id', roleId);
      final bool canEdit = await client.rpc<bool>('can_edit_role', params: <String, Object?>{'p_role_id': roleId});
      return RoleDetail(
        role: AppRole.fromJson(role),
        grantedPermissionIds: <String>{for (final Map<String, dynamic> row in grants) row['permission_id']! as String},
        canEdit: canEdit,
      );
    });
  }

  @override
  Future<String> create(RoleDraft draft) {
    return ErrorMapper.guard(() async {
      final Map<String, dynamic> row = await client
          .from('roles')
          .insert(<String, Object?>{
            'code': draft.code.trim().toUpperCase(),
            'name': draft.name.trim(),
            'description': draft.description.trim().isEmpty ? null : draft.description.trim(),
            'precedence': draft.precedence,
          })
          .select('id')
          .single();
      return row['id']! as String;
    });
  }

  @override
  Future<void> update(String roleId, RoleDraft draft) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('roles')
          .update(<String, Object?>{
            'name': draft.name.trim(),
            'description': draft.description.trim().isEmpty ? null : draft.description.trim(),
            'precedence': draft.precedence,
            'is_active': draft.isActive,
          })
          .eq('id', roleId)
          .select('id');
      ErrorMapper.requireChanged(rows);
    });
  }

  @override
  Future<void> delete(String roleId) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client.from('roles').delete().eq('id', roleId).select('id');
      ErrorMapper.requireChanged(rows);
    });
  }

  @override
  Future<void> grant(String roleId, String permissionId) {
    return ErrorMapper.guard(
      () => client.from('role_permissions').insert(<String, Object?>{'role_id': roleId, 'permission_id': permissionId}),
    );
  }

  @override
  Future<void> revoke(String roleId, String permissionId) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('role_permissions')
          .delete()
          .eq('role_id', roleId)
          .eq('permission_id', permissionId)
          .select('role_id');
      ErrorMapper.requireChanged(rows);
    });
  }
}

final Provider<RolesRepository> rolesRepositoryProvider = Provider<RolesRepository>(
  (Ref ref) => SupabaseRolesRepository(Supabase.instance.client),
);
