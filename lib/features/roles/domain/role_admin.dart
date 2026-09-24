import 'package:flutter/foundation.dart';

/// An application role (`roles` table).
@immutable
class AppRole {
  const AppRole({
    required this.id,
    required this.code,
    required this.name,
    required this.precedence,
    required this.isSystem,
    required this.isActive,
    this.description,
  });

  factory AppRole.fromJson(Map<String, Object?> json) => AppRole(
        id: json['id']! as String,
        code: json['code']! as String,
        name: json['name']! as String,
        precedence: json['precedence']! as int,
        isSystem: json['is_system'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        description: json['description'] as String?,
      );

  /// The owner role; the database keeps it holding every permission.
  static const String superAdminCode = 'SUPER_ADMIN';

  /// Custom roles rank below SUPER_ADMIN (100), enforced by a constraint.
  static const int maxCustomPrecedence = 99;

  final String id;
  final String code;
  final String name;
  final int precedence;
  final bool isSystem;
  final bool isActive;
  final String? description;

  bool get isSuperAdmin => code == superAdminCode;
}

/// A `module.action` entry of the permission catalogue.
@immutable
class PermissionEntry {
  const PermissionEntry({required this.id, required this.module, required this.action});

  factory PermissionEntry.fromJson(Map<String, Object?> json) => PermissionEntry(
        id: json['id']! as String,
        module: json['module']! as String,
        action: json['action']! as String,
      );

  final String id;
  final String module;
  final String action;

  String get code => '$module.$action';
}

/// A role with its granted permissions and whether the caller may edit it.
@immutable
class RoleDetail {
  const RoleDetail({required this.role, required this.grantedPermissionIds, required this.canEdit});

  final AppRole role;
  final Set<String> grantedPermissionIds;

  /// Server answer of can_edit_role(); UI hint only, RLS decides.
  final bool canEdit;
}

/// Fields of the role form.
@immutable
class RoleDraft {
  const RoleDraft({required this.code, required this.name, required this.precedence, this.description = '', this.isActive = true});

  final String code;
  final String name;
  final int precedence;
  final String description;
  final bool isActive;
}
