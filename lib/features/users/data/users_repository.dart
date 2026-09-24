import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/core/errors/error_mapper.dart';
import 'package:mybike_showroom/features/users/domain/user_admin.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// User administration. Every call runs with the signed-in user's JWT, so RLS
/// and the Phase 6 RPCs decide what is allowed; the Edge Function is used only
/// where the Auth admin API is needed (create user, set password).
abstract interface class UsersRepository {
  Future<UsersPage> list(UsersQuery query);

  /// `null` when the caller may not view the user.
  Future<UserAccess?> access(String profileId);

  /// Roles the caller may grant in a showroom (`null` = globally).
  Future<List<RoleOption>> grantableRoles(String? showroomId);

  /// Creates the auth user, its showroom and first role; returns the new id.
  Future<String> create(NewUserRequest request);

  Future<void> updateProfile(String profileId, UserProfileUpdate update);
  Future<void> setStatus(String profileId, String status);
  Future<void> setPassword(String profileId, String password);
  Future<void> addShowroom(String profileId, String showroomId);

  /// Also removes the user's roles in that showroom (database cascade).
  Future<void> removeShowroom(String profileId, String showroomId);
  Future<void> grantRole(String profileId, String roleId, String? showroomId);
  Future<void> revokeRole(String assignmentId);
}

final class SupabaseUsersRepository implements UsersRepository {
  SupabaseUsersRepository(this.client);

  final SupabaseClient client;

  static const String functionName = 'admin-users';

  /// Characters with a meaning in PostgREST filter syntax.
  static final RegExp filterSyntax = RegExp(r'[,()"\\*%]');

  @override
  Future<UsersPage> list(UsersQuery query) {
    return ErrorMapper.guard(() async {
      final String membership = query.showroomId == null ? '' : ', user_showrooms!user_showrooms_profile_id_fkey!inner(showroom_id)';
      PostgrestFilterBuilder<List<Map<String, dynamic>>> request = client.from('profiles').select(
            'id, full_name, email, phone, designation, employee_code, status, '
            'user_roles!user_roles_profile_id_fkey(roles(name))$membership',
          );
      if (query.showroomId != null) {
        request = request.eq('user_showrooms.showroom_id', query.showroomId!);
      }
      if (query.status != null) {
        request = request.eq('status', query.status!);
      }
      final String search = query.search.replaceAll(filterSyntax, ' ').trim();
      if (search.isNotEmpty) {
        request = request.or('full_name.ilike.%$search%,email.ilike.%$search%,employee_code.ilike.%$search%');
      }
      final int from = (query.page - 1) * query.pageSize;
      final PostgrestResponse<List<Map<String, dynamic>>> response =
          await request.order('full_name').range(from, from + query.pageSize - 1).count(CountOption.exact);
      return UsersPage(
        items: <ManagedUser>[for (final Map<String, dynamic> row in response.data) ManagedUser.fromJson(row)],
        total: response.count,
      );
    });
  }

  @override
  Future<UserAccess?> access(String profileId) {
    return ErrorMapper.guard(() async {
      final Object? data = await client.rpc<Object?>('rpc_get_user_access', params: <String, Object?>{'p_profile_id': profileId});
      return data == null ? null : UserAccess.fromJson((data as Map<Object?, Object?>).cast<String, Object?>());
    });
  }

  @override
  Future<List<RoleOption>> grantableRoles(String? showroomId) {
    return ErrorMapper.guard(() async {
      final List<Object?> rows =
          await client.rpc<List<Object?>>('rpc_grantable_roles', params: <String, Object?>{'p_showroom_id': showroomId});
      return <RoleOption>[
        for (final Object? row in rows) RoleOption.fromJson((row! as Map<Object?, Object?>).cast<String, Object?>()),
      ];
    });
  }

  @override
  Future<String> create(NewUserRequest request) {
    return ErrorMapper.guard(() async {
      final FunctionResponse response = await client.functions.invoke(functionName, body: request.toJson());
      return (response.data as Map<Object?, Object?>)['user_id']! as String;
    });
  }

  @override
  Future<void> updateProfile(String profileId, UserProfileUpdate update) {
    return ErrorMapper.guard(() => client.rpc<void>('rpc_admin_update_user', params: <String, Object?>{
          'p_profile_id': profileId,
          'p_full_name': update.fullName.trim(),
          'p_phone': update.phone.trim(),
          'p_designation': update.designation.trim(),
          'p_employee_code': update.employeeCode.trim(),
        }));
  }

  @override
  Future<void> setStatus(String profileId, String status) {
    return ErrorMapper.guard(() => client.rpc<void>(
          'rpc_admin_set_user_status',
          params: <String, Object?>{'p_profile_id': profileId, 'p_status': status},
        ));
  }

  @override
  Future<void> setPassword(String profileId, String password) {
    return ErrorMapper.guard(() => client.functions.invoke(
          functionName,
          body: <String, Object?>{'action': 'set_password', 'user_id': profileId, 'password': password},
        ));
  }

  @override
  Future<void> addShowroom(String profileId, String showroomId) {
    return ErrorMapper.guard(() => client.from('user_showrooms').insert(<String, Object?>{'profile_id': profileId, 'showroom_id': showroomId}));
  }

  @override
  Future<void> removeShowroom(String profileId, String showroomId) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('user_showrooms')
          .delete()
          .eq('profile_id', profileId)
          .eq('showroom_id', showroomId)
          .select('id');
      ErrorMapper.requireChanged(rows);
    });
  }

  @override
  Future<void> grantRole(String profileId, String roleId, String? showroomId) {
    return ErrorMapper.guard(() => client
        .from('user_roles')
        .insert(<String, Object?>{'profile_id': profileId, 'role_id': roleId, 'showroom_id': showroomId}));
  }

  @override
  Future<void> revokeRole(String assignmentId) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows =
          await client.from('user_roles').delete().eq('id', assignmentId).select('id');
      ErrorMapper.requireChanged(rows);
    });
  }
}

final Provider<UsersRepository> usersRepositoryProvider = Provider<UsersRepository>(
  (Ref ref) => SupabaseUsersRepository(Supabase.instance.client),
);
