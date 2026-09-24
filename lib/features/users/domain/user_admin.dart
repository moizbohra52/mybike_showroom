import 'package:flutter/foundation.dart';

/// Statuses an administrator can set (`invited` is set by the system only).
abstract final class UserStatuses {
  static const String active = 'active';
  static const String suspended = 'suspended';
  static const String deactivated = 'deactivated';

  static const List<String> all = <String>[active, suspended, deactivated];

  static String label(String status) => switch (status) {
        active => 'Active',
        suspended => 'Suspended',
        deactivated => 'Deactivated',
        'invited' => 'Invited',
        _ => status,
      };
}

/// A row of the users list.
@immutable
class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.fullName,
    required this.status,
    this.email,
    this.phone,
    this.designation,
    this.employeeCode,
    this.roleNames = const <String>[],
  });

  factory ManagedUser.fromJson(Map<String, Object?> json) {
    final List<Object?> roles = (json['user_roles'] as List<Object?>?) ?? const <Object?>[];
    return ManagedUser(
      id: json['id']! as String,
      fullName: json['full_name']! as String,
      status: json['status']! as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      designation: json['designation'] as String?,
      employeeCode: json['employee_code'] as String?,
      roleNames: <String>{
        for (final Object? row in roles)
          if (row is Map && row['roles'] is Map) (row['roles'] as Map)['name']! as String,
      }.toList(),
    );
  }

  final String id;
  final String fullName;
  final String status;
  final String? email;
  final String? phone;
  final String? designation;
  final String? employeeCode;
  final List<String> roleNames;

  bool get isActive => status == UserStatuses.active;
}

/// Users list filter. `showroomId == null` = every user the caller may see.
@immutable
class UsersQuery {
  const UsersQuery({this.search = '', this.showroomId, this.status, this.page = 1, this.pageSize = 25});

  final String search;
  final String? showroomId;
  final String? status;
  final int page;
  final int pageSize;

  UsersQuery copyWith({String? search, String? Function()? showroomId, String? Function()? status, int? page}) {
    return UsersQuery(
      search: search ?? this.search,
      showroomId: showroomId == null ? this.showroomId : showroomId(),
      status: status == null ? this.status : status(),
      page: page ?? this.page,
      pageSize: pageSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UsersQuery &&
      other.search == search &&
      other.showroomId == showroomId &&
      other.status == status &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(search, showroomId, status, page, pageSize);
}

@immutable
class UsersPage {
  const UsersPage({required this.items, required this.total});

  final List<ManagedUser> items;
  final int total;
}

/// A role that can be picked (grant dialogs, create form).
@immutable
class RoleOption {
  const RoleOption({required this.id, required this.code, required this.name});

  factory RoleOption.fromJson(Map<String, Object?> json) =>
      RoleOption(id: json['id']! as String, code: json['code']! as String, name: json['name']! as String);

  final String id;
  final String code;
  final String name;
}

/// A showroom that can be picked.
@immutable
class ShowroomOption {
  const ShowroomOption({required this.id, required this.code, required this.name});

  factory ShowroomOption.fromJson(Map<String, Object?> json) =>
      ShowroomOption(id: json['id']! as String, code: json['code']! as String, name: json['name']! as String);

  final String id;
  final String code;
  final String name;
}

/// One role assignment of the user.
@immutable
class RoleAssignment {
  const RoleAssignment({
    required this.assignmentId,
    required this.roleId,
    required this.code,
    required this.name,
    required this.isUsable,
    this.expiresOn,
  });

  factory RoleAssignment.fromJson(Map<String, Object?> json) => RoleAssignment(
        assignmentId: json['assignment_id']! as String,
        roleId: json['role_id']! as String,
        code: json['code']! as String,
        name: json['name']! as String,
        isUsable: json['is_usable'] as bool? ?? true,
        expiresOn: json['expires_on'] as String?,
      );

  final String assignmentId;
  final String roleId;
  final String code;
  final String name;

  /// False when the role is inactive or the assignment expired.
  final bool isUsable;
  final String? expiresOn;
}

/// The user's roles in one scope: a showroom, or global (`showroomId == null`).
@immutable
class AccessScope {
  const AccessScope({
    required this.canManage,
    required this.roles,
    required this.grantableRoles,
    this.showroomId,
    this.code,
    this.name,
    this.isActive = true,
  });

  factory AccessScope.fromJson(Map<String, Object?> json, {bool global = false}) => AccessScope(
        showroomId: global ? null : json['id']! as String,
        code: json['code'] as String?,
        name: json['name'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        canManage: json['can_manage'] as bool? ?? false,
        roles: <RoleAssignment>[
          for (final Object? row in (json['roles'] as List<Object?>?) ?? const <Object?>[])
            RoleAssignment.fromJson((row! as Map<Object?, Object?>).cast<String, Object?>()),
        ],
        grantableRoles: <RoleOption>[
          for (final Object? row in (json['grantable_roles'] as List<Object?>?) ?? const <Object?>[])
            RoleOption.fromJson((row! as Map<Object?, Object?>).cast<String, Object?>()),
        ],
      );

  final String? showroomId;
  final String? code;
  final String? name;
  final bool isActive;

  /// The caller may remove roles here (and, for a showroom, the showroom).
  final bool canManage;
  final List<RoleAssignment> roles;

  /// Roles the caller may add here; empty when adding is not allowed.
  final List<RoleOption> grantableRoles;

  bool get isGlobal => showroomId == null;
}

/// Payload of `rpc_get_user_access`: the user and what the caller may change.
/// The flags are UI hints; RLS decides every write.
@immutable
class UserAccess {
  const UserAccess({
    required this.user,
    required this.createdAt,
    required this.isSelf,
    required this.canManage,
    required this.global,
    required this.showrooms,
    required this.hiddenShowroomCount,
    required this.addableShowrooms,
  });

  factory UserAccess.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> profile = (json['profile']! as Map<Object?, Object?>).cast<String, Object?>();
    return UserAccess(
      user: ManagedUser.fromJson(profile),
      createdAt: DateTime.tryParse(profile['created_at'] as String? ?? ''),
      isSelf: json['is_self'] as bool? ?? false,
      canManage: json['can_manage'] as bool? ?? false,
      global: AccessScope.fromJson((json['global']! as Map<Object?, Object?>).cast<String, Object?>(), global: true),
      showrooms: <AccessScope>[
        for (final Object? row in (json['showrooms'] as List<Object?>?) ?? const <Object?>[])
          AccessScope.fromJson((row! as Map<Object?, Object?>).cast<String, Object?>()),
      ],
      hiddenShowroomCount: json['hidden_showroom_count'] as int? ?? 0,
      addableShowrooms: <ShowroomOption>[
        for (final Object? row in (json['addable_showrooms'] as List<Object?>?) ?? const <Object?>[])
          ShowroomOption.fromJson((row! as Map<Object?, Object?>).cast<String, Object?>()),
      ],
    );
  }

  final ManagedUser user;
  final DateTime? createdAt;
  final bool isSelf;

  /// The caller may change the profile, status and password.
  final bool canManage;
  final AccessScope global;
  final List<AccessScope> showrooms;

  /// Assignments in showrooms the caller cannot access (counted, not shown).
  final int hiddenShowroomCount;
  final List<ShowroomOption> addableShowrooms;
}

/// Fields of the create-user form (sent to the admin-users Edge Function).
@immutable
class NewUserRequest {
  const NewUserRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.showroomId,
    required this.roleId,
    this.phone = '',
    this.designation = '',
    this.employeeCode = '',
  });

  final String email;
  final String password;
  final String fullName;
  final String showroomId;
  final String roleId;
  final String phone;
  final String designation;
  final String employeeCode;

  Map<String, Object?> toJson() => <String, Object?>{
        'action': 'create',
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
        'showroom_id': showroomId,
        'role_id': roleId,
        'phone': phone.trim(),
        'designation': designation.trim(),
        'employee_code': employeeCode.trim(),
      };
}

/// Profile fields an administrator maintains.
@immutable
class UserProfileUpdate {
  const UserProfileUpdate({required this.fullName, this.phone = '', this.designation = '', this.employeeCode = ''});

  final String fullName;
  final String phone;
  final String designation;
  final String employeeCode;
}
